import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../printing/services/built_document.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../../core/i18n/app_strings.dart';

/// بيانات عيّنة للمعاينة والطباعة التجريبية.
class PrintSamples {
  PrintSamples._();

  static Sale get sale => Sale(
        id: 'sample01234',
        items: [
          SaleItem(
            productId: 'a',
            name: tr('قميص قطن أبيض'),
            barcode: '12345678',
            quantity: 2,
            unitPrice: 1800,
            purchasePrice: 1100,
          ),
          SaleItem(
            productId: 'b',
            name: tr('بنطال جينز'),
            barcode: '87654321',
            quantity: 1,
            unitPrice: 3500,
            purchasePrice: 2200,
          ),
        ],
        subtotal: 7100,
        discount: 100,
        total: 7000,
        customerName: tr('زبونة تجريبية'),
        createdByName: tr('البائع'),
        createdAt: DateTime(2026, 5, 12, 16, 45),
      );

  static final Product product = Product(
    id: 'sample',
    name: tr('قميص قطن أبيض'),
    barcode: '12345678',
    purchasePrice: 1100,
    sellPrice: 1800,
    quantity: 10,
  );
}

/// معاينة مرئية لمستند الطباعة.
///
/// ⚠️ الصورة مولّدة من **نفس الملف الذي يُرسَل للطابعة** — لا من رسم
/// تقريبي بـ Flutter. ما تراه هنا هو ما يخرج على الورق حرفياً.
class PrintPreview extends StatefulWidget {
  const PrintPreview({
    super.key,
    required this.build,
    required this.label,
    required this.signature,
    this.maxHeight = 320,
  });

  final Future<BuiltDocument> Function() build;
  final String label;

  /// بصمة الإعدادات المؤثّرة على هذه المعاينة.
  ///
  /// نُعيد التوليد عند تغيّرها فقط. لولاها لأعدنا بناء الـ PDF وتحويله
  /// صورةً في **كل** إعادة بناء للشاشة (كل ضغطة على أزرار الزيادة)،
  /// فتومض المعاينة وتبطؤ الإعدادات كلها.
  final String signature;

  final double maxHeight;

  @override
  State<PrintPreview> createState() => _PrintPreviewState();
}

class _PrintPreviewState extends State<PrintPreview> {
  Uint8List? _png;
  String? _error;
  String _size = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(PrintPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature != widget.signature) _generate();
  }

  Future<void> _generate() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doc = await widget.build();
      final raster = await Printing.raster(doc.bytes, dpi: 110).first;
      final png = await raster.toPng();
      if (!mounted) return;
      setState(() {
        _png = Uint8List.fromList(png);
        _size = trf('{0} × {1} مم', [doc.widthMm.toStringAsFixed(0), doc.heightMm.toStringAsFixed(0)]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.visibility, size: 16),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Text(
              _size,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: tr('تحديث المعاينة'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _generate,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: BoxDecoration(
            color: const Color(0xFFECEFF1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          padding: const EdgeInsets.all(10),
          child: _error != null
              ? Center(
                  child: Text(
                    trf('تعذّرت المعاينة: {0}', [_error]),
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : _png == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Center(
                        child: Container(
                          color: Colors.white,
                          child: Image.memory(_png!),
                        ),
                      ),
                    ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('الصورة مولّدة من نفس الملف الذي يُرسَل للطابعة.'),
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
