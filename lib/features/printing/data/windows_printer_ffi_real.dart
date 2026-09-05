import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

// ───────────────────── ثوابت ويندوز ─────────────────────

const int _dmOutBuffer = 2;
const int _dmInBuffer = 8;

/// ورق مخصّص. **ليس 0**: بعض الدرايفرات ترفض الصفر وتُبقي الفورم القديم.
const int _dmPaperUser = 256;

const int _dmOrientationField = 0x00000001;
const int _dmPaperSizeField = 0x00000002;
const int _dmPaperLengthField = 0x00000004;
const int _dmPaperWidthField = 0x00000008;

const int _printerAccessUse = 0x00000008;

const int _physicalWidth = 110;
const int _physicalHeight = 111;
const int _logPixelsX = 88;
const int _logPixelsY = 90;

// إزاحات حقول DEVMODEW بالبايت (x64 و x86 سواء — البنية معبّأة ثابتة).
const int _offDmSize = 68;
const int _offDmFields = 72;
const int _offDmOrientation = 76;
const int _offDmPaperSize = 78;
const int _offDmPaperLength = 80;
const int _offDmPaperWidth = 82;

// ───────────────────── توقيعات الدوال ─────────────────────

typedef _OpenPrinterWC = Int32 Function(
    Pointer<Utf16>, Pointer<IntPtr>, Pointer<Uint8>);
typedef _OpenPrinterWD = int Function(
    Pointer<Utf16>, Pointer<IntPtr>, Pointer<Uint8>);

typedef _ClosePrinterC = Int32 Function(IntPtr);
typedef _ClosePrinterD = int Function(int);

typedef _DocumentPropertiesWC = Int32 Function(
    IntPtr, IntPtr, Pointer<Utf16>, Pointer<Uint8>, Pointer<Uint8>, Uint32);
typedef _DocumentPropertiesWD = int Function(
    int, int, Pointer<Utf16>, Pointer<Uint8>, Pointer<Uint8>, int);

typedef _SetPrinterWC = Int32 Function(IntPtr, Uint32, Pointer<Uint8>, Uint32);
typedef _SetPrinterWD = int Function(int, int, Pointer<Uint8>, int);

typedef _CreateDCWC = IntPtr Function(
    Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint8>);
typedef _CreateDCWD = int Function(
    Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Uint8>);

typedef _DeleteDCC = Int32 Function(IntPtr);
typedef _DeleteDCD = int Function(int);

typedef _GetDeviceCapsC = Int32 Function(IntPtr, Int32);
typedef _GetDeviceCapsD = int Function(int, int);

/// قياس صفحة الجهاز كما يراها الدرايفر فعلاً.
class PaperMeasurement {
  const PaperMeasurement({
    required this.widthMm,
    required this.heightMm,
    required this.dpiX,
    required this.dpiY,
  });

  final double widthMm;
  final double heightMm;
  final int dpiX;
  final int dpiY;

  @override
  String toString() =>
      '${widthMm.toStringAsFixed(1)}×${heightMm.toStringAsFixed(1)}مم '
      '(${dpiX}dpi)';
}

/// نتيجة محاولة ضبط ورق الدرايفر.
class PaperApplyResult {
  const PaperApplyResult({
    required this.applied,
    required this.message,
    this.before,
    this.after,
  });

  /// نجح الضبط **وتحقّقنا منه بالقياس** — لا بمجرّد نجاح النداء.
  final bool applied;
  final String message;
  final PaperMeasurement? before;
  final PaperMeasurement? after;
}

/// ضبط مقاس ورق الدرايفر على ويندوز عبر winspool/gdi32 مباشرة.
///
/// ═══ العطل الذي يعالجه هذا الملف كله ═══
/// طابعة الملصقات كانت تُخرج ملصقاً فارغاً أو اثنين قبل/بعد كل تيكت.
/// السبب المقاس: الدرايفر يتقدّم بمقدار **الفورم المضبوط فيه** (كان
/// 72×297مم!) لا بمقدار الصفحة التي نرسلها. ومكتبة `printing` تبني
/// DEVMODE **مصفَّراً** بلا بيانات الدرايفر الخاصة (dmDriverExtra)،
/// فيتجاهله الدرايفر كلياً ويبقى على فورمه.
///
/// الحلّ: نأخذ DEVMODE **الحقيقي** من الدرايفر نفسه، نعدّل فيه مقاس الورق،
/// نمرّره عليه ليصحّحه، نحفظه افتراضياً للمستخدم، ثم **نقيس** أن الصفحة
/// صارت فعلاً بمقاس الملصق قبل أن نصدّق أن الضبط نجح.
class WindowsPrinterFfi {
  WindowsPrinterFfi._();

