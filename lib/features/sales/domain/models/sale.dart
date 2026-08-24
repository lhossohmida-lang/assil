import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../../core/i18n/app_strings.dart';

enum PaymentMethod { cash, credit, reservation }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => tr('نقداً'),
        PaymentMethod.credit => tr('كريدي'),
        PaymentMethod.reservation => tr('فارسمون'),
      };

  String get code => switch (this) {
        PaymentMethod.cash => 'cash',
        PaymentMethod.credit => 'credit',
        PaymentMethod.reservation => 'reservation',
      };

  static PaymentMethod parse(String? s) => switch (s) {
        'credit' => PaymentMethod.credit,
        'reservation' => PaymentMethod.reservation,
        _ => PaymentMethod.cash,
      };
}

/// سطر في الفاتورة.
///
/// يحمل **نسخة من بيانات المنتج وقت البيع** لا مرجعاً إليه: لو تغيّر سعر
/// الشراء أو الاسم لاحقاً وجب أن تبقى أرباح الفواتير القديمة كما كانت.
class SaleItem {
  final String productId;
  final String name;
  final String barcode;
  final int quantity;

  /// سعر البيع الفعلي لهذه القطعة (قد يكون معدَّلاً يدوياً في السلة).
  final double unitPrice;

  /// سعر الشراء **وقت البيع** — أساس حساب الفائدة.
  final double purchasePrice;

  /// نسخة كاملة من المنتج وقت البيع (للإرجاع والاستبدال وإعادة الطباعة).
  final Map<String, dynamic> productSnapshot;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice,
    this.barcode = '',
    this.productSnapshot = const {},
  });

  double get lineTotal => unitPrice * quantity;
  double get lineCost => purchasePrice * quantity;
  double get lineProfit => lineTotal - lineCost;

  factory SaleItem.fromProduct(Product p, int quantity, {double? priceOverride}) =>
      SaleItem(
        productId: p.id,
        name: p.name,
        barcode: p.barcode,
        quantity: quantity,
        unitPrice: priceOverride ?? p.sellPrice,
        purchasePrice: p.purchasePrice,
        productSnapshot: {
          'name': p.name,
          'barcode': p.barcode,
          'category': p.category,
          'supplier': p.supplier,
          'sellPrice': p.sellPrice,
          'purchasePrice': p.purchasePrice,
          'sizes': p.sizes,
          'colors': p.colors,
          'images': p.images,
        },
      );

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        productId: (m['productId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        barcode: (m['barcode'] ?? '') as String,
        quantity: toInt(m['quantity']),
        unitPrice: toDouble(m['unitPrice']),
        purchasePrice: toDouble(m['purchasePrice']),
        productSnapshot: Map<String, dynamic>.from(
          (m['productSnapshot'] ?? const {}) as Map,
        ),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'barcode': barcode,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'purchasePrice': purchasePrice,
        'total': lineTotal,
        'productSnapshot': productSnapshot,
      };

  SaleItem copyWith({int? quantity, double? unitPrice}) => SaleItem(
        productId: productId,
        name: name,
        barcode: barcode,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        purchasePrice: purchasePrice,
        productSnapshot: productSnapshot,
      );
}

/// فاتورة بيع.
class Sale {
  final String id;
  final List<SaleItem> items;

  /// مجموع الأسطر قبل أي تخفيض.
  final double subtotal;

  /// تخفيض يدوي على السلة كاملة (مبلغ لا نسبة).
  final double discount;

  /// خصم VIP المحسوب من نسبة الإعدادات.
  final double vipDiscount;

  final double total;
  final PaymentMethod paymentMethod;

  /// المبلغ المدفوع نقداً (يساوي total في البيع النقدي، وأقلّ في الكريدي).
  final double paidAmount;

  final String customerName;
  final String customerId;
  final bool isVip;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;

  const Sale({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.total,
    this.discount = 0,
    this.vipDiscount = 0,
    this.paymentMethod = PaymentMethod.cash,
    double? paidAmount,
    this.customerName = '',
    this.customerId = '',
    this.isVip = false,
    this.createdBy = '',
    this.createdByName = '',
    this.createdAt,
  }) : paidAmount = paidAmount ?? total;

  /// رقم الفاتورة المعروض — **مشتقّ من المعرّف** لا مخزَّن.
  /// عدّاد حقيقي يتطلّب معاملة لكل بيع، وهي أبطأ عملية يمكن وضعها في
  /// طريق البيع السريع، ولا فائدة منها هنا.
  String get invoiceNumber {
    final raw = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tail = raw.length >= 8 ? raw.substring(raw.length - 8) : raw;
    return 'TB-$tail';
  }

  /// عدد القطع في الفاتورة.
  int get pieceCount => items.fold(0, (acc, i) => acc + i.quantity);

  /// كلفة البضاعة المباعة (رأس المال المُباع).
  double get cost => items.fold(0.0, (acc, i) => acc + i.lineCost);

  /// الفائدة الخام: ما دخل فعلاً ناقص كلفة البضاعة.
  /// التخفيضات تُنقص الفائدة لأنها بالفعل مطروحة من `total`.
  double get profit => total - cost;

  /// عنوان الفاتورة في السجل = **أسماء منتجاتها**، لا رقمها.
  /// صاحب المحل يتعرّف على البيعة بما بِيع فيها لا برقم لا يعني له شيئاً.
  String get productsTitle {
    if (items.isEmpty) return tr('فاتورة فارغة');
    final names = items.map((i) => i.name).toList();
    if (names.length <= 2) return names.join(' + ');
    return trf('{0} + {1} أخرى', [names.take(2).join(' + '), names.length - 2]);
  }

  /// المتبقّي ديناً (للكريدي).
  double get remaining => (total - paidAmount).clamp(0, double.infinity);

  factory Sale.fromMap(String id, Map<String, dynamic> m) => Sale(
        id: id,
        items: ((m['items'] ?? const []) as List)
            .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        subtotal: toDouble(m['subtotal']),
        discount: toDouble(m['discount']),
        vipDiscount: toDouble(m['vipDiscount']),
        total: toDouble(m['total']),
        paymentMethod: PaymentMethodLabel.parse(m['paymentMethod'] as String?),
        paidAmount:
            m['paidAmount'] == null ? toDouble(m['total']) : toDouble(m['paidAmount']),
        customerName: (m['customerName'] ?? '') as String,
        customerId: (m['customerId'] ?? '') as String,
        isVip: (m['isVip'] ?? false) as bool,
        createdBy: (m['createdBy'] ?? '') as String,
        createdByName: (m['createdByName'] ?? '') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  factory Sale.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Sale.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'vipDiscount': vipDiscount,
        'total': total,
        'cost': cost,
        'profit': profit,
        'paymentMethod': paymentMethod.code,
        'paidAmount': paidAmount,
        'customerName': customerName,
        'customerId': customerId,
        'isVip': isVip,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  Sale copyWith({
    List<SaleItem>? items,
    double? subtotal,
    double? discount,
    double? total,
  }) =>
      Sale(
        id: id,
        items: items ?? this.items,
        subtotal: subtotal ?? this.subtotal,
        discount: discount ?? this.discount,
        vipDiscount: vipDiscount,
        total: total ?? this.total,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        customerName: customerName,
        customerId: customerId,
        isVip: isVip,
        createdBy: createdBy,
        createdByName: createdByName,
        createdAt: createdAt,
      );
}
