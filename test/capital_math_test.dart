import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/capital/domain/capital_math.dart';
import 'package:kmsan/features/inventory/domain/models/product.dart';

Product p({
  required double purchase,
  required double sell,
  int quantity = 1,
}) =>
    Product(
      id: 'x',
      name: 'سلعة',
      purchasePrice: purchase,
      sellPrice: sell,
      quantity: quantity,
    );

void main() {
  group('رأس المال', () {
    test('يُحسب بسعر الشراء، والقيمة المنتظرة بسعر البيع', () {
      final summary = computeCapital(
        stock: [
          p(purchase: 1000, sell: 1800, quantity: 3),
          p(purchase: 500, sell: 900, quantity: 2),
        ],
        cash: 0,
        credits: 0,
      );

      expect(summary.stockCapital, 4000); // 3000 + 1000
      expect(summary.stockSellValue, 7200); // 5400 + 1800
      expect(summary.expectedProfit, 3200);
      expect(summary.typeCount, 2);
      expect(summary.pieceCount, 5);
    });

    test('مخزون فارغ لا يرمي ولا يقسم على صفر', () {
      final summary = computeCapital(stock: const [], cash: 0, credits: 0);
      expect(summary.stockCapital, 0);
      expect(summary.expectedProfit, 0);
    });
  });

  // ═══════════════════════════ وعاء الزكاة ═══════════════════════════
  //
  // المعادلة كما حدّدها صاحب المحل:
  //   (سعر بيع كل منتج × كميته) + كريديات الزبائن − دَين الموردين
  //   ثم × 2.5٪
  //
  // ⚠️ نقد الصندوق **خارج** الوعاء بطلبه الصريح — وكان داخلاً سابقاً.
  // الاختبار الأخير يثبّت هذا عمداً كي لا يعود أحد فيضيفه بحسن نيّة.

  group('وعاء الزكاة', () {
    test('المخزون بسعر البيع + الكريديات − دَين الموردين', () {
      final summary = computeCapital(
        stock: [p(purchase: 600, sell: 1000, quantity: 120)], // 120000
        cash: 30000,
        credits: 50000,
        supplierDebt: 20000,
      );

      // 120000 + 50000 − 20000 = 150000
      expect(summary.zakatBase, 150000);
      expect(summary.zakat, 3750); // ٢٫٥٪
    });

    test('النسبة ربع العشر بالضبط', () {
      expect(zakatRate, 0.025);
      final summary = computeCapital(
        stock: const [],
        cash: 0,
        credits: 1000000,
      );
      expect(summary.zakat, 25000);
    });

    test('🔒 الوعاء يستعمل سعر البيع لا سعر الشراء', () {
      final summary = computeCapital(
        stock: [p(purchase: 1, sell: 100, quantity: 10)],
        cash: 0,
        credits: 0,
      );
      // لو استُعمل سعر الشراء لكان الوعاء 10 لا 1000.
      expect(summary.zakatBase, 1000);
      expect(summary.stockCapital, 10);
    });

    test('كريديات الزبائن تزيد الوعاء بمقدارها', () {
      final without = computeCapital(stock: const [], cash: 0, credits: 0);
      final with_ = computeCapital(stock: const [], cash: 0, credits: 40000);
      expect(with_.zakatBase - without.zakatBase, 40000);
    });

    test('دَين الموردين يُنقص الوعاء بمقداره', () {
      final without = computeCapital(
        stock: const [],
        cash: 0,
        credits: 100000,
      );
      final with_ = computeCapital(
        stock: const [],
        cash: 0,
        credits: 100000,
        supplierDebt: 30000,
      );
      expect(without.zakatBase - with_.zakatBase, 30000);
    });

    test('🔒 نقد الصندوق خارج الوعاء — بطلب صاحب المحل', () {
      // لو أُعيد النقد إلى المعادلة يوماً فليسقط هذا الاختبار أوّلاً،
      // لا أن يتغيّر رقم الزكاة على صاحب المحل بلا أن ينتبه أحد.
      final poor = computeCapital(stock: const [], cash: 0, credits: 5000);
      final rich = computeCapital(stock: const [], cash: 900000, credits: 5000);
      expect(rich.zakatBase, poor.zakatBase);
      expect(rich.zakatBase, 5000);
    });

    test('🔒 دَين أكبر من الموجودات ⇒ وعاء صفر لا سالب', () {
      // محل مديون أكثر مما يملك لا زكاة عليه، و«زكاة سالبة» بلا معنى.
      final summary = computeCapital(
        stock: [p(purchase: 100, sell: 200, quantity: 10)], // 2000
        cash: 0,
        credits: 0,
        supplierDebt: 500000,
      );
      expect(summary.zakatBase, 0);
      expect(summary.zakat, 0);
    });

    test('محل فارغ: كل شيء صفر', () {
      final summary = computeCapital(stock: const [], cash: 0, credits: 0);
      expect(summary.zakatBase, 0);
      expect(summary.zakat, 0);
    });
  });
}