  static bool get isAvailable {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  static DynamicLibrary? _winspool;
  static DynamicLibrary? _gdi32;

  static DynamicLibrary get _spool =>
      _winspool ??= DynamicLibrary.open('winspool.drv');
  static DynamicLibrary get _gdi => _gdi32 ??= DynamicLibrary.open('gdi32.dll');

  static _OpenPrinterWD get _openPrinter =>
      _spool.lookupFunction<_OpenPrinterWC, _OpenPrinterWD>('OpenPrinterW');
  static _ClosePrinterD get _closePrinter =>
      _spool.lookupFunction<_ClosePrinterC, _ClosePrinterD>('ClosePrinter');
  static _DocumentPropertiesWD get _documentProperties =>
      _spool.lookupFunction<_DocumentPropertiesWC, _DocumentPropertiesWD>(
          'DocumentPropertiesW');
  static _SetPrinterWD get _setPrinter =>
      _spool.lookupFunction<_SetPrinterWC, _SetPrinterWD>('SetPrinterW');

  static _CreateDCWD get _createDC =>
      _gdi.lookupFunction<_CreateDCWC, _CreateDCWD>('CreateDCW');
  static _DeleteDCD get _deleteDC =>
      _gdi.lookupFunction<_DeleteDCC, _DeleteDCD>('DeleteDC');
  static _GetDeviceCapsD get _getDeviceCaps =>
      _gdi.lookupFunction<_GetDeviceCapsC, _GetDeviceCapsD>('GetDeviceCaps');

  /// يقيس مقاس الصفحة الحالي للطابعة كما يراه الدرايفر.
  ///
  /// هذا هو **الرقم الوحيد الذي نثق به**: نجاح `SetPrinter` لا يعني أن
  /// الدرايفر قبل المقاس.
  static PaperMeasurement? measure(String printerName) {
    if (!isAvailable || printerName.trim().isEmpty) return null;

    final name = printerName.toNativeUtf16();
    var hdc = 0;
    try {
      hdc = _createDC(nullptr, name, nullptr, nullptr);
      if (hdc == 0) return null;

      final wPx = _getDeviceCaps(hdc, _physicalWidth);
      final hPx = _getDeviceCaps(hdc, _physicalHeight);
      final dpiX = _getDeviceCaps(hdc, _logPixelsX);
      final dpiY = _getDeviceCaps(hdc, _logPixelsY);
      if (dpiX <= 0 || dpiY <= 0) return null;

      return PaperMeasurement(
        widthMm: wPx * 25.4 / dpiX,
        heightMm: hPx * 25.4 / dpiY,
        dpiX: dpiX,
        dpiY: dpiY,
      );
    } catch (e) {
      debugPrint('[KMSAN] فشل قياس الطابعة: $e');
      return null;
    } finally {
      if (hdc != 0) _deleteDC(hdc);
      calloc.free(name);
    }
  }

  /// يضبط ورق الدرايفر على مقاس مخصّص ثم **يتحقّق بالقياس**.
  static PaperApplyResult applyCustomPaper({
    required String printerName,
    required double widthMm,
    required double heightMm,
  }) {
    if (!isAvailable) {
      return const PaperApplyResult(
        applied: false,
        message: 'ضبط ورق الدرايفر متاح على ويندوز فقط',
      );
    }
    if (printerName.trim().isEmpty) {
      return const PaperApplyResult(
        applied: false,
        message: 'لم تُختر طابعة',
      );
    }

    final before = measure(printerName);

    final name = printerName.toNativeUtf16();
    final handlePtr = calloc<IntPtr>();
    final defaults = calloc<Uint8>(24); // PRINTER_DEFAULTSW
    Pointer<Uint8> devIn = nullptr;
    Pointer<Uint8> devOut = nullptr;
    Pointer<Uint8> info9 = nullptr;
    var handle = 0;

    try {
      // DesiredAccess عند الإزاحة 16. PRINTER_ACCESS_USE يكفي لحفظ
      // «الافتراضي للمستخدم» (المستوى 9) — لا يحتاج صلاحيات مدير.
      (defaults + 16).cast<Uint32>().value = _printerAccessUse;

      if (_openPrinter(name, handlePtr, defaults) == 0) {
        return PaperApplyResult(
          applied: false,
          message: 'تعذّر فتح الطابعة «$printerName»',
          before: before,
        );
      }
      handle = handlePtr.value;

      // 1) حجم DEVMODE الحقيقي (يشمل بيانات الدرايفر الخاصة dmDriverExtra).
      final needed = _documentProperties(0, handle, name, nullptr, nullptr, 0);
      if (needed <= 0) {
        return PaperApplyResult(
          applied: false,
          message: 'الدرايفر لم يُعطِ حجم DEVMODE',
          before: before,
        );
      }

      // 2) اقرأ DEVMODE الحقيقي من الدرايفر — لا تبنِ واحداً مصفَّراً.
      devIn = calloc<Uint8>(needed);
      if (_documentProperties(0, handle, name, devIn, nullptr, _dmOutBuffer) !=
          1) {
        return PaperApplyResult(
          applied: false,
          message: 'تعذّرت قراءة إعدادات الدرايفر',
          before: before,
        );
      }

      // حارس: لا نكتب إلا داخل الجزء العام من DEVMODEW.
      // أي درايفر يُرجِع dmSize أصغر من نهاية dmPaperWidth يعني أن الكتابة
      // ستقع في بياناته الخاصة فتُفسدها.
      final dmSize = (devIn + _offDmSize).cast<Uint16>().value;
      if (dmSize < _offDmPaperWidth + 2) {
        return PaperApplyResult(
          applied: false,
          message: 'بنية DEVMODE غير متوقّعة من هذا الدرايفر (dmSize=$dmSize)',
          before: before,
        );
      }

      // 3) عدّل مقاس الورق (بأعشار المليمتر) وفعّل بتات الحقول المعدَّلة —
      //    الدرايفر يتجاهل أي حقل لم تُرفع رايته في dmFields.
      final fieldsPtr = (devIn + _offDmFields).cast<Uint32>();
      fieldsPtr.value = fieldsPtr.value |
          _dmPaperSizeField |
          _dmPaperLengthField |
          _dmPaperWidthField |
          _dmOrientationField;

      (devIn + _offDmOrientation).cast<Int16>().value = 1; // portrait
      (devIn + _offDmPaperSize).cast<Int16>().value = _dmPaperUser;
      (devIn + _offDmPaperWidth).cast<Int16>().value =
          (widthMm * 10).round().clamp(1, 32767);
      (devIn + _offDmPaperLength).cast<Int16>().value =
          (heightMm * 10).round().clamp(1, 32767);

      // 4) مرّره على الدرايفر ليصحّحه ويملأ ما ينقصه.
      devOut = calloc<Uint8>(needed);
      if (_documentProperties(
            0,
            handle,
            name,
            devOut,
            devIn,
            _dmInBuffer | _dmOutBuffer,
          ) !=
          1) {
        return PaperApplyResult(
          applied: false,
          message: 'الدرايفر رفض المقاس المطلوب',
          before: before,
        );
      }

      // 5) احفظه «افتراضياً للمستخدم» — المستوى 9.
      //    المستوى 2 يكتب الافتراضي للجهاز كله ويتطلّب صلاحيات مدير.
      info9 = calloc<Uint8>(sizeOf<IntPtr>());
      info9.cast<IntPtr>().value = devOut.address;
      final ok = _setPrinter(handle, 9, info9, 0);
      if (ok == 0) {
        return PaperApplyResult(
          applied: false,
          message: 'تعذّر حفظ مقاس الورق في الدرايفر',
          before: before,
        );
      }
    } catch (e) {
      return PaperApplyResult(
        applied: false,
        message: 'خطأ أثناء ضبط الورق: $e',
        before: before,
      );
    } finally {
      if (handle != 0) _closePrinter(handle);
      if (devIn != nullptr) calloc.free(devIn);
      if (devOut != nullptr) calloc.free(devOut);
      if (info9 != nullptr) calloc.free(info9);
      calloc.free(defaults);
      calloc.free(handlePtr);
      calloc.free(name);
    }

    // 6) ⚠️ لا تثق بالنجاح المعلَن — قِس.
    final after = measure(printerName);
    if (after == null) {
      return PaperApplyResult(
        applied: false,
        message: 'ضُبط المقاس لكن تعذّر التحقّق منه',
        before: before,
      );
    }

    const toleranceMm = 0.6;
    final okW = (after.widthMm - widthMm).abs() <= toleranceMm;
    final okH = (after.heightMm - heightMm).abs() <= toleranceMm;

    if (okW && okH) {
      return PaperApplyResult(
        applied: true,
        message: 'صفحة الجهاز الآن ${after.toString()}',
        before: before,
        after: after,
      );
    }
    return PaperApplyResult(
      applied: false,
      message: 'الدرايفر أبقى صفحته على ${after.toString()} '
          'بدل ${widthMm.toStringAsFixed(1)}×${heightMm.toStringAsFixed(1)}مم',
      before: before,
      after: after,
    );
  }
}
