; DSTX Tweaks final installer script
; Output installer file: setup.exe
; Installed app executable: dstx.exe

#define MyAppName "DSTX Tweaks"
#define MyAppVersion "0.8.3"
#define MyAppPublisher "DSTX"
#define MyAppExeName "dstx.exe"

[Setup]
AppId={{B44B43B4-7634-4F0D-9C70-4AA9E2A8E931}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\DSTX Tweaks
DefaultGroupName={#MyAppName}
OutputDir=..\installer-output
OutputBaseFilename=setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#MyAppExeName}
DisableProgramGroupPage=yes
SetupLogging=yes

[Files]
Source: "..\publish\win-x64\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\DSTX Tweaks"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\DSTX Tweaks"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: checkedonce

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch DSTX Tweaks"; Flags: nowait postinstall skipifsilent runascurrentuser

[UninstallDelete]
Type: filesandordirs; Name: "{commonappdata}\DSTX-Tweaks\Temp"
