import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../settings/presentation/providers/settings_providers.dart';

/// سطر في السلة.
class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  final Product product;
  final int quantity;

  /// السعر المطبَّق فعلاً — قد يكون معدَّلاً يدوياً (±100 أو إدخال حرّ).
  final double unitPrice;

  double get lineTotal => unitPrice * quantity;

  /// الفائدة على السطر — **لا تُعرض في السلة إطلاقاً**.
  /// شاشة نقطة البيع مواجهة للزبونة، ولا يجوز أن ترى هامش الربح.
  double get lineProfit => (unitPrice - product.purchasePrice) * quantity;

  bool get priceChanged => (unitPrice - product.sellPrice).abs() > 0.009;

  CartLine copyWith({int? quantity, double? unitPrice, Product? product}) =>
      CartLine(
        product: product ?? this.product,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );

  SaleItem toSaleItem() =>
      SaleItem.fromProduct(product, quantity, priceOverride: unitPrice);

  Map<String, dynamic> toSyncMap() => {
        'productId': product.id,
        'name': product.name,
        'barcode': product.barcode,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'sellPrice': product.sellPrice,
        'purchasePrice': product.purchasePrice,
      };

  /// إعادة بناء السطر من مزامنة جهاز آخر.
  ///
  /// نفضّل المنتج الحقيقي من المخزون (فيه الكمية والصور والحالة)، ونعود
  /// إلى نسخة مبسّطة إن لم يصل المخزون بعد إلى هذا الجهاز.
  static CartLine fromSyncMap(
    Map<String, dynamic> m,
    Map<String, Product> inventory,
  ) {
    final id = (m['productId'] ?? '') as String;
    final product = inventory[id] ??
        Product(
          id: id,
          name: (m['name'] ?? '') as String,
          barcode: (m['barcode'] ?? '') as String,
          sellPrice: toDouble(m['sellPrice']),
          purchasePrice: toDouble(m['purchasePrice']),
        );
    return CartLine(
      product: product,
      quantity: toInt(m['quantity']),
      unitPrice: toDouble(m['unitPrice']),
    );
  }
}

class CartState {
  const CartState({
    this.lines = const [],
    this.discount = 0,
    this.customerName = '',
    this.customerId = '',
    this.isVip = false,
  });

  final List<CartLine> lines;

  /// تخفيض يدوي بمبلغ على السلة كاملة.
  final double discount;

  final String customerName;
  final String customerId;
  final bool isVip;

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;
  int get pieceCount => lines.fold(0, (acc, l) => acc + l.quantity);
  double get subtotal => lines.fold(0.0, (acc, l) => acc + l.lineTotal);

  List<SaleItem> toSaleItems() => lines.map((l) => l.toSaleItem()).toList();

  CartState copyWith({
    List<CartLine>? lines,
    double? discount,
    String? customerName,
    String? customerId,
    bool? isVip,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        discount: discount ?? this.discount,
        customerName: customerName ?? this.customerName,
        customerId: customerId ?? this.customerId,
        isVip: isVip ?? this.isVip,
      );

  Map<String, dynamic> toSyncMap() => {
        'lines': lines.map((l) => l.toSyncMap()).toList(),
        'discount': discount,
        'customerName': customerName,
        'customerId': customerId,
        'isVip': isVip,
      };

  static CartState fromSyncMap(
    Map<String, dynamic> m,
    Map<String, Product> inventory,
  ) =>
      CartState(
        lines: ((m['lines'] ?? const []) as List)
            .map((e) => CartLine.fromSyncMap(
                  Map<String, dynamic>.from(e as Map),
                  inventory,
                ))
            .toList(),
        discount: toDouble(m['discount']),
        customerName: (m['customerName'] ?? '') as String,
        customerId: (m['customerId'] ?? '') as String,
        isVip: (m['isVip'] ?? false) as bool,
      );
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// إضافة منتج: يزيد كميته إن كان موجوداً بالفعل.
  void add(Product product, {int quantity = 1, double? price}) {
    final index = state.lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0) {
      final line = state.lines[index];
      setQuantity(index, line.quantity + quantity);
      return;
    }
    state = state.copyWith(lines: [
      ...state.lines,
      CartLine(
        product: product,
        quantity: quantity,
        unitPrice: price ?? product.sellPrice,
      ),
    ]);
  }

  void setQuantity(int index, int quantity) {
    if (index < 0 || index >= state.lines.length) return;
    if (quantity <= 0) {
      removeAt(index);
      return;
    }
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(quantity: quantity);
    state = state.copyWith(lines: lines);
  }

  void setPrice(int index, double price) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(
      unitPrice: price < 0 ? 0 : price,
    );
    state = state.copyWith(lines: lines);
  }

  /// زرّا ±100 د.ج بجانب السعر — أسرع طريقة للمساومة أمام الزبونة.
  void bumpPrice(int index, double delta) {
    if (index < 0 || index >= state.lines.length) return;
    setPrice(index, state.lines[index].unitPrice + delta);
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines);
  }

  void setDiscount(double value) =>
      state = state.copyWith(discount: value < 0 ? 0 : value);

  void setCustomer({
    required String name,
    String id = '',
    bool isVip = false,
  }) =>
      state = state.copyWith(
        customerName: name,
        customerId: id,
        isVip: isVip,
      );

  void clearCustomer() => state = state.copyWith(
        customerName: '',
        customerId: '',
        isVip: false,
      );

  void clear() => state = const CartState();

  /// استبدال السلة كاملةً (تحميل سلة معلّقة أو مزامنة من جهاز آخر).
  void replaceAll(CartState next) => state = next;
}

final cartProvider =
    NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

/// مجاميع السلة — محسوبة خارج الحالة حتى تبقى الحالة نقيّة ولا تتأثّر
/// بتغيّر نسبة VIP في الإعدادات.
class CartTotals {
  const CartTotals({
    required this.subtotal,
    required this.vipDiscount,
    required this.discount,
    required this.total,
  });

  final double subtotal;
  final double vipDiscount;
  final double discount;
  final double total;

  double get totalDiscount => vipDiscount + discount;
}

final cartTotalsProvider = Provider<CartTotals>((ref) {
  final cart = ref.watch(cartProvider);
  final vipPercent = ref.watch(vipDiscountPercentProvider);

  final subtotal = cart.subtotal;
  final vipDiscount = cart.isVip ? subtotal * (vipPercent / 100) : 0.0;
  final total =
      (subtotal - vipDiscount - cart.discount).clamp(0, double.infinity);

  return CartTotals(
    subtotal: subtotal,
    vipDiscount: vipDiscount,
    discount: cart.discount,
    total: total.toDouble(),
  );
});
