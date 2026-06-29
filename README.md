# DSTX Tweaks v0.8.3 Release Pipeline

This build adds a proper release pipeline around the WPF app.

## Final naming

```text
Installer artifact: installer-output\setup.exe
Installed app:      C:\Program Files\DSTX Tweaks\dstx.exe
Data folder:        C:\ProgramData\DSTX-Tweaks\
```

## New in v0.8.3

- GitHub Actions workflow: `.github/workflows/build-release.yml`
- Automated Windows build.
- PowerShell syntax validation.
- JSON catalog validation.
- Action ID validation against `run-action.ps1`.
- Self-contained win-x64 publish.
- Inno Setup compilation to `setup.exe`.
- SHA256 generation.
- `update.metadata.json` generation.
- Optional code signing if GitHub secrets are configured.
- ProgramData structure for Logs, Backups, Reports, State, Profiles, Updates and Temp.
- Base lifecycle model: Detect / Apply / Undo / Verify.
- `actions.schema.json`.
- `danger.catalog.json`.

## How to build locally on Windows

Install requirements:

- .NET 8 SDK
- Inno Setup 6

Then run:

```bat
Build_Release_Pipeline_Local.bat
```

Output:

```text
installer-output\setup.exe
installer-output\setup.exe.sha256
installer-output\update.metadata.json
```

## How to build on GitHub

1. Put this folder in a GitHub repo.
2. Push to `main`.
3. Open the Actions tab.
4. Run `build-release`.
5. Download the `DSTX-Tweaks-setup` artifact.

## Optional signing

Add repository secrets:

```text
SIGNING_CERTIFICATE_BASE64
SIGNING_CERTIFICATE_PASSWORD
```

The pipeline will sign `dstx.exe` and `setup.exe` if those secrets exist. If not, signing is skipped.

## Important

This environment cannot compile WPF Windows executables. The project must be built on Windows or GitHub Actions `windows-latest`.
