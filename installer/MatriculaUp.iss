[Setup]
AppName=MatriculaUp
AppVersion=1.0
AppPublisher=MatriculaUp
DefaultDirName={autopf}\MatriculaUp
DefaultGroupName=MatriculaUp
OutputBaseFilename=MatriculaUp_v1_Setup
OutputDir=..\dist
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\MatriculaUp\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\MatriculaUp"; Filename: "{app}\MatriculaUp.exe"
Name: "{group}\{cm:UninstallProgram,MatriculaUp}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\MatriculaUp"; Filename: "{app}\MatriculaUp.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\MatriculaUp.exe"; Description: "{cm:LaunchProgram,MatriculaUp}"; Flags: nowait postinstall skipifsilent
