; ─────────────────────────────────────────────────────────────────
;  مثبّت KMSAN لويندوز — Inno Setup 6
;
;  الاستعمال:
;    1. flutter build windows --release
;    2. ضع vc_redist.x64.exe في مجلد installer\
;       (حمّله من https://aka.ms/vs/17/release/vc_redist.x64.exe)
;    3. افتح هذا الملف بـ Inno Setup Compiler ثم Build → Compile
;       (أو من سطر الأوامر: ISCC.exe windows_setup.iss)
;    4. المثبّت يخرج في installer\KMSAN-Setup-<الإصدار>.exe
;
;  ⚠️ يحزم **مجلد Release كاملاً**: الـ exe وحده لا يعمل — يحتاج
;     flutter_windows.dll وملفات الإضافات ومجلد data (فيه الخطوط).
;
;  ✅ يثبّت Visual C++ Redistributable 2015-2022 تلقائياً لحل مشاكل:
;     MSVCP140.dll و VCRUNTIME140.dll و VCRUNTIME140_1.dll
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

; ── Visual C++ Redistributable 2015-2022 (x64) ──────────────────────────────
; يُحزم مع المثبّت ويُشغَّل بصمت قبل الإطلاق الأول.
; يُصلح أخطاء: MSVCP140.dll  VCRUNTIME140.dll  VCRUNTIME140_1.dll
Source: "installer\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; \
  Tasks: desktopicon

[Run]
; ── 1: تثبيت VC++ Redistributable بصمت إن لم يكن مثبّتاً بعد ──────────────
; /install /quiet /norestart  = بلا نوافذ ولا إعادة تشغيل إجبارية.
; المعلمة /norestart آمنة: إن احتاج النظام إعادة تشغيل يُخبر المستخدم
;   عبر المثبّت الرئيسي بعد اكتمال [Run].
Filename: "{tmp}\vc_redist.x64.exe"; \
  Parameters: "/install /quiet /norestart"; \
  StatusMsg: "تثبيت Visual C++ Redistributable..."; \
  Flags: waituntilterminated

; ── 2: إطلاق التطبيق بعد التثبيت ───────────────────────────────────────────
Filename: "{app}\{#AppExeName}"; \
  Description: "{cm:LaunchProgram,{#AppName}}"; \
  Flags: nowait postinstall skipifsilent

[UninstallDelete]
; ملفات الإعدادات المحلية (الطابعة والمعايرة) تُترك للمستخدم عمداً —
; إعادة التثبيت لا تفقد معايرة الطابعة.
Type: filesandordirs; Name: "{app}\data"
