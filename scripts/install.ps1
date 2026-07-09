<#
.SYNOPSIS
    desko -- Installer for Windows
.DESCRIPTION
    Downloads the desko CLI binary from GitHub and adds it to your PATH.
    Features real-time download progress and detailed step logging.
.EXAMPLE
    irm https://raw.githubusercontent.com/sajjadbzrn/desko/main/scripts/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -Version v0.1.0
.EXAMPLE
    .\install.ps1 -InstallDir C:\tools\desko
#>

$Repo = "sajjadbzrn/desko"
$ScriptStart = Get-Date

$Version = "latest"
$InstallDir = ""
$Help = $false

if ($args -and $args.Count -gt 0) {
    for ($i = 0; $i -lt $args.Count; $i++) {
        switch -regex ($args[$i]) {
            '^(-|/)Version$'   { if ($i + 1 -lt $args.Count) { $Version = $args[++$i] } }
            '^(-|/)InstallDir$' { if ($i + 1 -lt $args.Count) { $InstallDir = $args[++$i] } }
            '^(-|/)Help$'       { $Help = $true }
            '^(-|/)[h?]$'       { $Help = $true }
        }
    }
}

if ($Help) {
    Write-Host "desko -- Installer for Windows" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: install.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Version [tag]   Install a specific version (default: latest)"
    Write-Host "  -InstallDir [d]  Install to a custom directory (default: ~\.desko\bin)"
    Write-Host "  -Help            Show this help"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  irm https://raw.githubusercontent.com/$Repo/main/scripts/install.ps1 | iex"
    Write-Host "  .\install.ps1 -Version v0.1.0"
    Write-Host "  .\install.ps1 -InstallDir C:\tools\desko"
    Exit 0
}

# =========================================================================
#  UI helpers
# =========================================================================

function Write-Timestamp {
    return Get-Date -Format "HH:mm:ss"
}

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $ts = Write-Timestamp
    $prefix = "  [$ts]"
    Write-Host "$prefix $Message" -ForegroundColor $Color
}

function Write-Step {
    param([string]$Title)
    Write-Host ""
    Write-Host "  -- $Title ---" -ForegroundColor Cyan
    Write-Log "Starting..." -Color Blue
}

function Write-Success {
    param([string]$Message)
    Write-Log "[OK] $Message" -Color Green
}

function Write-Warn {
    param([string]$Message)
    Write-Log "[WARN] $Message" -Color Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Log "[FAIL] $Message" -Color Red
}

# =========================================================================
#  Download progress bar
# =========================================================================

function Write-DownloadProgress {
    param(
        [int]$Percent,
        [long]$BytesReceived,
        [long]$TotalBytes
    )

    # Format sizes for display
    if ($TotalBytes -gt 1MB) {
        $receivedStr = "{0:N2} MB" -f ($BytesReceived / 1MB)
        $totalStr   = "{0:N2} MB" -f ($TotalBytes / 1MB)
    } elseif ($TotalBytes -gt 1KB) {
        $receivedStr = "{0:N1} KB" -f ($BytesReceived / 1KB)
        $totalStr   = "{0:N1} KB" -f ($TotalBytes / 1KB)
    } else {
        $receivedStr = "$BytesReceived B"
        $totalStr    = "$TotalBytes B"
    }

    # Clamp percentage to 0-100
    $pct = [math]::Min([math]::Max($Percent, 0), 100)

    # Draw bar
    $barLen = 25
    $filled = [math]::Floor($pct / 100 * $barLen)
    $bar = "#" * $filled + "-" * ($barLen - $filled)

    # Remaining
    $remaining = $TotalBytes - $BytesReceived
    if ($remaining -gt 1MB) {
        $remainingStr = "{0:N2} MB" -f ($remaining / 1MB)
    } elseif ($remaining -gt 1KB) {
        $remainingStr = "{0:N1} KB" -f ($remaining / 1KB)
    } else {
        $remainingStr = "$remaining B"
    }

    Write-Host "`r  [$bar] $pct%  ($receivedStr / $totalStr, $remainingStr remaining)  " -NoNewline
}

