import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/cashbox/domain/models/cashbox_transaction.dart';
import 'package:kmsan/features/inventory/domain/models/product.dart';
import 'package:kmsan/features/sales/domain/models/sale.dart';
import 'package:kmsan/features/settings/domain/models/store_settings.dart';

void main() {
  group('🚫 تسريب بيانات إلى المتجر العام', () {
    const product = Product(
      id: 'p1',
      name: 'فستان',
      barcode: '12345678',
      purchasePrice: 1200,
      sellPrice: 3500,
      supplier: 'مورّد الجملة',
      quantity: 5,
      description: 'قطن',
      category: 'فساتين',
      sizes: ['40', '42'],
      colors: ['أحمر'],
      images: ['https://example.com/a.jpg'],
    );

    test('المرآة العامة لا تحوي سعر الشراء ولا المورّد ولا الباركود', () {
      final publicMap = product.toPublicMap();

      // هذه الحقول يقرأها أي زائر على الإنترنت لو تسرّبت.
      expect(publicMap.containsKey('purchasePrice'), isFalse,
          reason: 'سعر الشراء يكشف هامش الربح للمنافسين وللزبائن');
      expect(publicMap.containsKey('supplier'), isFalse,
          reason: 'المورّد يكشف مصدر البضاعة');
      expect(publicMap.containsKey('barcode'), isFalse,
          reason: 'الباركود يسمح بتخمين مخزون المحل');
      expect(publicMap.containsKey('quantity'), isFalse);
      expect(publicMap.containsKey('reserved'), isFalse);
      expect(publicMap.containsKey('imagePublicIds'), isFalse);
    });

    test('المرآة تحوي بالضبط الحقول المسموح بها — لا أكثر', () {
      // لو أضفت حقلاً جديداً إلى toPublicMap فسيسقط هذا الاختبار عمداً،
      // حتى تسأل نفسك: «هل أقبل أن يراه أي شخص في العالم؟».
      const allowed = {
        'name',
        'description',
        'sellPrice',
        'category',
        'images',
        'sizes',
        'colors',
        'inStock',
        'publishedToStore',
        'updatedAt',
      };
      expect(product.toPublicMap().keys.toSet(), allowed);
    });

    test('inStock يحترم المحجوز لطلبات المتجر', () {
      const reservedAll = Product(id: 'p2', name: 'x', quantity: 3, reserved: 3);
      expect(reservedAll.availableQuantity, 0);
      expect(reservedAll.toPublicMap()['inStock'], isFalse);

      const partly = Product(id: 'p3', name: 'x', quantity: 3, reserved: 1);
      expect(partly.availableQuantity, 2);
      expect(partly.toPublicMap()['inStock'], isTrue);
    });

    test('الكمية المتاحة لا تصير سالبة أبداً', () {
      const oversold = Product(id: 'p4', name: 'x', quantity: 1, reserved: 5);
      expect(oversold.availableQuantity, 0);
    });

    // ── هوية المتجر: المرآة الثانية التي يقرأها العالم ──
    const settings = StoreSettings(
      pinHash: 'a3f1c9…تجزئة الرقم السرّي',
      vipDiscountPercent: 15,
      categories: ['قمصان'],
      sizes: ['L'],
      logoBase64: 'iVBORw0KGgoAAAANSUhEUg...شعار مصغَّر',
      storefrontUrl: 'https://assil.vercel.app',
      storeName: 'الأصيل',
      storeTagline: 'قمصان رجالية',
      storePhone: '0555000000',
      facebookUrl: 'https://facebook.com/asil',
      instagramUrl: 'https://instagram.com/asil',
    );

    test('🔒 مرآة المتجر لا تحوي تجزئة الرقم السرّي ولا أي إعداد داخلي', () {
      final map = settings.toStorefrontMap();

      expect(map.containsKey('pinHash'), isFalse,
          reason: 'تجزئة الرقم السرّي تُتيح كسره بالقوة الغاشمة دون حدود');
      expect(map.containsKey('vipDiscountPercent'), isFalse,
          reason: 'نسبة خصم VIP شأن داخلي بين صاحب المحل وزبوناته');
      expect(map.containsKey('lastDayClose'), isFalse);
      expect(map.containsKey('categories'), isFalse);
      expect(map.containsKey('sizes'), isFalse);
      expect(map.containsKey('colors'), isFalse);

      // 🔒 الشعار تحديداً: عشرات الكيلوبايتات تُقرأ بلا مصادقة عند كل
      // زيارة، ومستند عام سقفه ميغابايت. الموقع له نسخته في public/.
      expect(map.containsKey('logoBase64'), isFalse,
          reason: 'الشعار ثقيل ولا داعي لتحميله من Firestore في كل زيارة');
    });

    test('مرآة المتجر تحوي بالضبط ما تسمح به قواعد Firestore — لا أكثر', () {
      // 🔒 هذه المجموعة نسخة طبق الأصل من hasOnly([...]) في firestore.rules.
      // لو أضفت حقلاً هنا ونسيت القواعد، رفضت Firestore الكتابة كاملةً
      // وبقي الموقع على بيانات قديمة بصمت — فليسقط الاختبار أوّلاً.
      const allowed = {
        'storeName',
        'tagline',
        'phone',
        'facebookUrl',
        'instagramUrl',
        'updatedAt',
      };
      expect(settings.toStorefrontMap().keys.toSet(), allowed);
    });
  });

  group('سحب الأرباح ليس مصروفاً', () {
    CashboxTransaction tx(CashboxType type, {String note = ''}) =>
        CashboxTransaction(id: 't', type: type, amount: 5000, note: note);

    test('النوع المستقلّ يُصنَّف سحب أرباح لا مصروفاً', () {
      final t = tx(CashboxType.profitWithdrawal);
      expect(t.isProfitWithdrawal, isTrue);
      expect(t.isRealExpense, isFalse);
    });

    test('المصروف العادي يبقى مصروفاً', () {
      final t = tx(CashboxType.expense, note: 'فاتورة الكهرباء');
      expect(t.isProfitWithdrawal, isFalse);
      expect(t.isRealExpense, isTrue);
    });

    test('التوافق الرجعي: حركات قديمة تُعرف بملاحظتها', () {
      // بيانات أشهر مضت سُجّلت كمصروف قبل وجود نوع مستقلّ. لو صنّفناها
      // مصاريف لأفسدت كل تقارير الفترات السابقة.
      for (final note in [
        'إغلاق الصندوق',
        'سحب أرباح',
        'إغلاق الصندوق ليوم 12/05',
        'سحب أرباح نهاية الأسبوع',
      ]) {
        final t = tx(CashboxType.expense, note: note);
        expect(t.isProfitWithdrawal, isTrue, reason: 'الملاحظة: $note');
        expect(t.isRealExpense, isFalse, reason: 'الملاحظة: $note');
      }
    });

    test('ملاحظة تشبه سحب الأرباح لكنها ليست منه', () {
      final t = tx(CashboxType.expense, note: 'شراء قفل للصندوق');
      expect(t.isProfitWithdrawal, isFalse);
      expect(t.isRealExpense, isTrue);
    });

    test('الدخل لا يُصنَّف سحب أرباح مهما كانت الملاحظة', () {
      final t = tx(CashboxType.income, note: 'إغلاق الصندوق');
      expect(t.isProfitWithdrawal, isFalse);
      expect(t.isRealExpense, isFalse);
    });

    test('أثر الحركة على رصيد الصندوق', () {
      expect(tx(CashboxType.income).signedAmount, 5000);
      expect(tx(CashboxType.deposit).signedAmount, 5000);
      expect(tx(CashboxType.expense).signedAmount, -5000);
      expect(tx(CashboxType.profitWithdrawal).signedAmount, -5000);
    });
  });

  group('حساب الفاتورة', () {
    Sale build({double discount = 0, double vipDiscount = 0}) {
      const items = [
        SaleItem(
          productId: 'a',
          name: 'قميص',
          quantity: 2,
          unitPrice: 1000,
          purchasePrice: 600,
        ),
        SaleItem(
          productId: 'b',
          name: 'بنطال',
          quantity: 1,
          unitPrice: 2000,
          purchasePrice: 1400,
        ),
      ];
      const subtotal = 4000.0; // 2×1000 + 2000
      return Sale(
        id: 'inv1',
        items: items,
        subtotal: subtotal,
        discount: discount,
        vipDiscount: vipDiscount,
        total: subtotal - discount - vipDiscount,
      );
    }

    test('الكلفة والفائدة بلا تخفيض', () {
      final s = build();
      expect(s.subtotal, 4000);
      expect(s.cost, 2600); // 2×600 + 1400
      expect(s.total, 4000);
      expect(s.profit, 1400);
      expect(s.pieceCount, 3);
    });

    test('التخفيض يُنقص الفائدة — لا يُبتلع بصمت', () {
      final s = build(discount: 500);
      expect(s.total, 3500);
      expect(s.profit, 900);
    });

    test('خصم VIP يُنقص الفائدة أيضاً', () {
      final s = build(vipDiscount: 400);
      expect(s.total, 3600);
      expect(s.profit, 1000);
    });

    test('عنوان الفاتورة أسماء منتجاتها لا رقمها', () {
      expect(build().productsTitle, 'قميص + بنطال');
    });

    test('عنوان فاتورة بأكثر من سلعتين يُختصر', () {
      const items = [
        SaleItem(productId: 'a', name: 'قميص', quantity: 1, unitPrice: 1, purchasePrice: 0),
        SaleItem(productId: 'b', name: 'بنطال', quantity: 1, unitPrice: 1, purchasePrice: 0),
        SaleItem(productId: 'c', name: 'حذاء', quantity: 1, unitPrice: 1, purchasePrice: 0),
        SaleItem(productId: 'd', name: 'حزام', quantity: 1, unitPrice: 1, purchasePrice: 0),
      ];
      const s = Sale(id: 'i', items: items, subtotal: 4, total: 4);
      expect(s.productsTitle, 'قميص + بنطال + 2 أخرى');
    });

    test('رقم الفاتورة مشتقّ من المعرّف وثابت', () {
      const s = Sale(id: 'AbC123dEf456', items: [], subtotal: 0, total: 0);
      // 'AbC123dEf456' → أحرف كبيرة → آخر 8 محارف.
      expect(s.invoiceNumber, 'TB-23DEF456');
      expect(s.invoiceNumber.length, 11); // 'TB-' + 8

      // معرّف أقصر من 8 محارف لا يرمي استثناءً.
      const short = Sale(id: 'ab1', items: [], subtotal: 0, total: 0);
      expect(short.invoiceNumber, 'TB-AB1');
    });

    test('الكريدي: الباقي دين', () {
      const s = Sale(
        id: 'i',
        items: [],
        subtotal: 5000,
        total: 5000,
        paidAmount: 2000,
        paymentMethod: PaymentMethod.credit,
      );
      expect(s.remaining, 3000);
    });

    test('البيع النقدي: المدفوع = الإجمالي تلقائياً', () {
      const s = Sale(id: 'i', items: [], subtotal: 5000, total: 5000);
      expect(s.paidAmount, 5000);
      expect(s.remaining, 0);
    });
  });
}
