param(
    [switch]$SkipInstaller,
    [switch]$SkipSign
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Project = Join-Path $Root "DSTX.Tweaks.App\DSTX.Tweaks.App.csproj"
$PublishDir = Join-Path $Root "publish\win-x64"
$InstallerOutput = Join-Path $Root "installer-output"
$SetupExe = Join-Path $InstallerOutput "setup.exe"
$MetadataPath = Join-Path $InstallerOutput "update.metadata.json"

function Step($Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

Step "Clean"
Remove-Item $PublishDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $InstallerOutput -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $PublishDir,$InstallerOutput -Force | Out-Null

Step "Validate PowerShell"
& (Join-Path $Root "scripts\ci\test-powershell.ps1")

Step "Validate catalogs"
& (Join-Path $Root "scripts\ci\validate-catalogs.ps1")

Step "dotnet restore"
dotnet restore $Project

Step "dotnet build"
dotnet build $Project -c Release --no-restore

Step "dotnet publish win-x64 self-contained"
dotnet publish $Project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=false `
    -p:DebugType=embedded `
    -o $PublishDir

$DstxExe = Join-Path $PublishDir "dstx.exe"
if (-not (Test-Path $DstxExe)) {
    throw "dstx.exe was not created: $DstxExe"
}

if (-not $SkipSign) {
    & (Join-Path $Root "scripts\ci\sign-artifacts.ps1") -Path $DstxExe
}

if (-not $SkipInstaller) {
    Step "Compile Inno setup.exe"
    $isccCandidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )
    $iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $iscc) {
        throw "ISCC.exe not found. Install Inno Setup 6."
    }

    & $iscc (Join-Path $Root "installer\DSTX-Tweaks.iss")
    if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed." }
    if (-not (Test-Path $SetupExe)) { throw "setup.exe was not created." }

    if (-not $SkipSign) {
        & (Join-Path $Root "scripts\ci\sign-artifacts.ps1") -Path $SetupExe
    }

    Step "SHA256"
    $hash = (Get-FileHash $SetupExe -Algorithm SHA256).Hash.ToLowerInvariant()
    Set-Content -Path (Join-Path $InstallerOutput "setup.exe.sha256") -Value "$hash  setup.exe" -Encoding ASCII

    $metadata = Get-Content (Join-Path $Root "catalog\update.metadata.json") -Raw | ConvertFrom-Json
    $metadata.sha256 = $hash
    $metadata.generatedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    $metadata | ConvertTo-Json -Depth 20 | Set-Content $MetadataPath -Encoding UTF8

    Write-Host "setup.exe: $SetupExe" -ForegroundColor Green
    Write-Host "sha256: $hash" -ForegroundColor Green
}


if ($env:GITHUB_HEAD_REF -eq "dap-port-26.3-ci" -or $env:GITHUB_REF_NAME -eq "dap-port-26.3-ci") {
    Step "DAP ur Homies Minecraft 26.3 port attempt"
    $DapOutput = Join-Path $PublishDir "DAP-Port-26.3"
    & (Join-Path $Root "scripts\ci\dap-port-ci.ps1") -OutputDir $DapOutput
}

Step "Build release completed"
