import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// خطوط الـ PDF.
///
/// ⚠️ الخطوط الافتراضية في مكتبة `pdf` (Helvetica وأخواتها) **لا ترسم
/// العربية إطلاقاً** — تخرج الوصولات فراغات بيضاء، بلا أي خطأ ولا تحذير.
/// لذلك كل صفحة في التطبيق تُبنى بـ `ThemeData.withFont` ومعها Amiri
/// المضمّن في assets، و`textDirection: rtl`.
class PdfFonts {
  PdfFonts._();

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.ThemeData? _theme;

  /// يُحمّل الخطوط مرة واحدة ويحتفظ بها — تحميلها لكل وصل يضيف تأخيراً
  /// محسوساً بين الضغط على «دفع» وخروج الورقة.
  static Future<pw.ThemeData> theme() async {
    if (_theme != null) return _theme!;
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Bold.ttf'));
    _theme = pw.ThemeData.withFont(base: _regular, bold: _bold);
    return _theme!;
  }

  /// تهيئة مسبقة عند إقلاع التطبيق حتى تكون أول طباعة سريعة كالبقية.
  static Future<void> warmUp() async {
    try {
      await theme();
    } catch (_) {
      // فشل تحميل الخط لا يمنع التطبيق من العمل — تظهر المشكلة عند الطباعة.
    }
  }
}
