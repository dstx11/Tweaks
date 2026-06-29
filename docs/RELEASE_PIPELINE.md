# DSTX Tweaks v0.8.3 Release Pipeline

## Pipeline flow

1. Checkout
2. Setup .NET 8 SDK
3. Install Inno Setup
4. Validate PowerShell
5. Validate JSON catalogs
6. dotnet restore
7. dotnet build
8. dotnet publish win-x64 self-contained
9. Optional signing
10. Inno Setup compile
11. Optional signing of setup.exe
12. SHA256 checksum
13. update.metadata.json
14. Upload artifacts

## Release artifacts

- setup.exe
- setup.exe.sha256
- update.metadata.json
- publish/win-x64 folder

## Signing secrets

- SIGNING_CERTIFICATE_BASE64
- SIGNING_CERTIFICATE_PASSWORD

## Local output

`installer-output\setup.exe`
