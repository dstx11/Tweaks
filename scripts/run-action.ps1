param(
    [Parameter(Mandatory=$true)]
    [string]$Action,

    [ValidateSet("Detect","Apply","Undo","Verify")]
    [string]$Mode = "Apply"
)

$ErrorActionPreference = "Continue"
$BaseDir = Join-Path $env:ProgramData "DSTX-Tweaks"
$BackupDir = Join-Path $BaseDir "Backups"
$LogDir = Join-Path $BaseDir "Logs"
$ReportDir = Join-Path $BaseDir "Reports"
$StateDir = Join-Path $BaseDir "State"
$ProfilesDir = Join-Path $BaseDir "Profiles"
$UpdatesDir = Join-Path $BaseDir "Updates"
$TempDir = Join-Path $BaseDir "Temp"
New-Item -ItemType Directory -Path $BackupDir,$LogDir,$ReportDir,$StateDir,$ProfilesDir,$UpdatesDir,$TempDir -Force | Out-Null

$LogFile = Join-Path $LogDir ("dstx_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")

function Write-Dstx {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Write-Output $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Invoke-DstxCmd {
    param([string]$Command)
    Write-Dstx ("CMD: " + $Command)
    cmd.exe /c "$Command >> `"$LogFile`" 2>&1"
}

function New-DstxBackup {
    $dir = Join-Path $BackupDir (Get-Date -Format "yyyyMMdd_HHmmss")
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Dstx ("Backup: " + $dir)
    Invoke-DstxCmd "powercfg /getactivescheme > `"$dir\ActivePowerScheme.txt`""
    Invoke-DstxCmd "bcdedit /enum all > `"$dir\BCD.txt`""
    Invoke-DstxCmd "netsh int tcp show global > `"$dir\TcpGlobal.txt`""
    Invoke-DstxCmd "ipconfig /all > `"$dir\IpConfig.txt`""
    Invoke-DstxCmd "reg export `"HKCU\System\GameConfigStore`" `"$dir\GameConfigStore.reg`" /y"
    Invoke-DstxCmd "reg export `"HKCU\Control Panel\Mouse`" `"$dir\Mouse.reg`" /y"
}

function New-DstxRestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "DSTX Tweaks before apply" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Dstx "Restore point created."
    } catch {
        Write-Dstx ("Restore point failed: " + $_.Exception.Message)
    }
}

function Install-WingetExact {
    param([string]$Id)
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Dstx "winget not found."
        return
    }
    Invoke-DstxCmd "winget show --id `"$Id`" -e --accept-source-agreements"
    if ($LASTEXITCODE -eq 0) {
        Invoke-DstxCmd "winget install -e --id `"$Id`" --accept-package-agreements --accept-source-agreements"
        Invoke-DstxCmd "winget upgrade -e --id `"$Id`" --accept-package-agreements --accept-source-agreements"
    }
}

function Clear-Folder {
    param([string]$Path)
    $p = [Environment]::ExpandEnvironmentVariables($Path)
    if ($p.Length -lt 8) { return }
    if (Test-Path $p) {
        Write-Dstx ("Clearing: " + $p)
        Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Dashboard-Status {
    Write-Dstx "Dashboard Status Scan"
    try { $os = Get-CimInstance Win32_OperatingSystem; Write-Dstx ("Windows: " + $os.Caption + " build " + $os.BuildNumber) } catch {}
    try { $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1; Write-Dstx ("CPU: " + $cpu.Name) } catch {}
    try { Get-NetAdapter | Where-Object Status -eq "Up" | ForEach-Object { Write-Dstx ("Adapter: " + $_.Name + " / " + $_.LinkSpeed) } } catch {}
    Invoke-DstxCmd "sc query vgc"
    Invoke-DstxCmd "winget --version"
}

function Valorant-Guard {
    Write-Dstx "Valorant Guard scan"
    Invoke-DstxCmd "sc query vgc"
    try { Write-Dstx ("SecureBoot: " + (Confirm-SecureBootUEFI)) } catch { Write-Dstx "SecureBoot: unavailable" }
    try { $t = Get-Tpm; Write-Dstx ("TPM Present: " + $t.TpmPresent + " Ready: " + $t.TpmReady) } catch { Write-Dstx "TPM: unavailable" }
}

function Gamer-Mode {
    New-DstxBackup
    New-DstxRestorePoint
    Invoke-DstxCmd "reg add `"HKCU\System\GameConfigStore`" /v GameDVR_Enabled /t REG_DWORD /d 0 /f"
    Invoke-DstxCmd "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR`" /v AllowGameDVR /t REG_DWORD /d 0 /f"
    Invoke-DstxCmd "reg add `"HKCU\Control Panel\Mouse`" /v MouseSpeed /t REG_SZ /d 0 /f"
    Invoke-DstxCmd "reg add `"HKCU\Control Panel\Mouse`" /v MouseThreshold1 /t REG_SZ /d 0 /f"
    Invoke-DstxCmd "reg add `"HKCU\Control Panel\Mouse`" /v MouseThreshold2 /t REG_SZ /d 0 /f"
    Write-Dstx "Minimal Windows Gamer Mode applied."
}

function Power-CPU {
    New-DstxBackup
    Invoke-DstxCmd "powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61"
    Invoke-DstxCmd "powercfg /setactive SCHEME_MIN"
}

function Latency-BCD {
    New-DstxBackup
    New-DstxRestorePoint
    Invoke-DstxCmd "bcdedit /set disabledynamictick yes"
    Invoke-DstxCmd "bcdedit /set useplatformtick no"
    Invoke-DstxCmd "bcdedit /set tscsyncpolicy Enhanced"
    Invoke-DstxCmd "bcdedit /set hypervisorlaunchtype off"
}

function Network-Diagnostics {
    $dir = Join-Path $ReportDir ("network_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Invoke-DstxCmd "ipconfig /all > `"$dir\ipconfig.txt`""
    Invoke-DstxCmd "netsh int tcp show global > `"$dir\tcp.txt`""
    Invoke-DstxCmd "ping 1.1.1.1 -n 20 > `"$dir\ping_1.1.1.1.txt`""
    Write-Dstx ("Network report: " + $dir)
}

