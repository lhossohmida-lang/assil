import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../shared/utils/formatters.dart';
import '../../sales/domain/models/sale.dart';
import '../domain/models/print_settings.dart';
import '../domain/models/receipt_content.dart';
import 'built_document.dart';
import 'pdf_fonts.dart';
import '../../../core/i18n/app_strings.dart';

/// هوية المحل المشتركة بين الأجهزة كما تُطبع على الوصل:
/// روابط التواصل (رموز QR) وشعار المحل الذي اختاره صاحبه من الإعدادات.
///
/// منفصلة عن [ReceiptSettings] عمداً: تلك محلّية لكل جهاز (طابعته
/// ومعايرته)، وهذه مشتركة تأتي من Firestore.
class ReceiptBranding {
  const ReceiptBranding({
    this.facebook = '',
    this.instagram = '',
    this.logoBase64 = '',
  });

  final String facebook;
  final String instagram;

  /// شعار المحل المخصَّص (PNG مصغَّر، base64). فارغ ⇒ الشعار المضمَّن.
  final String logoBase64;

  static const ReceiptBranding none = ReceiptBranding();
}

/// بناء وصل البيع (بكرة 80مم عادةً).
class ReceiptService {
  const ReceiptService._();

  static Uint8List? _bundledLogoBytes;

  /// يقرأ الشعار المضمَّن مرة واحدة ويحتفظ به.
  ///
  /// القراءة من الحزمة عملية إدخال/إخراج، وطباعة عشرين وصلاً في ساعة
  /// الذروة تعني عشرين قراءة لنفس الملف بلا داعٍ.
  static Future<Uint8List?> _bundledLogo() async {
    if (_bundledLogoBytes != null) {
      return _bundledLogoBytes!.isEmpty ? null : _bundledLogoBytes;
    }
    try {
      final data = await rootBundle.load('assets/images/logo_mark.png');
      _bundledLogoBytes = data.buffer.asUint8List();
    } catch (_) {
      _bundledLogoBytes = Uint8List(0);
    }
    return _bundledLogoBytes!.isEmpty ? null : _bundledLogoBytes;
  }

