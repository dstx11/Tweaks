param(
    [Parameter(Mandatory=$true)]
    [string]$Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    throw "File to sign not found: $Path"
}

if ([string]::IsNullOrWhiteSpace($env:SIGNING_CERTIFICATE_BASE64) -or [string]::IsNullOrWhiteSpace($env:SIGNING_CERTIFICATE_PASSWORD)) {
    Write-Host "Signing skipped: SIGNING_CERTIFICATE_BASE64 or SIGNING_CERTIFICATE_PASSWORD not set." -ForegroundColor Yellow
    return
}

$certPath = Join-Path $env:RUNNER_TEMP "dstx-signing-cert.pfx"
[IO.File]::WriteAllBytes($certPath, [Convert]::FromBase64String($env:SIGNING_CERTIFICATE_BASE64))

$signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin" -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\x64\\signtool\.exe$" } |
    Select-Object -First 1

if (-not $signtool) {
    throw "signtool.exe not found."
}

Write-Host "Signing: $Path" -ForegroundColor Cyan
& $signtool.FullName sign /fd SHA256 /f $certPath /p $env:SIGNING_CERTIFICATE_PASSWORD /tr "http://timestamp.digicert.com" /td SHA256 $Path
if ($LASTEXITCODE -ne 0) { throw "signtool sign failed." }

& $signtool.FullName verify /pa /v $Path
if ($LASTEXITCODE -ne 0) { throw "signtool verify failed." }
