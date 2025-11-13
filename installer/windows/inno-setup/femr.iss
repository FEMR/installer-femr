#define MyAppName "fEMR"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "FEMR"
#define MyAppURL "https://github.com/FEMR/femr"
#define MyAppExeName "femr-launcher.exe"

[Setup]
AppId={{8F6C5E21-24B4-4A13-9D8E-E3B6F1BECC3E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\output
OutputBaseFilename=femr-setup
SetupIconFile=..\femr.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Scripts
Source: "..\scripts\setup.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\scripts\launcher.ps1"; DestDir: "{app}"; Flags: ignoreversion

; Docker related files
Source: "..\..\common\femr-images.tar"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\common\docker-compose.yml"; DestDir: "{app}"; Flags: ignoreversion

; Icon
Source: "..\femr.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; IconFilename: "{app}\femr.ico"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; Tasks: desktopicon

[Run]
; Run the setup script automatically after installation
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -NoProfile -File ""{app}\setup.ps1"""; StatusMsg: "Setting up WSL and Docker (this may take several minutes)..."; Flags: runhidden waituntilterminated

[UninstallRun]
; Stop fEMR service and cleanup
Filename: "powershell.exe"; Parameters: "-ExecutionPolicy Bypass -File ""{app}\launcher.ps1"" -Stop"; Flags: runhidden waituntilterminated
Filename: "wsl.exe"; Parameters: "--unregister Ubuntu"; Flags: runhidden waituntilterminated