function Invoke-Download {
    param([string]$Url, [string]$OutFile)

    Write-Log "Connecting to $Url ..." -Color Blue

    $request = [System.Net.WebRequest]::Create($Url)
    $request.Timeout = 600000
    $request.UserAgent = "desko-installer/1.0"
    $request.AllowAutoRedirect = $true

    try {
        $response = $request.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::Create($OutFile)

        try {
            $buffer = New-Object byte[] 65536
            $totalRead = [long]0
            $lastReportedPct = -1

            if ($totalBytes -le 0) {
                Write-Log "Downloading (size unknown)..." -Color Yellow
                while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fileStream.Write($buffer, 0, $read)
                    $totalRead += $read
                    if ($totalRead % (1MB) -lt 65536) {
                        Write-Host "`r  Downloaded $([math]::Round($totalRead / 1MB, 1)) MB so far..." -NoNewline
                    }
                }
                Write-Host "`r  Downloaded $([math]::Round($totalRead / 1MB, 1)) MB -- complete!    "
            } else {
                while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $fileStream.Write($buffer, 0, $read)
                    $totalRead += $read

                    $pct = [math]::Min([math]::Round(($totalRead / $totalBytes) * 100), 100)
                    if ($pct -ne $lastReportedPct) {
                        Write-DownloadProgress -Percent $pct -BytesReceived $totalRead -TotalBytes $totalBytes
                        $lastReportedPct = $pct
                    }
                }

                Write-DownloadProgress -Percent 100 -BytesReceived $totalRead -TotalBytes $totalBytes
                Write-Host ""
                Write-Host ""
            }
        } finally {
            if ($fileStream) { $fileStream.Close() }
            if ($responseStream) { $responseStream.Close() }
        }
    } catch [System.Net.WebException] {
        $statusCode = 0
        if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
        if ($statusCode -eq 404) {
            throw "HTTP 404 -- Release not found. Verify a release exists for version '$Version'."
        }
        throw "HTTP $statusCode -- $_"
    } catch {
        throw $_
    } finally {
        if ($response) { $response.Close() }
    }
}

# =========================================================================
#  Platform detection
# =========================================================================

Write-Step "System check"

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

Write-Log "Architecture: $ArchName" -Color White

if ($ArchName -ne "x64") {
    Write-Error "Unsupported architecture: $ArchName (only x64 is currently supported)"
    Exit 1
}

$Platform = "windows-x64"
$Asset = "desko-windows-x64.exe"

Write-Success "Platform: Windows $ArchName"

# -- install directory ----------------------------------------------------

if (-not $InstallDir) {
    $InstallDir = Join-Path $env:USERPROFILE ".desko\bin"
}

$BinPath = Join-Path $InstallDir "desko.exe"

Write-Log "Install target: $BinPath" -Color White

# -- build download URL ---------------------------------------------------

if ($Version -eq "latest") {
    $DownloadUrl = "https://github.com/$Repo/releases/latest/download/$Asset"
} else {
    $DownloadUrl = "https://github.com/$Repo/releases/download/$Version/$Asset"
}

Write-Log "Release URL: $DownloadUrl" -Color White

# =========================================================================
#  Header
# =========================================================================

Write-Host ""
Write-Host "  +----------------------------+" -ForegroundColor Cyan
Write-Host "  |     desko -- Installer     |" -ForegroundColor Cyan
Write-Host "  +----------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Platform: Windows $ArchName"
Write-Host "  Version:  $Version"
Write-Host "  Install:  $InstallDir"
Write-Host "  Repo:     $Repo"
Write-Host ""

# =========================================================================
#  Download
# =========================================================================

Write-Step "Downloading desko"

$TmpDir = Join-Path $env:TEMP "desko-install-$([System.IO.Path]::GetRandomFileName())"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null
$TmpBin = Join-Path $TmpDir "desko.exe"

try {
    Invoke-Download -Url $DownloadUrl -OutFile $TmpBin
} catch {
    Write-Error "Download failed: $_"
    Write-Log "Possible causes:" -Color Yellow
    Write-Log "  - No internet connection" -Color Yellow
    Write-Log "  - The release asset '$Asset' does not exist for version '$Version'" -Color Yellow
    Write-Log "  - GitHub is unreachable from your network" -Color Yellow
    Write-Log ""
    Write-Log "Check the releases page:" -Color Yellow
    Write-Log "  https://github.com/$Repo/releases" -Color Yellow
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Exit 1
}

