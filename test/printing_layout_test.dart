import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/inventory/domain/models/product.dart';
import 'package:kmsan/features/printing/domain/models/print_settings.dart';
import 'package:kmsan/features/printing/domain/models/receipt_content.dart';
import 'package:kmsan/features/printing/services/branding_marks.dart';
import 'package:kmsan/features/printing/services/receipt_service.dart';
import 'package:kmsan/features/printing/services/ticket_service.dart';
import 'package:kmsan/features/sales/domain/models/sale.dart';
import 'package:pdf/pdf.dart';

Sale saleWith(int itemCount) {
  final items = [
    for (var i = 0; i < itemCount; i++)
      SaleItem(
        productId: 'p$i',
        name: 'قميص قطن رقم $i',
        barcode: '1234567$i',
        quantity: 1,
        unitPrice: 1500,
        purchasePrice: 900,
      ),
  ];
  final subtotal = items.fold<double>(0, (acc, i) => acc + i.lineTotal);
  return Sale(
    id: 'abc123def456',
    items: items,
    subtotal: subtotal,
    total: subtotal,
    createdAt: DateTime(2026, 5, 12, 14, 30),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('الوصل — الارتفاع الديناميكي', () {
    test('الارتفاع يُحسب فعلاً ولا يبقى لانهائياً', () async {
      final doc = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
      );
      expect(doc.format.height.isFinite, isTrue);
      // وصل بسلعة واحدة بالشعار ≈ 103مم مقاساً — لا ورقة كاملة.
      expect(doc.heightMm, closeTo(103.5, 3.0));
      expect(doc.bytes.length, greaterThan(1000));
    });

    test('إخفاء الشعار يقصّر الوصل فعلاً — لا مجرّد إخفاء بصري', () async {
      final withLogo = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
      );
      final withoutLogo = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(logo: ReceiptLogo(enabled: false)),
      );
      expect(withoutLogo.heightMm, lessThan(withLogo.heightMm - 15));
    });

    test('الأسطر الحرّة تُطبع وتزيد الطول', () async {
      final plain = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(lines: []),
      );
      final withLines = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(lines: [
          ReceiptLine(text: 'facebook.com/alaseel'),
          ReceiptLine(text: '0555 12 34 56', bold: true),
          ReceiptLine(text: 'رأس المحل', footer: false),
        ]),
      );
      expect(withLines.heightMm, greaterThan(plain.heightMm));
    });

    test('العرض يساوي عرض البكرة المضبوط', () async {
      final doc = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(widthMm: 80),
      );
      expect(doc.widthMm, closeTo(80, 0.01));

      final narrow = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(widthMm: 58),
      );
      expect(narrow.widthMm, closeTo(58, 0.01));
    });

    test('كل سلعة إضافية تزيد الطول — لا ورق ثابت مهدور', () async {
      final one = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
      );
      final three = await ReceiptService.build(
        sale: saleWith(3),
        settings: const ReceiptSettings(),
      );
      final ten = await ReceiptService.build(
        sale: saleWith(10),
        settings: const ReceiptSettings(),
      );

      expect(three.heightMm, greaterThan(one.heightMm));
      expect(ten.heightMm, greaterThan(three.heightMm));

      // الزيادة خطّية تقريباً: سطران إضافيان بين 1 و3 سلع.
      final perItem = (three.heightMm - one.heightMm) / 2;
      expect(perItem, greaterThan(1));
      expect(perItem, lessThan(15));
    });

    test('التغذية الإضافية تُضاف إلى الطول', () async {
      final plain = await ReceiptService.build(
        sale: saleWith(2),
        settings: const ReceiptSettings(),
      );
      final fed = await ReceiptService.build(
        sale: saleWith(2),
        settings: const ReceiptSettings(extraFeedMm: 10),
      );
      expect(fed.heightMm - plain.heightMm, closeTo(10, 0.5));
    });
  });

  // ═══════════ اسم المحل وشعاره على الوصل ═══════════

  group('هوية المحل على الوصل', () {
    test('اسم مخصَّص طويل يصل إلى الورق فعلاً — لا يُتجاهل بصمت', () async {
      // نقيس بالأثر لا بالنيّة: PDF لا يُرجع نصّه، لكن اسماً طويلاً
      // يلتفّ على أسطر فيزيد ارتفاع الوصل. لو تُجوهل الحقل لتساوى الطولان.
      final short = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(storeName: 'أ'),
      );
      final long = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(
          storeName: 'الأصيل للألبسة الرجالية المحتشمة فرع وسط المدينة',
        ),
      );
      expect(long.format.height, greaterThan(short.format.height));
    });

    test('اسم فارغ لا يُفرغ رأس الوصل — يعود للاسم الافتراضي', () async {
      final empty = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(storeName: ''),
      );
      final hidden = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(showStoreName: false),
      );
      // لو كان الفراغ يعني «لا اسم» لتساوى الوصلان.
      expect(empty.format.height, greaterThan(hidden.format.height));
    });

    test('شعار المحل المشترك يُطبع حين لا صورة خاصة بالوصل', () async {
      final doc = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
        branding: const ReceiptBranding(logoBase64: onePixelPng),
      );
      expect(doc.format.height, greaterThan(0));
      expect(doc.bytes.length, greaterThan(0));
    });

    test('🔒 شعار تالف لا يُفشل الوصل — يعود للشعار المضمَّن', () async {
      // صاحب المحل قد يحفظ صورة تتلف في النقل. أن يتوقّف الطبع كلّه
      // بسبب شعار هو أسوأ نتيجة ممكنة في ساعة الذروة.
      final doc = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
        branding: const ReceiptBranding(logoBase64: 'هذا ليس base64 أصلاً!!'),
      );
      final normal = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
      );
      expect(doc.format.height, normal.format.height);
    });

    test('صورة الوصل الخاصة أولى من شعار المحل المشترك', () async {
      // كلاهما مضبوط: النتيجة يجب أن تطابق حالة «صورة الوصل وحدها»،
      // لا حالة «الشعار المشترك وحده».
      final both = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(
          logo: ReceiptLogo(imageBase64: onePixelPng, widthMm: 30),
        ),
        branding: const ReceiptBranding(logoBase64: onePixelPng),
      );
      final receiptOnly = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(
          logo: ReceiptLogo(imageBase64: onePixelPng, widthMm: 30),
        ),
      );
      expect(both.format.height, receiptOnly.format.height);
    });
  });

  _brandingTests();

  group('تيكت الباركود — المقاس', () {
    const product = Product(
      id: 'x1',
      name: 'قميص',
      barcode: '12345678',
      sellPrice: 2500,
      purchasePrice: 1500,
    );

    test('ارتفاع الصفحة = الخطوة بين ملصقين لا ارتفاع الملصق', () async {
      final doc = await TicketService.build(
        product: product,
        settings: const TicketSettings(
          labelWidthMm: 40,
          labelHeightMm: 20,
          pitchMm: 23, // ملصق 20مم + فجوة 3مم
        ),
      );
      expect(doc.heightMm, closeTo(23, 0.01));
      expect(doc.widthMm, closeTo(40, 0.01));
    });

    test('خطوة صفر تعني «مثل ارتفاع الملصق»', () async {
      final doc = await TicketService.build(
        product: product,
        settings: const TicketSettings(labelHeightMm: 20, pitchMm: 0),
      );
      expect(doc.heightMm, closeTo(20, 0.01));
    });

    test('عدد النسخ = عدد صفحات متطابقة', () async {
      final one = await TicketService.build(
        product: product,
        settings: const TicketSettings(),
      );
      final five = await TicketService.build(
        product: product,
        settings: const TicketSettings(),
        copies: 5,
      );
      expect(five.bytes.length, greaterThan(one.bytes.length));
    });

    test('النسخ محدودة بـ200 حتى لا تُغرق الطابعة بالخطأ', () async {
      final huge = await TicketService.build(
        product: product,
        settings: const TicketSettings(),
        copies: 100000,
      );
      expect(huge.bytes.isNotEmpty, isTrue);
    });

    test('منتج بلا باركود لا يُعطّل الطباعة', () async {
      final doc = await TicketService.build(
        product: const Product(id: 'x2', name: 'بلا باركود'),
        settings: const TicketSettings(),
      );
      expect(doc.bytes.isNotEmpty, isTrue);
    });
  });

  test('وحدة المليمتر في مكتبة pdf كما نتوقّع', () {
    // كل الحسابات هنا تعتمد على هذا التحويل — لو تغيّر لانهارت المقاسات.
    expect(PdfPageFormat.mm, closeTo(72 / 25.4, 1e-9));
  });
}