function Network-Ping {
    New-DstxBackup
    Invoke-DstxCmd "netsh int tcp set global rss=enabled"
    Invoke-DstxCmd "netsh int tcp set global rsc=disabled"
    Invoke-DstxCmd "netsh int tcp set global ecncapability=disabled"
    Invoke-DstxCmd "ipconfig /flushdns"
}

function Install-Apps {
    "Brave.Brave","Discord.Discord","Valve.Steam","Spotify.Spotify","TechPowerUp.NVCleanstall","Stremio.Stremio","PrismLauncher.PrismLauncher" | ForEach-Object { Install-WingetExact $_ }
}

function Optimize-Discord {
    New-DstxBackup
    Get-Process Discord,Update -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Clear-Folder "%APPDATA%\discord\Cache"
    Clear-Folder "%APPDATA%\discord\Code Cache"
    Clear-Folder "%APPDATA%\discord\GPUCache"
    $settings = Join-Path $env:APPDATA "discord\settings.json"
    if (Test-Path $settings) {
        Copy-Item $settings "$settings.bak_dstx" -Force
        Write-Dstx "Discord settings.json backed up."
    }
}

function Optimize-Steam {
    New-DstxBackup
    Clear-Folder "%LOCALAPPDATA%\Steam\htmlcache"
    Get-Process steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Optimize-Brave {
    New-DstxBackup
    Get-Process brave -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Clear-Folder "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\Cache"
    Clear-Folder "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\Code Cache"
    Clear-Folder "%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data\Default\GPUCache"
}

function Fix-Valorant {
    Invoke-DstxCmd "sc config vgc start= demand"
    Invoke-DstxCmd "net start vgc"
}

function Fix-Bluetooth {
    Invoke-DstxCmd "sc config bthserv start= demand"
    Invoke-DstxCmd "net start bthserv"
    Invoke-DstxCmd "pnputil /scan-devices"
}

function Repair-Windows {
    Invoke-DstxCmd "DISM /Online /Cleanup-Image /RestoreHealth"
    Invoke-DstxCmd "sfc /scannow"
}

function Export-Report {
    $dir = Join-Path $ReportDir ("report_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Invoke-DstxCmd "powercfg /getactivescheme > `"$dir\power.txt`""
    Invoke-DstxCmd "tasklist /v > `"$dir\tasklist.txt`""
    Invoke-DstxCmd "sc query state= all > `"$dir\services.txt`""
    Compress-Archive -Path "$dir\*" -DestinationPath "$dir.zip" -Force
    Write-Dstx ("Report ZIP: " + $dir + ".zip")
}

function Restore-Basic {
    Invoke-DstxCmd "bcdedit /deletevalue disabledynamictick"
    Invoke-DstxCmd "bcdedit /deletevalue useplatformtick"
    Invoke-DstxCmd "bcdedit /deletevalue tscsyncpolicy"
    Invoke-DstxCmd "bcdedit /set hypervisorlaunchtype auto"
    Write-Dstx "Basic revert executed."
}

function Invoke-DstxLifecycleMode {
    param([string]$Mode,[string]$Action)
    if ($Mode -eq "Detect") {
        Write-Dstx ("DETECT: " + $Action)
        Write-Dstx "Detect base is enabled. Full per-action detection will be expanded in the next build."
        return $true
    }
    if ($Mode -eq "Verify") {
        Write-Dstx ("VERIFY: " + $Action)
        Write-Dstx "Verify base is enabled. Full per-action verification will be expanded in the next build."
        return $true
    }
    if ($Mode -eq "Undo") {
        Write-Dstx ("UNDO: " + $Action)
        Restore-Basic
        return $true
    }
    return $false
}

if (Invoke-DstxLifecycleMode -Mode $Mode -Action $Action) {
    exit 0
}

switch ($Action) {
    "dashboard_status" { Dashboard-Status }
    "valorant_guard" { Valorant-Guard }
    "command_preview" { Write-Dstx "Command preview is handled by the UI." }
    "gamer_mode" { Gamer-Mode }
    "power_cpu" { Power-CPU }
    "latency_bcd" { Latency-BCD }
    "network_diagnostics" { Network-Diagnostics }
    "network_ping" { Network-Ping }
    "install_apps" { Install-Apps }
    "optimize_discord" { Optimize-Discord }
    "optimize_steam" { Optimize-Steam }
    "optimize_brave" { Optimize-Brave }
    "fix_valorant" { Fix-Valorant }
    "per_game_profile" { Write-Dstx "Per-game profile picker is implemented in the C# UI layer next." }
    "fix_bluetooth" { Fix-Bluetooth }
    "repair_windows" { Repair-Windows }
    "export_report" { Export-Report }
    "restore_basic" { Restore-Basic }
    default {
        Write-Dstx ("Unknown action: " + $Action)
        exit 2
    }
}

exit 0
