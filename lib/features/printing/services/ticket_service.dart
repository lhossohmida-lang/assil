import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../inventory/domain/models/product.dart';
import '../domain/models/print_settings.dart';
import 'built_document.dart';
import 'pdf_fonts.dart';
import '../../../core/i18n/app_strings.dart';

/// عدد وحدات (modules) رمز Code128 لبيانات معيّنة.
///
/// «الوحدة» هي أرفع خط ممكن في الرمز؛ كل شيء آخر مضاعفاتها.
///
/// كيف نحسبها: نرسم الرمز بعرض 1، فيصير عرض كل خط كسراً من الواحد،
/// وأرفع خط = 1/عدد الوحدات. نعكس الكسر فنحصل على العدد.
/// لماذا هكذا ولا نستدعي `convert()` مباشرة: الصنف `Barcode1D` الذي يملك
/// `convert` غير مُصدَّر من المكتبة، فلا سبيل إليه من خارجها.
int code128ModuleCount(String data) {
  if (data.isEmpty) return 0;
  final elements = bc.Barcode.code128().make(
    data,
    width: 1,
    height: 1,
    drawText: false,
  );

  var thinnest = double.infinity;
  for (final e in elements) {
    if (e is bc.BarcodeBar && e.black && e.width > 0 && e.width < thinnest) {
      thinnest = e.width;
    }
  }
  if (thinnest == double.infinity || thinnest <= 0) return 0;
  return (1 / thinnest).round();
}

/// قياسات باركود مطبوع على ملصق.
class BarcodeMetrics {
  const BarcodeMetrics({
    required this.modules,
    required this.dotsPerModule,
    required this.widthMm,
    required this.dotMm,
    required this.availableWidthMm,
  });

  /// عدد وحدات الرمز (يشمل رموز البداية والنهاية ورقم التحقّق).
  final int modules;

  /// كم نقطة طابعة يأخذ أرفع خط. **هذا هو الرقم الذي يقرّر المقروئية.**
  final int dotsPerModule;

  /// العرض النهائي للرمز.
  final double widthMm;

  final double dotMm;
  final double availableWidthMm;

  /// المنطقة الصامتة الفعلية على كل جانب (الفراغ الأبيض حول الرمز).
  double get quietZoneMm => (availableWidthMm - widthMm) / 2;

  /// المنطقة الصامتة بالوحدات — معيار Code128 يشترط 10 وحدات على الأقل.
  double get quietZoneModules =>
      dotsPerModule == 0 ? 0 : quietZoneMm / (dotsPerModule * dotMm);

  /// هل يُتوقّع أن تقرأه كاميرا هاتف؟
  ///
  /// 3 نقاط فأكثر = ممتاز. نقطتان = على الحافة (الطابعة تقرّب بعض الخطوط
  /// لـ2 وبعضها لـ3 فتتفاوت السماكات). أقلّ من نقطتين = لا يُقرأ.
  bool get isReadable => dotsPerModule >= 3;
  bool get isMarginal => dotsPerModule == 2;

  String get qualityLabel {
    if (dotsPerModule >= 3) return tr('ممتاز');
    if (dotsPerModule == 2) return tr('على الحافة');
    return tr('لا يُقرأ');
  }
}

/// يحسب عرض الباركود كـ **مضاعف صحيح لنقطة الطابعة**.
///
/// العطل الذي يعالجه هذا الحساب (مقيس لا مُخمَّن):
/// كان الباركود يُمدّ ليملأ عرض الملصق، فيصير عرض الوحدة 2.1 نقطة مثلاً.
/// الطابعة لا تطبع أجزاء نقطة: تقرّب بعض الخطوط إلى 2 وبعضها إلى 3، فتخرج
/// سماكات متفاوتة لا يقبلها أي مفكّك رموز. الحلّ أن يكون عرض الوحدة عدداً
/// صحيحاً من النقاط، فتتساوى كل الخطوط تماماً.
///
/// الـ +20 وحدة هي المنطقة الصامتة: 10 وحدات فراغ أبيض على كل جانب.
/// معيار Code128 يشترطها، وبدونها لا يُقرأ الرمز مهما كان واضحاً.
BarcodeMetrics computeBarcodeMetrics({
  required String data,
  required double availableWidthMm,
  required int dpi,
}) {
  final modules = code128ModuleCount(data);
  final dotMm = 25.4 / dpi;
  if (modules <= 0 || availableWidthMm <= 0) {
    return BarcodeMetrics(
      modules: 0,
      dotsPerModule: 0,
      widthMm: 0,
      dotMm: dotMm,
      availableWidthMm: availableWidthMm,
    );
  }

  final raw = availableWidthMm / ((modules + 20) * dotMm);
  final k = raw.floor() < 1 ? 1 : raw.floor();

  return BarcodeMetrics(
    modules: modules,
    dotsPerModule: k,
    widthMm: modules * k * dotMm,
    dotMm: dotMm,
    availableWidthMm: availableWidthMm,
  );
}

