import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/inventory/domain/models/product.dart';
import 'package:kmsan/features/inventory/presentation/providers/inventory_providers.dart';

Product p({
  required String id,
  required int quantity,
  int minQuantity = 3,
  String category = 'قمصان',
}) =>
    Product(
      id: id,
      name: 'منتج $id',
      quantity: quantity,
      minQuantity: minQuantity,
      category: category,
      purchasePrice: 100,
      sellPrice: 200,
    );

void main() {
  group('إحصاء المخزون', () {
    final stock = [
      p(id: '1', quantity: 10), // سليم
      p(id: '2', quantity: 2), // قارب النفاد
      p(id: '3', quantity: 0), // نفد
      p(id: '4', quantity: 0), // نفد
      p(id: '5', quantity: 3), // على الحدّ تماماً = قارب النفاد
    ];

    test('عدّ الأنواع والقطع', () {
      final s = computeStats(stock);
      expect(s.typeCount, 5);
      expect(s.pieceCount, 15);
    });

    test('«نفد» = الكمية صفر فقط', () {
      expect(computeStats(stock).outOfStockCount, 2);
    });

    test('«قارب النفاد» يشمل ما نفد — والفرق بينهما هو المعروض', () {
      final s = computeStats(stock);
      // isLowStock = quantity <= minQuantity، والصفر ≤ أي حدّ.
      expect(s.lowStockCount, 4);
      // ما تعرضه بطاقة «قارب النفاد» = ما قارب ولم ينفد بعد.
      expect(s.lowStockCount - s.outOfStockCount, 2);
    });

    test('🔒 الكمية على الحدّ تماماً تُعدّ «قارب النفاد» لا سليمة', () {
      // منتج حدّه 3 وكميته 3: تركه خارج التنبيه يعني أن صاحب المحل
      // يكتشف نفاده حين يطلبه زبون.
      final single = computeStats([p(id: 'x', quantity: 3, minQuantity: 3)]);
      expect(single.lowStockCount, 1);
      expect(single.outOfStockCount, 0);
    });

    test('مخزون فارغ لا يرمي', () {
      final s = computeStats(const []);
      expect(s.typeCount, 0);
      expect(s.outOfStockCount, 0);
      expect(s.lowStockCount, 0);
      expect(s.capitalValue, 0);
    });

    test('القيم المالية بسعري الشراء والبيع', () {
      final s = computeStats([p(id: '1', quantity: 4)]);
      expect(s.capitalValue, 400);
      expect(s.sellValue, 800);
    });
  });
}
