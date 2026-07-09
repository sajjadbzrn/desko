<#
.SYNOPSIS
    Validates the syntax of scripts/install.ps1
.DESCRIPTION
    Uses PowerShell's built-in parser to check for syntax errors without executing.
    Exits with code 0 if valid, 1 if errors found.
.EXAMPLE
    .\scripts\validate-install.ps1
#>

$scriptPath = Join-Path $PSScriptRoot "install.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERR] File not found: $scriptPath" -ForegroundColor Red
    exit 1
}

$errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref] $null,
    [ref] $errors
)

if ($errors.Count -gt 0) {
    Write-Host "[FAIL] PowerShell syntax: INVALID" -ForegroundColor Red
    foreach ($e in $errors) {
        Write-Host "    $($e.Message)" -ForegroundColor Red
    }
    exit 1
}

Write-Host "  [PASS] PowerShell syntax: valid" -ForegroundColor Green
exit 0
