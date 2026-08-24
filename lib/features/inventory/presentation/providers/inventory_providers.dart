import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/inventory_repository.dart';
import '../../domain/models/product.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return InventoryRepository(ref.watch(firestoreProvider), storeId);
});

/// كل المنتجات كما هي في Firestore (العادية + الخاصة).
final allProductsProvider = StreamProvider<List<Product>>((ref) {
  final repo = ref.watch(inventoryRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll();
});

/// المخزون مرتّباً بالاسم — يستعمله نقطة البيع ورأس المال وشاشة المخزون.
final inventoryProvider = Provider<List<Product>>((ref) {
  final all = ref.watch(allProductsProvider).value ?? const <Product>[];
  final list = [...all];
  list.sort((a, b) => a.name.compareTo(b.name));
  return list;
});

/// إحصاءات شاشة المخزون.
class InventoryStats {
  const InventoryStats({
    required this.typeCount,
    required this.pieceCount,
    required this.lowStockCount,
    required this.capitalValue,
    required this.sellValue,
  });

  /// عدد الأنواع (مستندات المنتجات).
  final int typeCount;

  /// مجموع القطع.
  final int pieceCount;

  /// عدد الأنواع التي قاربت النفاد.
  final int lowStockCount;

  /// رأس المال = مجموع (سعر الشراء × الكمية).
  final double capitalValue;

  /// القيمة بسعر البيع (تدخل في وعاء الزكاة).
  final double sellValue;
}

InventoryStats computeStats(List<Product> products) {
  var pieces = 0;
  var low = 0;
  var capital = 0.0;
  var sell = 0.0;
  for (final p in products) {
    pieces += p.quantity;
    if (p.isLowStock) low++;
    capital += p.purchasePrice * p.quantity;
    sell += p.sellPrice * p.quantity;
  }
  return InventoryStats(
    typeCount: products.length,
    pieceCount: pieces,
    lowStockCount: low,
    capitalValue: capital,
    sellValue: sell,
  );
}

final inventoryStatsProvider = Provider<InventoryStats>(
  (ref) => computeStats(ref.watch(inventoryProvider)),
);

/// الفئات المستعملة فعلاً (لاقتراحها عند إضافة منتج).
final categoriesProvider = Provider<List<String>>((ref) {
  final set = <String>{};
  for (final p in ref.watch(allProductsProvider).value ?? const <Product>[]) {
    if (p.category.trim().isNotEmpty) set.add(p.category.trim());
  }
  final list = set.toList()..sort();
  return list;
});

final suppliersProvider = Provider<List<String>>((ref) {
  final set = <String>{};
  for (final p in ref.watch(allProductsProvider).value ?? const <Product>[]) {
    if (p.supplier.trim().isNotEmpty) set.add(p.supplier.trim());
  }
  final list = set.toList()..sort();
  return list;
});
