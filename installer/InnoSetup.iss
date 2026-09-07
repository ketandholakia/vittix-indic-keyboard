[Setup]
AppId={{5E5D1E1B-9430-4C3D-B91F-77EF1F7A5074}
AppName=Vittix Indic Keyboard
AppVersion=1.0.0.0
AppPublisher=Vittix
DefaultDirName={pf}\Vittix Indic Keyboard
DefaultGroupName=Vittix Indic Keyboard
AllowNoIcons=yes
LicenseFile=..\LICENSE.txt
OutputDir=..\build
OutputBaseFilename=VittixIndicKeyboardSetup
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\Win32\VittixIndicKeyboard.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\Win32\VittixIndicEditor.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\layouts\*"; DestDir: "{app}\layouts"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Vittix Indic Keyboard"; Filename: "{app}\VittixIndicKeyboard.exe"
Name: "{group}\Vittix Layout Editor"; Filename: "{app}\VittixIndicEditor.exe"
Name: "{group}\{cm:UninstallProgram,Vittix Indic Keyboard}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\Vittix Indic Keyboard"; Filename: "{app}\VittixIndicKeyboard.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\VittixIndicKeyboard.exe"; Description: "{cm:LaunchProgram,Vittix Indic Keyboard}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM VittixIndicKeyboard.exe"; Flags: runhidden
Filename: "{cmd}"; Parameters: "/C taskkill /F /IM VittixIndicEditor.exe"; Flags: runhidden
