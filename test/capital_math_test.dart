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

  group('وعاء الزكاة', () {
    test('يجمع ثلاثة بنود: المخزون بسعر البيع + النقد + الكريديات', () {
      final summary = computeCapital(
        stock: [p(purchase: 600, sell: 1000, quantity: 120)], // 120000
        cash: 30000,
        credits: 50000,
      );

      expect(summary.zakatBase, 200000);
      expect(summary.zakat, 5000); // ٢٫٥٪
    });

    test('النسبة ربع العشر بالضبط', () {
      expect(zakatRate, 0.025);
      final summary =
          computeCapital(stock: const [], cash: 1000000, credits: 0);
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

    test('ديون الزبائن تدخل الوعاء', () {
      final without =
          computeCapital(stock: const [], cash: 10000, credits: 0);
      final with_ =
          computeCapital(stock: const [], cash: 10000, credits: 40000);
      expect(with_.zakatBase - without.zakatBase, 40000);
    });

    test('محل فارغ: كل شيء صفر', () {
      final summary = computeCapital(stock: const [], cash: 0, credits: 0);
      expect(summary.zakatBase, 0);
      expect(summary.zakat, 0);
    });
  });
}
