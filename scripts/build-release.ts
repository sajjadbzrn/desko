#!/usr/bin/env bun
import { mkdirSync, existsSync, cpSync, chmodSync } from "fs";
import { join } from "path";

const PLATFORMS = [
  "linux-x64",
  "macos-arm64",
  "macos-x64",
  "windows-x64",
] as const;

type Platform = (typeof PLATFORMS)[number];

function getBinaryName(platform: Platform): string {
  return platform === "windows-x64"
    ? "desko-windows-x64.exe"
    : `desko-${platform}`;
}

function getCurrentPlatform(): Platform {
  const os = process.platform;
  const arch = process.arch;

  if (os === "linux" && arch === "x64") return "linux-x64";
  if (os === "darwin" && arch === "arm64") return "macos-arm64";
  if (os === "darwin" && arch === "x64") return "macos-x64";
  if (os === "win32" && arch === "x64") return "windows-x64";

  throw new Error(`Unsupported platform: ${os}-${arch}`);
}

async function build(target?: Platform) {
  const currentPlatform = getCurrentPlatform();
  const buildTarget = target || currentPlatform;

  if (target && target !== currentPlatform) {
    console.error(`❌ Cannot cross-compile.`);
    console.error(`   Current platform: ${currentPlatform}`);
    console.error(`   Requested target:  ${target}`);
    console.error(`   Bun does not support cross-compilation.`);
    console.error(`   Use GitHub Actions to build for all platforms.`);
    process.exit(1);
  }

  const releaseDir = join(process.cwd(), "release");
  if (!existsSync(releaseDir)) {
    mkdirSync(releaseDir, { recursive: true });
  }

  const binaryName = getBinaryName(buildTarget);
  const outputBin = join(releaseDir, binaryName);
  const tempBin = join(process.cwd(), binaryName);

  console.log(`🔨 Building desko for ${buildTarget}...`);

  const proc = Bun.spawnSync(
    [
      "bun",
      "build",
      "--compile",
      "--minify",
      "--sourcemap",
      "./src/index.ts",
      "--outfile",
      tempBin,
    ],
    { stdio: "inherit" },
  );

  if (proc.exitCode !== 0) {
    console.error("❌ Build failed.");
    process.exit(1);
  }

  cpSync(tempBin, outputBin);
  chmodSync(outputBin, 0o755);

  console.log(`✅ Built: release/${binaryName}`);

  try {
    Bun.spawnSync(["rm", tempBin]);
  } catch {
    // Ignore cleanup errors on Windows
  }
}

const target = process.argv[2] as Platform | undefined;

if (target && !PLATFORMS.includes(target)) {
  console.error(`Invalid target: "${target}"`);
  console.error(`Valid targets: ${PLATFORMS.join(", ")}`);
  process.exit(1);
}

await build(target);
