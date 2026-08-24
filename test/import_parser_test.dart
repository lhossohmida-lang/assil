import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/import_products/data/xlsx_codec.dart';
import 'package:kmsan/features/import_products/domain/import_parser.dart';
import 'package:kmsan/features/inventory/domain/models/product.dart';

void main() {
  group('xlsx ذهاباً وإياباً', () {
    test('ما نكتبه نقرؤه كما هو', () {
      const rows = [
        ['الاسم', 'الباركود', 'سعر الشراء'],
        ['قميص قطن', '12345678', '1100'],
        ['بنطال "مميّز" & رخيص', '87654321', '2200'],
      ];

      final bytes = XlsxCodec.writeRows(rows);
      final back = XlsxCodec.readRows(bytes);

      expect(back.length, 3);
      expect(back[0], rows[0]);
      expect(back[1], rows[1]);
      // المحارف الخاصة في XML لا تُفسد الملف.
      expect(back[2][0], 'بنطال "مميّز" & رخيص');
    });

    test('الملف النموذجي يُقرأ ويُحلَّل بنجاح', () {
      final bytes = XlsxCodec.writeRows(templateRows());
      final preview = parseRows(
        XlsxCodec.readRows(bytes),
        existingByBarcode: const {},
      );

      expect(preview.isUsable, isTrue);
      expect(preview.createCount, 2);
      expect(preview.errorCount, 0);
      expect(preview.rows.first.product!.name, 'قميص قطن أبيض');
      expect(preview.rows.first.product!.sizes, ['40', '42', '44']);
    });
  });

  group('CSV', () {
    test('يقرأ الفاصلة والفاصلة المنقوطة والاقتباس', () {
      final commaBytes = CsvCodec.write([
        ['الاسم', 'سعر البيع'],
        ['قميص, قطن', '1800'],
      ]);
      final back = CsvCodec.readRows(commaBytes);
      expect(back[1][0], 'قميص, قطن');
      expect(back[1][1], '1800');
    });

    test('BOM لا يُفسد أول عمود', () {
      final bytes = CsvCodec.write([
        ['الاسم'],
        ['قميص'],
      ]);
      final back = CsvCodec.readRows(bytes);
      expect(back[0][0], 'الاسم');
    });
  });

  group('مطابقة الرؤوس', () {
    test('عربية وإنجليزية معاً', () {
      final mapping = mapHeaders(
        ['name', 'الباركود', 'purchase_price', 'سعر البيع', 'qty'],
      );
      expect(mapping['name'], 0);
      expect(mapping['barcode'], 1);
      expect(mapping['purchasePrice'], 2);
      expect(mapping['sellPrice'], 3);
      expect(mapping['quantity'], 4);
    });

    test('عمود إلزامي ناقص يمنع الاستيراد برسالة واضحة', () {
      final preview = parseRows(
        [
          ['الاسم', 'الكمية'],
          ['قميص', '5'],
        ],
        existingByBarcode: const {},
      );
      expect(preview.isUsable, isFalse);
      expect(preview.missingColumns, contains('سعر الشراء'));
      expect(preview.missingColumns, contains('سعر البيع'));
    });
  });

  group('التحقّق من الصفوف', () {
    List<List<String>> withRow(List<String> row) => [
          ['الاسم', 'الباركود', 'سعر الشراء', 'سعر البيع', 'الكمية'],
          row,
        ];

    test('صف سليم = جديد', () {
      final preview = parseRows(
        withRow(['قميص', '11112222', '1000', '1800', '4']),
        existingByBarcode: const {},
      );
      expect(preview.createCount, 1);
      expect(preview.rows.first.product!.quantity, 4);
    });

    test('باركود موجود = سيُحدَّث', () {
      final preview = parseRows(
        withRow(['قميص', '11112222', '1000', '1800', '4']),
        existingByBarcode: {
          '11112222': const Product(id: 'existing1', name: 'قديم'),
        },
      );
      expect(preview.updateCount, 1);
      expect(preview.rows.first.existingId, 'existing1');
    });

    test('سعر ليس رقماً ⇒ خطأ عربي يذكر الصف والقيمة', () {
      final preview = parseRows(
        withRow(['قميص', '', 'غير رقم', '1800', '4']),
        existingByBarcode: const {},
      );
      expect(preview.errorCount, 1);
      expect(preview.rows.first.error, contains('سعر الشراء'));
      expect(preview.rows.first.error, contains('الصف 2'));
      expect(preview.rows.first.error, contains('غير رقم'));
    });

    test('اسم فارغ ⇒ خطأ', () {
      final preview = parseRows(
        withRow(['', '', '1000', '1800', '4']),
        existingByBarcode: const {},
      );
      expect(preview.errorCount, 1);
      expect(preview.rows.first.error, contains('الاسم'));
    });

    test('الصفوف الفارغة تُتجاهل بصمت ولا تُعدّ أخطاءً', () {
      final preview = parseRows(
        [
          ['الاسم', 'سعر الشراء', 'سعر البيع', 'الكمية'],
          ['قميص', '1000', '1800', '4'],
          ['', '', '', ''],
          ['   ', '', '', ''],
          ['بنطال', '2000', '3000', '2'],
        ],
        existingByBarcode: const {},
      );
      expect(preview.rows.length, 2);
      expect(preview.errorCount, 0);
      expect(preview.createCount, 2);
    });

    test('صف خاطئ لا يُفشل بقيّة الملف', () {
      final preview = parseRows(
        [
          ['الاسم', 'سعر الشراء', 'سعر البيع', 'الكمية'],
          ['قميص', '1000', '1800', '4'],
          ['بنطال', 'خطأ', '3000', '2'],
          ['حذاء', '500', '900', '7'],
        ],
        existingByBarcode: const {},
      );
      expect(preview.createCount, 2);
      expect(preview.errorCount, 1);
    });

    test('أرقام عربية وفاصلة عشرية عربية تُقرأ', () {
      final preview = parseRows(
        withRow(['قميص', '', '١٠٠٠٫٥٠', '1 800,25', '٤']),
        existingByBarcode: const {},
      );
      expect(preview.errorCount, 0);
      expect(preview.rows.first.product!.purchasePrice, 1000.5);
      expect(preview.rows.first.product!.sellPrice, 1800.25);
      expect(preview.rows.first.product!.quantity, 4);
    });

    test('قيمة سالبة مرفوضة', () {
      final preview = parseRows(
        withRow(['قميص', '', '-100', '1800', '4']),
        existingByBarcode: const {},
      );
      expect(preview.errorCount, 1);
    });
  });

  group('سياسة التكرار', () {
    const existing = Product(
      id: 'e1',
      name: 'قميص قديم',
      barcode: '11112222',
      purchasePrice: 900,
      sellPrice: 1500,
      quantity: 10,
      images: ['https://cdn/a.jpg'],
      reserved: 2,
      publishedToStore: false,
    );
    const imported = Product(
      id: '',
      name: 'قميص جديد',
      barcode: '11112222',
      purchasePrice: 1000,
      sellPrice: 1800,
      quantity: 5,
    );

    test('تخطّي: لا شيء يتغيّر', () {
      final result = applyPolicy(
        imported: imported,
        existing: existing,
        policy: DuplicatePolicy.skip,
      );
      expect(result.quantity, 10);
      expect(result.sellPrice, 1500);
      expect(result.name, 'قميص قديم');
    });

    test('🔒 جمع الكميات: الكمية تتراكم والأسعار تُحدَّث', () {
      final result = applyPolicy(
        imported: imported,
        existing: existing,
        policy: DuplicatePolicy.addQuantity,
      );
      expect(result.quantity, 15, reason: '10 موجودة + 5 مستلمة');
      expect(result.purchasePrice, 1000);
      expect(result.sellPrice, 1800);
    });

    test('استبدال: البيانات من الملف لكن الصور والحجز والنشر تبقى', () {
      final result = applyPolicy(
        imported: imported,
        existing: existing,
        policy: DuplicatePolicy.replace,
      );
      expect(result.id, 'e1');
      expect(result.name, 'قميص جديد');
      expect(result.quantity, 5);
      // ما ليس في الملف أصلاً لا يُمحى.
      expect(result.images, ['https://cdn/a.jpg']);
      expect(result.reserved, 2);
      expect(result.publishedToStore, isFalse);
    });
  });
}
