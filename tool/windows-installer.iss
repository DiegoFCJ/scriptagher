#ifndef APP_VERSION
  #error "APP_VERSION is not defined"
#endif
#ifndef SOURCE_DIR
  #error "SOURCE_DIR is not defined"
#endif
#ifndef OUTPUT_DIR
  #error "OUTPUT_DIR is not defined"
#endif

[Setup]
AppId={{92D2E67D-59F5-4F6B-86E7-1F6C4B647C0D}}
AppName=Scriptagher
AppVersion={#APP_VERSION}
AppPublisher=Scriptagher
AppPublisherURL=https://github.com/scriptagher/scriptagher
AppSupportURL=https://github.com/scriptagher/scriptagher
AppUpdatesURL=https://github.com/scriptagher/scriptagher
DefaultDirName={autopf}\\Scriptagher
DisableProgramGroupPage=yes
OutputDir={#OUTPUT_DIR}
OutputBaseFilename=ScriptagherSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Files]
Source: "{#SOURCE_DIR}\\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion createallsubdirs

[Icons]
Name: "{autoprograms}\\Scriptagher"; Filename: "{app}\\Scriptagher.exe"
Name: "{autodesktop}\\Scriptagher"; Filename: "{app}\\Scriptagher.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\\Scriptagher.exe"; Description: "Launch Scriptagher"; Flags: nowait postinstall skipifsilent
