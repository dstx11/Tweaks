param(
    [switch]$BuildSetup,
    [switch]$RunAfterInstall = $true,
    [switch]$NoInstall
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$ProjectDir = Join-Path $Root "DSTX.Tweaks.App"
$PublishDir = Join-Path $Root "publish\win-x64"
$InstallDir = Join-Path $env:ProgramFiles "DSTX Tweaks"
$ExeName = "dstx.exe"
$PublishedExe = Join-Path $PublishDir $ExeName
$InstalledExe = Join-Path $InstallDir $ExeName
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath("Desktop")) "DSTX Tweaks.lnk"
$SetupOutput = Join-Path $Root "installer-output\setup.exe"

function Write-Step($Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
    if (-not (Test-Admin)) {
        Write-Host "Requesting Administrator permissions..."
        Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $($MyInvocation.BoundParameters.Keys | ForEach-Object { '-' + $_ })"
        exit
    }
}

function Ensure-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "winget found." -ForegroundColor Green
        return
    }

    Write-Host "winget was not found. Install 'App Installer' from Microsoft Store, then run this again." -ForegroundColor Yellow
    Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
    throw "winget missing"
}

function Ensure-DotNetSdk {
    Write-Step ".NET 8 SDK check"
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnet) {
        $sdks = & dotnet --list-sdks
        if ($sdks -match "^8\.") {
            Write-Host ".NET 8 SDK found." -ForegroundColor Green
            return
        }
    }

    Ensure-Winget
    Write-Host "Installing .NET 8 SDK via winget..."
    winget install -e --id Microsoft.DotNet.SDK.8 --accept-package-agreements --accept-source-agreements
}

function Ensure-InnoSetup {
    Write-Step "Inno Setup check"
    $possible = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    )

    foreach ($p in $possible) {
        if (Test-Path $p) {
            Write-Host "Inno Setup found." -ForegroundColor Green
            return $p
        }
    }

    Ensure-Winget
    Write-Host "Installing Inno Setup via winget..."
    winget install -e --id JRSoftware.InnoSetup --accept-package-agreements --accept-source-agreements

    foreach ($p in $possible) {
        if (Test-Path $p) { return $p }
    }

    throw "Inno Setup compiler not found after install."
}

function Publish-App {
    Write-Step "Publishing DSTX Tweaks as self-contained win-x64"
    if (Test-Path $PublishDir) { Remove-Item $PublishDir -Recurse -Force }

    Push-Location $ProjectDir
    try {
        dotnet restore
        dotnet publish `
            -c Release `
            -r win-x64 `
            --self-contained true `
            -p:PublishSingleFile=false `
            -p:DebugType=embedded `
            -o "$PublishDir"
    }
    finally {
        Pop-Location
    }

    if (-not (Test-Path $PublishedExe)) {
        throw "Publish failed: $PublishedExe was not created."
    }

    Write-Host "Published app exe: $PublishedExe" -ForegroundColor Green
}

function Install-AppLocal {
    Write-Step "Installing to Program Files"
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

    Get-ChildItem $PublishDir -Force | ForEach-Object {
        Copy-Item $_.FullName -Destination $InstallDir -Recurse -Force
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($DesktopShortcut)
    $shortcut.TargetPath = $InstalledExe
    $shortcut.WorkingDirectory = $InstallDir
    $shortcut.Description = "DSTX Tweaks"
    $shortcut.Save()

    Write-Host "Installed app exe: $InstalledExe" -ForegroundColor Green
    Write-Host "Desktop shortcut: $DesktopShortcut" -ForegroundColor Green
}

function Build-InnoSetup {
    Write-Step "Building final setup.exe"
    $iscc = Ensure-InnoSetup
    $iss = Join-Path $PSScriptRoot "DSTX-Tweaks.iss"
    & $iscc $iss
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compile failed."
    }

    if (Test-Path $SetupOutput) {
        Write-Host "Final installer created: $SetupOutput" -ForegroundColor Green
    } else {
        throw "setup.exe was not created."
    }
}

function Run-App {
    if (Test-Path $InstalledExe) {
        Write-Step "Starting DSTX Tweaks"
        Start-Process -FilePath $InstalledExe -Verb RunAs
    } elseif (Test-Path $PublishedExe) {
        Write-Step "Starting published DSTX Tweaks"
        Start-Process -FilePath $PublishedExe -Verb RunAs
    } else {
        throw "No executable found to run."
    }
}

Ensure-Admin

if (-not $NoInstall) {
    Ensure-DotNetSdk
}

Publish-App
Install-AppLocal

if ($BuildSetup) {
    Build-InnoSetup
}

if ($RunAfterInstall) {
    Run-App
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
Write-Host "Final installed executable: $InstalledExe"
if (Test-Path $SetupOutput) { Write-Host "Final installer: $SetupOutput" }
