# DSTX Tweaks final app packaging spec

## Naming

- Installer: `setup.exe`
- Installed executable: `dstx.exe`
- Install directory: `C:\Program Files\DSTX Tweaks`
- Shortcut: `DSTX Tweaks`

## Installer behavior

- Requires admin.
- Copies published self-contained app files.
- Creates Start Menu shortcut.
- Creates Desktop shortcut.
- Offers to launch the app after install.
- Adds uninstall entry.

## App behavior

- `dstx.exe` asks for admin through app manifest.
- Runs PowerShell backend scripts hidden/no-console where possible.
- Uses ProgramData for logs/backups/reports.
- Uses WinGet for optional third-party app installs.
- Does not require .NET runtime after publishing self-contained.

## Build requirements

- Windows x64.
- .NET 8 SDK.
- Inno Setup 6.
- WinGet/App Installer.
