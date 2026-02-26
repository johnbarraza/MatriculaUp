[Setup]
AppName=MatriculaUp
AppVersion=1.4
AppPublisher=MatriculaUp
DefaultDirName={autopf}\MatriculaUp
DefaultGroupName=MatriculaUp
OutputBaseFilename=MatriculaUp_v1.4_Setup
OutputDir=..\dist
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Flutter app files
Source: "..\matriculaup_app\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Default JSON course files
Source: "..\input\courses_2026-1_v1.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\input\efe_courses_2026-1_v1.json"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\MatriculaUp"; Filename: "{app}\matriculaup_app.exe"
Name: "{group}\{cm:UninstallProgram,MatriculaUp}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MatriculaUp"; Filename: "{app}\matriculaup_app.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\matriculaup_app.exe"; Description: "{cm:LaunchProgram,MatriculaUp}"; Flags: nowait postinstall skipifsilent
