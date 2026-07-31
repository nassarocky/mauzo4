[Setup]
AppId={{8B8F14A3-9A07-4F69-8B77-90EFD8F693E4}}
AppName=Mauzo
AppVersion=3.2
AppPublisher=Mauzo
AppPublisherURL=https://example.com
DefaultDirName={pf}\Mauzo
DefaultGroupName=Mauzo
UninstallDisplayIcon={app}\mauzo.exe
OutputDir=..\..\dist\windows
OutputBaseFilename=MauzoSetup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=admin
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\\Mauzo"; Filename: "{app}\\mauzo.exe"; IconFilename: "..\\runner\\resources\\app_icon.ico"
Name: "{commondesktop}\\Mauzo"; Filename: "{app}\\mauzo.exe"; Tasks: desktopicon; IconFilename: "..\\runner\\resources\\app_icon.ico"

[Run]
Filename: "{app}\\mauzo.exe"; Description: "Launch Mauzo"; Flags: nowait postinstall skipifsilent