# -- verify ----------------------------------------------------------------

Write-Step "Verifying download"

$fileInfo = Get-Item $TmpBin
$fileSize = $fileInfo.Length

if ($fileSize -eq 0) {
    Write-Error "Download returned an empty file."
    Write-Log "The release asset may be missing or corrupt." -Color Yellow
    Write-Log "Check: https://github.com/$Repo/releases" -Color Yellow
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Exit 1
}

$peCheckStream = [System.IO.File]::OpenRead($TmpBin)
$magic = New-Object byte[] 2
$null = $peCheckStream.Read($magic, 0, 2)
$peCheckStream.Close()

if ($magic[0] -ne 77 -or $magic[1] -ne 90) {
    Write-Error "Downloaded file is not a valid Windows executable."
    Write-Log "GitHub may have returned an error page instead of the binary." -Color Yellow
    Write-Log "This can happen if:" -Color Yellow
    Write-Log "  - No release exists yet for version '$Version'" -Color Yellow
    Write-Log "  - The asset name '$Asset' does not match the release" -Color Yellow
    Write-Log ""
    Write-Log "Check the releases page:" -Color Yellow
    Write-Log "  https://github.com/$Repo/releases" -Color Yellow
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
    Exit 1
}

if ($fileSize -gt 1MB) {
    Write-Success ("Downloaded {0:N2} MB" -f ($fileSize / 1MB))
} else {
    Write-Success ("Downloaded {0:N1} KB" -f ($fileSize / 1KB))
}

# =========================================================================
#  Install
# =========================================================================

Write-Step "Installing binary"

Write-Log "Creating directory: $InstallDir" -Color Blue
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

Write-Log "Moving binary to: $BinPath" -Color Blue
Move-Item -Path $TmpBin -Destination $BinPath -Force
Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue

Write-Success "desko installed to $BinPath"

# -- show version ----------------------------------------------------------

Write-Step "Verifying installation"

try {
    $versionOutput = & $BinPath "--version" 2>&1
    Write-Success "desko $versionOutput"
} catch {
    Write-Warn "Could not verify version (the --version flag may not be supported)"
}

# =========================================================================
#  Add to PATH
# =========================================================================

Write-Step "Setting up PATH"

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$NormalizedInstallDir = $InstallDir.TrimEnd('\')
$Paths = $UserPath -split ";" | Where-Object { $_ -ne "" } | ForEach-Object { $_.TrimEnd('\') }

if ($Paths -contains $NormalizedInstallDir) {
    Write-Success "$NormalizedInstallDir already in your PATH"
} else {
    Write-Log "Adding $NormalizedInstallDir to user PATH..." -Color Blue
    $NewPath = "$NormalizedInstallDir;$UserPath"
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")

    # Also update current session
    $env:Path = "$NormalizedInstallDir;$env:Path"

    Write-Success "Added $NormalizedInstallDir to your PATH"
}

# =========================================================================
#  Summary
# =========================================================================

$Elapsed = [math]::Round(((Get-Date) - $ScriptStart).TotalSeconds, 1)

Write-Step "Installation complete"

Write-Success "desko is ready! (completed in ${Elapsed}s)"
Write-Host ""
Write-Host "  Quick start:" -ForegroundColor Cyan
$deskoPath = (Get-Command "desko" -ErrorAction SilentlyContinue).Source
if ($deskoPath) {
    Write-Host "    desko add \"Buy groceries\" --priority high" -ForegroundColor Cyan
    Write-Host "    desko list" -ForegroundColor Cyan
    Write-Host "    desko stats" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Need help?  desko --help" -ForegroundColor Cyan
} else {
    Write-Warn "Restart your terminal, then try:"
    Write-Host "    desko add \"Buy groceries\" --priority high" -ForegroundColor Cyan
    Write-Host "    desko list" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Need help?  desko --help" -ForegroundColor Cyan
}
Write-Host ""
