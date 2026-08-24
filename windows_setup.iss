; ─────────────────────────────────────────────────────────────────
;  مثبّت KMSAN لويندوز — Inno Setup 6
;
;  الاستعمال:
;    1. flutter build windows --release
;    2. افتح هذا الملف بـ Inno Setup Compiler ثم Build → Compile
;       (أو من سطر الأوامر: ISCC.exe windows_setup.iss)
;    3. المثبّت يخرج في installer\KMSAN-Setup-<الإصدار>.exe
;
;  ⚠️ يحزم **مجلد Release كاملاً**: الـ exe وحده لا يعمل — يحتاج
;     flutter_windows.dll وملفات الإضافات ومجلد data (فيه الخطوط).
; ─────────────────────────────────────────────────────────────────

#define AppName "KMSAN"
#define AppVersion "1.0.0"
#define AppPublisher "KMSAN"
#define AppExeName "kmsan.exe"
#define BuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{6C8602DA-4DE8-4FA2-9D38-1D5F789F0BBF}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=installer
OutputBaseFilename=KMSAN-Setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
; واجهة المثبّت بالعربية من اليمين إلى اليسار
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
PrivilegesRequired=admin

[Languages]
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
; مجلد Release كاملاً — بما فيه data\flutter_assets (خطوط Amiri للطباعة)
Source: "{#BuildDir}\{#AppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
  Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; ملفات الإعدادات المحلية (الطابعة والمعايرة) تُترك للمستخدم عمداً —
; إعادة التثبيت لا تفقد معايرة الطابعة.
Type: filesandordirs; Name: "{app}\data"