/// بناء تيكت الباركود (ملصق 40×20مم عادةً).
class TicketService {
  const TicketService();

  static Future<BuiltDocument> build({
    required Product product,
    required TicketSettings settings,
    int copies = 1,
  }) async {
    final theme = await PdfFonts.theme();

    final labelW = settings.labelWidthMm * PdfPageFormat.mm;
    final labelH = settings.labelHeightMm * PdfPageFormat.mm;
    // ارتفاع الصفحة = **الخطوة** (الملصق + الفجوة) لا الملصق وحده،
    // وإلا تراكمت الفجوات وانزاحت الطباعة عن الملصق بعد بضع قطع.
    final pageH = settings.effectivePitchMm * PdfPageFormat.mm;

    final offsetX = settings.offsetXMm * PdfPageFormat.mm;
    final offsetY = settings.offsetYMm * PdfPageFormat.mm;

    // العرض المتاح فعلاً للرمز بعد إزاحة المعايرة.
    final availableWidthMm =
        settings.labelWidthMm - settings.offsetXMm.abs() - 1.0;
    final metrics = computeBarcodeMetrics(
      data: product.barcode,
      availableWidthMm: availableWidthMm,
      dpi: settings.dpi,
    );

    final doc = pw.Document();
    final scale = settings.fontScale;

    for (var copy = 0; copy < copies.clamp(1, 200); copy++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(labelW, pageH, marginAll: 0),
          theme: theme,
          textDirection: pw.TextDirection.rtl,
          build: (context) => pw.Padding(
            padding: pw.EdgeInsets.only(
              left: offsetX > 0 ? offsetX : 0,
              right: offsetX < 0 ? -offsetX : 0,
              top: offsetY > 0 ? offsetY : 0,
            ),
            // المحتوى محصور في **ارتفاع الملصق** لا الخطوة: ما يتجاوزه
            // يقع في الفجوة بين الملصقين فلا يُطبع على شيء.
            child: pw.SizedBox(
              height: labelH,
              width: labelW,
              child: pw.Container(
                decoration: settings.drawCalibrationFrame
                    ? pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.black,
                          width: 0.4,
                        ),
                      )
                    : null,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 1,
                  vertical: 1,
                ),
                child: _labelContent(
                  product: product,
                  settings: settings,
                  metrics: metrics,
                  scale: scale,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bytes = await doc.save();
    return BuiltDocument(bytes, PdfPageFormat(labelW, pageH));
  }

  static pw.Widget _labelContent({
    required Product product,
    required TicketSettings settings,
    required BarcodeMetrics metrics,
    required double scale,
  }) {
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (settings.showStoreName)
          pw.Text(
            AppConstants.storeDisplayName,
            style: pw.TextStyle(
              fontSize: 5 * scale,
              fontWeight: pw.FontWeight.bold,
            ),
            maxLines: 1,
          ),
        pw.Text(
          product.name,
          style: pw.TextStyle(fontSize: 6 * scale),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          textAlign: pw.TextAlign.center,
        ),
        // الباركود يأخذ ما تبقّى من الارتفاع: النصوص فوقه وتحته لها
        // ارتفاع ثابت، فلو أعطينا الباركود ارتفاعاً ثابتاً أيضاً لفاض
        // المحتوى و**أسقط محرّك pdf آخر عنصر بصمت** (يختفي السعر).
        pw.Expanded(
          child: pw.Center(
            child: metrics.modules <= 0
                ? pw.SizedBox()
                : pw.SizedBox(
                    // ⚠️ عرض محسوب — **لا تمدّه ليملأ الملصق أبداً**.
                    width: metrics.widthMm * PdfPageFormat.mm,
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: product.barcode,
                      drawText: false,
                      color: PdfColors.black,
                      padding: pw.EdgeInsets.zero,
                      margin: pw.EdgeInsets.zero,
                    ),
                  ),
          ),
        ),
        if (settings.showBarcodeText)
          pw.Text(
            product.barcode,
            style: pw.TextStyle(fontSize: 5 * scale, letterSpacing: 0.5),
            maxLines: 1,
          ),
        if (settings.showPrice)
          pw.Text(
            '${product.sellPrice.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
            style: pw.TextStyle(
              fontSize: 7 * scale,
              fontWeight: pw.FontWeight.bold,
            ),
            maxLines: 1,
          ),
      ],
    );
  }
}
