<#
.SYNOPSIS
    desko — Installer for Windows
.DESCRIPTION
    Downloads the desko CLI binary from GitHub and adds it to your PATH.
.EXAMPLE
    irm https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -Version v0.1.0
.EXAMPLE
    .\install.ps1 -InstallDir C:\tools\desko
#>

param(
    [string]$Version = "latest",
    [string]$InstallDir = "",
    [switch]$Help
)

$Repo = "sajjadbzrn/desko"

# ── help ────────────────────────────────────────────────────────────

if ($Help) {
    Write-Host "desko — Installer for Windows" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: install.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Version <tag>   Install a specific version (default: latest)"
    Write-Host "  -InstallDir <d>  Install to a custom directory"
    Write-Host "  -Help            Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  irm https://raw.githubusercontent.com/$Repo/main/scripts/install.ps1 | iex"
    Write-Host "  .\install.ps1 -Version v0.1.0"
    Exit 0
}

# ── helpers ─────────────────────────────────────────────────────────

function Write-Step($msg) {
    Write-Host "→ $msg" -ForegroundColor Blue
}

function Write-Success($msg) {
    Write-Host "✓ $msg" -ForegroundColor Green
}

function Write-Error($msg) {
    Write-Host "✗ $msg" -ForegroundColor Red
}

# ── platform detection ──────────────────────────────────────────────

# Detect architecture
# Prefer $env:PROCESSOR_ARCHITECTURE (simpler, always available),
# fall back to CIM for cross-architecture awareness (ARM64 on x64 emulation)
$ArchName = switch ($env:PROCESSOR_ARCHITECTURE) {
    "AMD64"  { "x64" }
    "ARM64"  { "arm64" }
    "x86"    { "x86" }
    default  {
        try {
            $arch = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop | Select-Object -First 1).Architecture
            switch ($arch) {
                0  { "x86" }
                9  { "x64" }
                12 { "arm64" }
                default { "unknown" }
            }
        } catch {
            "unknown"
        }
    }
}

if ($ArchName -ne "x64") {
    Write-Error "Unsupported architecture: $ArchName (only x64 is currently supported)"
    Exit 1
}

$Platform = "windows-x64"
$Asset = "desko-windows-x64.exe"

# ── install directory ───────────────────────────────────────────────

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:USERPROFILE ".desko\bin"
}

$BinPath = Join-Path $InstallDir "desko.exe"

# ── build download URL ──────────────────────────────────────────────

if ($Version -eq "latest") {
    $DownloadUrl = "https://github.com/$Repo/releases/latest/download/$Asset"
} else {
    $DownloadUrl = "https://github.com/$Repo/releases/download/$Version/$Asset"
}

# ── header ──────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  ╔══════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     desko — Installer        ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Platform: Windows $ArchName"
Write-Host "  Version:  $Version"
Write-Host "  Install:  $InstallDir"
Write-Host "  Repo:     $Repo"
Write-Host ""

# ── download ────────────────────────────────────────────────────────

Write-Step "Downloading desko for Windows..."

$TmpDir = Join-Path $env:TEMP "desko-install-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$TmpBin = Join-Path $TmpDir "desko.exe"

try {
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TmpBin -UseBasicParsing
} catch {
    Write-Error "Download failed: $_"
    Write-Error "Check that $Asset exists in the $Version release at:"
    Write-Error "https://github.com/$Repo/releases"
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Exit 1
}

if (-not (Test-Path $TmpBin) -or ((Get-Item $TmpBin).Length -eq 0)) {
    Write-Error "Download returned an empty file. Check the release page."
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Exit 1
}

# ── install ─────────────────────────────────────────────────────────

Write-Step "Installing to $InstallDir..."
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Move-Item -Path $TmpBin -Destination $BinPath -Force
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

Write-Success "desko installed to $BinPath"

# Show version
try {
    $versionOutput = & $BinPath "--version" 2>&1
    Write-Success "Version: $versionOutput"
} catch {
    # Version flag might not work; that's okay
}

# ── add to PATH ─────────────────────────────────────────────────────

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$NormalizedInstallDir = $InstallDir.TrimEnd('\')
$Paths = $UserPath -split ";" | Where-Object { $_ -ne "" } | ForEach-Object { $_.TrimEnd('\') }

if ($Paths -contains $NormalizedInstallDir) {
    Write-Success "$NormalizedInstallDir already in your PATH"
} else {
    Write-Step "Adding $NormalizedInstallDir to your PATH..."
    $NewPath = "$NormalizedInstallDir;$UserPath"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")

    # Also update current session
    $env:Path = "$NormalizedInstallDir;$env:Path"

    Write-Success "Added $NormalizedInstallDir to your PATH"
}

# ── done ────────────────────────────────────────────────────────────

Write-Host ""
Write-Success "desko is ready!"
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Cyan
$deskoPath = (Get-Command "desko" -ErrorAction SilentlyContinue).Source
if ($deskoPath) {
    Write-Host "    desko add ""Buy groceries"" --priority high" -ForegroundColor Cyan
    Write-Host "    desko list" -ForegroundColor Cyan
    Write-Host "    desko stats" -ForegroundColor Cyan
} else {
    Write-Host "  ⚠  Restart your terminal, then try:" -ForegroundColor Yellow
    Write-Host "    desko add ""Buy groceries"" --priority high" -ForegroundColor Cyan
    Write-Host "    desko list" -ForegroundColor Cyan
}
Write-Host ""
