import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../shared/utils/formatters.dart';
import '../domain/models/print_settings.dart';
import '../domain/models/receipt_content.dart';
import 'branding_marks.dart';
import 'built_document.dart';
import 'pdf_fonts.dart';
import '../../../core/i18n/app_strings.dart';

class OrderLabelItem {
  const OrderLabelItem(this.name, this.quantity, this.price);
  final String name;
  final int quantity;
  final double price;
}

/// بيانات ملصق الشحن — مستقلّة عن نموذج الطلب حتى لا ترتبط الطباعة
/// بميزة المتجر الإلكتروني (وقد لا تكون مفعّلة أصلاً).
class OrderLabelData {
  const OrderLabelData({
    required this.orderNumber,
    required this.customerName,
    required this.phone,
    required this.wilaya,
    required this.items,
    required this.total,
    this.address = '',
    this.notes = '',
    this.deposit = 0,
    this.deliveryFee = 0,
  });

  final String orderNumber;
  final String customerName;
  final String phone;
  final String wilaya;
  final String address;
  final String notes;
  final List<OrderLabelItem> items;
  final double total;
  final double deposit;
  final double deliveryFee;

  double get remaining => (total - deposit).clamp(0, double.infinity);
}

/// ملصق شحن كبير (100×150مم عادةً) — يُلصق على الطرد.
class OrderLabelService {
  const OrderLabelService();

  static Future<BuiltDocument> build({
    required OrderLabelData data,
    required OrderLabelSettings settings,
    ReceiptBranding branding = ReceiptBranding.none,
  }) async {
    final theme = await PdfFonts.theme();
    final width = settings.widthMm * PdfPageFormat.mm;
    final height = settings.heightMm * PdfPageFormat.mm;
    final s = settings.fontScale;

    // نفس سلسلة الوصل: صورة خاصّة بالملصق ← شعار المحل ← المضمَّن.
    pw.ImageProvider? logoImage;
    if (settings.logo.enabled) {
      for (final encoded in [settings.logo.imageBase64, branding.logoBase64]) {
        if (encoded.isEmpty) continue;
        try {
          logoImage = pw.MemoryImage(Uint8List.fromList(base64Decode(encoded)));
          break;
        } catch (_) {
          logoImage = null; // صورة تالفة لا تُفشل الملصق.
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
        pageFormat: PdfPageFormat(
          width,
          height,
          marginAll: settings.marginMm * PdfPageFormat.mm,
        ),
        theme: theme,
        textDirection: pw.TextDirection.rtl,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logoImage != null)
              pw.Container(
                alignment: _align(settings.logo.align),
                margin: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Image(
                  logoImage,
                  width: settings.logo.widthMm * PdfPageFormat.mm,
                  height: settings.logo.widthMm * PdfPageFormat.mm,
                ),
              ),
            if (settings.showStoreName)
              pw.Container(
                alignment: _align(settings.storeNameAlign),
                child: pw.Text(
                  settings.storeName.trim().isEmpty
                      ? AppConstants.storeDisplayName
                      : settings.storeName.trim(),
                  style: pw.TextStyle(
                    fontSize: 18 * s,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            for (final line in settings.headerLines) _freeLine(line, s),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                trf('طلب رقم {0}', [data.orderNumber]),
                style: pw.TextStyle(fontSize: 11 * s),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),

            // بيانات الزبونة — أكبر خط على الملصق، يقرؤها موصّل الطرد.
            pw.Text(
              data.customerName,
              style: pw.TextStyle(
                fontSize: 20 * s,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              data.phone,
              style: pw.TextStyle(
                fontSize: 18 * s,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              data.wilaya,
              style: pw.TextStyle(fontSize: 15 * s),
            ),
            if (data.address.trim().isNotEmpty)
              pw.Text(
                data.address,
                style: pw.TextStyle(fontSize: 11 * s),
                maxLines: 3,
              ),

            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            pw.Text(
              tr('المنتجات'),
              style: pw.TextStyle(
                fontSize: 11 * s,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  for (final item in data.items)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              item.name,
                              style: pw.TextStyle(fontSize: 10 * s),
                              maxLines: 2,
                            ),
                          ),
                          pw.Text(
                            '×${item.quantity}',
                            style: pw.TextStyle(fontSize: 10 * s),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Text(
                            moneyPlain(item.price * item.quantity),
                            style: pw.TextStyle(fontSize: 10 * s),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            pw.Divider(thickness: 1),
            if (data.deliveryFee > 0)
              _row(tr('التوصيل'), money(data.deliveryFee), s),
            // الإجمالي يُطبع فقط حين يختلف عمّا سيُقبض، وإلا فهو سطر مكرّر.
            if (data.deposit > 0) _row(tr('الإجمالي'), money(data.total), s),

            // 🔒 الرقم الوحيد الذي يعني شيئاً لعامل التوصيل: كم يقبض.
            // العربون **لا يُطبع**: هو شأن بين المحل والزبون، ووجوده على
            // الملصق يدعو إلى الجدل عند الباب ولا يضيف للسائق شيئاً.
            _row(tr('مجموع عند الاستلام'), money(data.remaining), s,
                bold: true, big: true),
            if (data.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                trf('ملاحظة: {0}', [data.notes]),
                style: pw.TextStyle(fontSize: 9 * s),
                maxLines: 3,
              ),
            ],
            for (final line in settings.footerLines) _freeLine(line, s),
            if (settings.qr.any)
              brandingQrRow(qr: settings.qr, branding: branding, fontScale: s),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    return BuiltDocument(bytes, PdfPageFormat(width, height));
  }

  static pw.Widget _row(
    String key,
    String value,
    double s, {
    bool bold = false,
    bool big = false,
  }) {
    final style = pw.TextStyle(
      fontSize: (big ? 14 : 11) * s,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  static Uint8List? _bundledLogoBytes;

  /// يقرأ الشعار المضمَّن مرّة واحدة (انظر نظيره في `ReceiptService`).
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

  static pw.Alignment _align(ReceiptAlign a) => switch (a) {
        // الملصق يُطبع RTL، فـ start = يمين الورقة.
        ReceiptAlign.start => pw.Alignment.centerRight,
        ReceiptAlign.center => pw.Alignment.center,
        ReceiptAlign.end => pw.Alignment.centerLeft,
      };

  static pw.Widget _freeLine(ReceiptLine line, double s) {
    if (line.text.trim().isEmpty) return pw.SizedBox();
    return pw.Container(
      alignment: _align(line.align),
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Text(
        line.text,
        style: pw.TextStyle(
          fontSize: line.fontSize * s,
          fontWeight: line.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

}