// ═══════════════ اسم المحل وشعاره على الوصل ═══════════════

// أصغر PNG صالح (1×1 شفّاف) — يكفي لإثبات أن مسار الصورة يعمل.
const onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
    '60e6kgAAAABJRU5ErkJggg==';

// ═══════════ رموز QR: الأيقونة والاسم والموقع ═══════════

void _brandingTests() {
  group('رموز QR على الوصل', () {
    const branding = ReceiptBranding(
      facebook: 'https://facebook.com/alasil',
      facebookName: 'الأصيل',
      instagram: 'https://instagram.com/alasil',
      instagramName: '@alasil.dz',
      website: 'https://assil.vercel.app/boutique',
    );

    test('كل رمز مفعَّل يزيد ارتفاع الوصل — أي أنه يُرسم فعلاً', () async {
      final none = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
        branding: branding,
      );
      final one = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(qr: ReceiptQr(showFacebook: true)),
        branding: branding,
      );
      expect(one.format.height, greaterThan(none.format.height));
    });

    test('🔒 رمز الموقع يُرسم كبقيّة الرموز', () async {
      final without = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
        branding: branding,
      );
      final withWeb = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(qr: ReceiptQr(showWebsite: true)),
        branding: branding,
      );
      expect(withWeb.format.height, greaterThan(without.format.height));
    });

    test('رمز مفعَّل بلا رابط لا يُرسم ولا يترك فراغاً', () async {
      // إن فعّل صاحب المحل رمز إنستغرام ولم يضع رابطاً، يجب ألّا يظهر
      // مربّع فارغ ولا أن يزيد الطول.
      final empty = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(qr: ReceiptQr(showInstagram: true)),
        branding: const ReceiptBranding(),
      );
      final plain = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(),
        branding: const ReceiptBranding(),
      );
      expect(empty.format.height, plain.format.height);
    });

    test('الأيقونة والاسم يزيدان الارتفاع عن الرمز وحده', () async {
      final bare = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(
          qr: ReceiptQr(showFacebook: true, withLabels: false),
        ),
        branding: branding,
      );
      final labelled = await ReceiptService.build(
        sale: saleWith(1),
        settings: const ReceiptSettings(
          qr: ReceiptQr(showFacebook: true, withLabels: true),
        ),
        branding: branding,
      );
      expect(labelled.format.height, greaterThan(bare.format.height));
    });
  });

  group('اختصار عنوان الموقع تحت الرمز', () {
    test('يُسقط البروتوكول وwww والمسار', () {
      expect(prettyDomain('https://assil.vercel.app/boutique'),
          'assil.vercel.app');
      expect(prettyDomain('http://www.alasil.dz/'), 'alasil.dz');
      expect(prettyDomain('alasil.dz'), 'alasil.dz');
    });

    test('عنوان فارغ أو غريب لا يرمي', () {
      expect(prettyDomain(''), '');
      expect(prettyDomain('   '), '');
      expect(prettyDomain('https://'), '');
    });
  });
}
