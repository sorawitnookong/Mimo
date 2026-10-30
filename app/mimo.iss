; Inno Setup script for Mimo. Run app\package.ps1 to collect the files and build it.

[Setup]
AppId={{7F5F1C9A-5A0B-4C0C-9E3B-4E8F2A6D1B10}
AppName=Mimo
AppVersion=0.1.1
AppPublisher=Mello
AppPublisherURL=https://github.com/sorawitnookong/Mimo
DefaultDirName={autopf}\Mimo
DefaultGroupName=Mimo
DisableProgramGroupPage=yes
DisableDirPage=no
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
LicenseFile=..\LICENSE
SetupIconFile=..\assets\mimo.ico
UninstallDisplayIcon={app}\Mimo.exe
OutputDir=..\dist
OutputBaseFilename=Mimo-Setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "..\dist\Mimo\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Mimo"; Filename: "{app}\Mimo.exe"
Name: "{autodesktop}\Mimo"; Filename: "{app}\Mimo.exe"

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""Mimo"" dir=in action=allow program=""{app}\receiver\bin\uxplay.exe"" enable=yes profile=private"; Flags: runhidden; StatusMsg: "Allowing Mimo through Windows Firewall..."
Filename: "{app}\Mimo.exe"; Description: "Open Mimo"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""Mimo"""; Flags: runhidden; RunOnceId: "RemoveFirewallRule"
