$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Failed = $false

Write-Host "Checking PowerShell syntax..." -ForegroundColor Cyan
$Files = Get-ChildItem -Path $Root -Recurse -Filter *.ps1 | Where-Object {
    $_.FullName -notmatch "\\bin\\" -and $_.FullName -notmatch "\\obj\\"
}

foreach ($File in $Files) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($File.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        Write-Host "FAILED: $($File.FullName)" -ForegroundColor Red
        $errors | Format-List *
        $Failed = $true
    } else {
        Write-Host "OK: $($File.FullName)" -ForegroundColor Green
    }
}

if ($Failed) { exit 1 }
Write-Host "PowerShell syntax OK." -ForegroundColor Green


if ($env:GITHUB_HEAD_REF -eq "dap-port-26.3-ci" -or $env:GITHUB_REF_NAME -eq "dap-port-26.3-ci") {
    $DapEarly = Join-Path $Root "dap-port-early"
    $DapStatus = Join-Path $DapEarly "BUILD_STATUS.txt"
    if (-not (Test-Path $DapStatus)) {
        Write-Host "Running early DAP 26.3 port attempt..." -ForegroundColor Cyan
        & (Join-Path $PSScriptRoot "dap-port-ci.ps1") -OutputDir $DapEarly
    } else {
        Write-Host "DAP 26.3 early attempt already completed in this job." -ForegroundColor DarkGray
    }
}
