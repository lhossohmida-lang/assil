import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/app_constants.dart';
import '../../../shared/utils/formatters.dart';
import '../domain/models/print_settings.dart';
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
  }) async {
    final theme = await PdfFonts.theme();
    final width = settings.widthMm * PdfPageFormat.mm;
    final height = settings.heightMm * PdfPageFormat.mm;
    final s = settings.fontScale;

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
            pw.Center(
              child: pw.Text(
                AppConstants.storeDisplayName,
                style: pw.TextStyle(
                  fontSize: 18 * s,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
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
            _row(tr('الإجمالي'), money(data.total), s, bold: true, big: true),
            if (data.deposit > 0) ...[
              _row(tr('العربون المدفوع'), money(data.deposit), s),
              _row(tr('الباقي عند الاستلام'), money(data.remaining), s,
                  bold: true, big: true),
            ],
            if (data.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                trf('ملاحظة: {0}', [data.notes]),
                style: pw.TextStyle(fontSize: 9 * s),
                maxLines: 3,
              ),
            ],
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
}
