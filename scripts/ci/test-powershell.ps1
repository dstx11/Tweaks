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