  /// يبني الوصل بارتفاع **ديناميكي** حسب المحتوى.
  ///
  /// الحيلة: نطلب صفحة بارتفاع `double.infinity`؛ مكتبة pdf تحسب الارتفاع
  /// الفعلي أثناء التخطيط و**تكتبه في `page.pageFormat` بعد `save()`**.
  /// نقرأه من هناك ونرسله للطابعة كمقاس ورق نهائي — فلا ورق مهدور.
  static Future<BuiltDocument> build({
    required Sale sale,
    required ReceiptSettings settings,
    ReceiptBranding branding = ReceiptBranding.none,
  }) async {
    final theme = await PdfFonts.theme();
    final width = settings.widthMm * PdfPageFormat.mm;
    final margin = settings.marginMm * PdfPageFormat.mm;

    // الشعار: صورة اختارها المستخدم، وإلا الشعار المضمَّن.
    pw.ImageProvider? logoImage;
    if (settings.logo.enabled) {
      // الأولوية: صورة خاصّة بهذا الوصل ← شعار المحل المشترك ← المضمَّن.
      // صورة الوصل أوّلاً لأن من ضبطها ضبطها لهذه الطابعة تحديداً.
      for (final encoded in [
        settings.logo.imageBase64,
        branding.logoBase64,
      ]) {
        if (encoded.isEmpty) continue;
        try {
          logoImage = pw.MemoryImage(Uint8List.fromList(base64Decode(encoded)));
          break;
        } catch (_) {
          logoImage = null; // صورة تالفة — نجرّب التالية ولا نُفشل الوصل.
        }
      }
      if (logoImage == null) {
        final bundled = await _bundledLogo();
        if (bundled != null) logoImage = pw.MemoryImage(bundled);
      }
    }

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity, marginAll: margin),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        build: (context) => _content(
          sale: sale,
          settings: settings,
          branding: branding,
          logoImage: logoImage,
        ),
      ),
    );

    final bytes = await doc.save();

    // الارتفاع الذي حسبته المكتبة فعلاً — هذا هو المقاس الذي نطبع به.
    final computed = doc.document.pdfPageList.pages.first.pageFormat;
    return BuiltDocument(bytes, PdfPageFormat(width, computed.height));
  }

  static pw.Widget _content({
    required Sale sale,
    required ReceiptSettings settings,
    required ReceiptBranding branding,
    pw.ImageProvider? logoImage,
  }) {
    final s = settings.fontScale;

    pw.Widget logo() {
      final size = settings.logo.widthMm * PdfPageFormat.mm;
      final child = logoImage != null
          ? pw.Image(logoImage, width: size, height: size)
          : pw.SizedBox();
      return pw.Container(
        alignment: _alignment(settings.logo.align),
        margin: const pw.EdgeInsets.only(bottom: 4),
        child: child,
      );
    }

    final showLogo = settings.logo.enabled && logoImage != null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        if (showLogo && !settings.logo.footer) logo(),

        if (settings.showStoreName)
          pw.Container(
            alignment: _alignment(settings.storeNameAlign),
            child: pw.Text(
              settings.storeName.trim().isEmpty
                  ? AppConstants.storeDisplayName
                  : settings.storeName.trim(),
              style: pw.TextStyle(
                fontSize: 16 * s,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

        // أسطر الرأس الحرّة.
        for (final line in settings.headerLines) _line(line, s),

        pw.SizedBox(height: 4),
        _divider(),
        pw.SizedBox(height: 3),

        _kv(tr('رقم الفاتورة'), sale.invoiceNumber, s),
        _kv(tr('التاريخ'), formatDateTime(sale.createdAt ?? DateTime.now()), s),
        if (sale.customerName.trim().isNotEmpty)
          _kv(
            tr('الزبون'),
            sale.isVip ? '${sale.customerName} (VIP)' : sale.customerName,
            s,
          ),
        if (sale.createdByName.trim().isNotEmpty)
          _kv(tr('البائع'), sale.createdByName, s),

        pw.SizedBox(height: 3),
        _divider(),
        pw.SizedBox(height: 3),

        // رأس الجدول — في RTL أول عنصر في الـ Row يظهر على اليمين.
        _itemRow(tr('المنتج'), tr('الكمية'), tr('السعر'), tr('المجموع'), s, bold: true),
        pw.SizedBox(height: 2),
        for (final item in sale.items)
          _itemRow(
            item.name,
            '${item.quantity}',
            moneyPlain(item.unitPrice),
            moneyPlain(item.lineTotal),
            s,
          ),

        pw.SizedBox(height: 3),
        _divider(),
        pw.SizedBox(height: 3),

        _kv(tr('المجموع'), money(sale.subtotal), s),
        if (sale.vipDiscount > 0)
          _kv(tr('خصم VIP'), '- ${money(sale.vipDiscount)}', s),
        if (sale.discount > 0) _kv(tr('التخفيض'), '- ${money(sale.discount)}', s),

        pw.SizedBox(height: 3),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              tr('الإجمالي'),
              style: pw.TextStyle(
                fontSize: 14 * s,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              money(sale.total),
              style: pw.TextStyle(
                fontSize: 14 * s,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        _kv(tr('طريقة الدفع'), sale.paymentMethod.label, s),
        if (sale.paymentMethod == PaymentMethod.credit) ...[
          _kv(tr('المدفوع'), money(sale.paidAmount), s),
          _kv(tr('الباقي (دين)'), money(sale.remaining), s),
        ],

        pw.SizedBox(height: 6),
        _divider(),
        pw.SizedBox(height: 4),

        // أسطر الذيل الحرّة — فيسبوك، هاتف، شكر، أي شيء.
        for (final line in settings.footerLines) _line(line, s),

        if (settings.qr.any) _qrRow(settings, branding, s),

        if (showLogo && settings.logo.footer) ...[
          pw.SizedBox(height: 4),
          logo(),
        ],

        // تغذية إضافية بعد القصّ: بعض الطابعات تقصّ فوق آخر سطر مباشرة.
        if (settings.extraFeedMm > 0)
          pw.SizedBox(height: settings.extraFeedMm * PdfPageFormat.mm),
      ],
    );
  }

  static pw.Widget _qrRow(
    ReceiptSettings settings,
    ReceiptBranding branding,
    double s,
  ) {
    final size = settings.qr.sizeMm * PdfPageFormat.mm;
    final codes = <pw.Widget>[
      if (settings.qr.showFacebook && branding.facebook.isNotEmpty)
        _qr(tr('فيسبوك'), branding.facebook, size, settings.qr.withLabels, s),
      if (settings.qr.showInstagram && branding.instagram.isNotEmpty)
        _qr(tr('إنستغرام'), branding.instagram, size, settings.qr.withLabels, s),
    ];
    if (codes.isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: codes.length == 1
            ? pw.MainAxisAlignment.center
            : pw.MainAxisAlignment.spaceEvenly,
        children: codes,
      ),
    );
  }

  static pw.Widget _qr(
    String label,
    String data,
    double size,
    bool withLabel,
    double s,
  ) =>
      pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.SizedBox(
            width: size,
            height: size,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: data,
              drawText: false,
              padding: pw.EdgeInsets.zero,
              margin: pw.EdgeInsets.zero,
            ),
          ),
          if (withLabel)
            pw.Text(label, style: pw.TextStyle(fontSize: 7 * s)),
        ],
      );

  static pw.Widget _line(ReceiptLine line, double s) {
    if (line.text.trim().isEmpty) return pw.SizedBox();
    return pw.Container(
      alignment: _alignment(line.align),
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Text(
        line.text,
        textAlign: _textAlign(line.align),
        style: pw.TextStyle(
          fontSize: line.fontSize * s,
          fontWeight: line.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Alignment _alignment(ReceiptAlign a) => switch (a) {
        // RTL: «البداية» هي اليمين.
        ReceiptAlign.start => pw.Alignment.centerRight,
        ReceiptAlign.center => pw.Alignment.center,
        ReceiptAlign.end => pw.Alignment.centerLeft,
      };

  static pw.TextAlign _textAlign(ReceiptAlign a) => switch (a) {
        ReceiptAlign.start => pw.TextAlign.right,
        ReceiptAlign.center => pw.TextAlign.center,
        ReceiptAlign.end => pw.TextAlign.left,
      };

  static pw.Widget _divider() => pw.Container(
        height: 0.7,
        color: PdfColors.black,
      );

  static pw.Widget _kv(String key, String value, double s) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(key, style: pw.TextStyle(fontSize: 9 * s)),
            pw.Text(value, style: pw.TextStyle(fontSize: 9 * s)),
          ],
        ),
      );

  static pw.Widget _itemRow(
    String name,
    String qty,
    String price,
    String total,
    double s, {
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: 9 * s,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Text(name, style: style, maxLines: 2),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(qty, style: style, textAlign: pw.TextAlign.center),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(price, style: style, textAlign: pw.TextAlign.center),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(total, style: style, textAlign: pw.TextAlign.left),
          ),
        ],
      ),
    );
  }
}
