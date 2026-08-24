import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../core/i18n/app_strings.dart';

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.pending => tr('جديد'),
        OrderStatus.confirmed => tr('مؤكَّد'),
        OrderStatus.shipped => tr('مُرسَل'),
        OrderStatus.delivered => tr('مُسلَّم'),
        OrderStatus.cancelled => tr('ملغى'),
      };

  String get code => switch (this) {
        OrderStatus.pending => 'pending',
        OrderStatus.confirmed => 'confirmed',
        OrderStatus.shipped => 'shipped',
        OrderStatus.delivered => 'delivered',
        OrderStatus.cancelled => 'cancelled',
      };

  static OrderStatus parse(String? s) => switch (s) {
        'confirmed' => OrderStatus.confirmed,
        'shipped' => OrderStatus.shipped,
        'delivered' => OrderStatus.delivered,
        'cancelled' => OrderStatus.cancelled,
        _ => OrderStatus.pending,
      };
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    this.size = '',
    this.color = '',
  });

  final String productId;
  final String name;
  final int quantity;
  final double price;
  final String size;
  final String color;

  double get lineTotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: (m['productId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        quantity: toInt(m['quantity']),
        price: toDouble(m['price']),
        size: (m['size'] ?? '') as String,
        color: (m['color'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'size': size,
        'color': color,
      };
}

/// طلب من المتجر الإلكتروني.
///
/// يُنشئه زائر غير مصادَق، فبنيته مقيَّدة بقواعد Firestore (`isValidOrder`):
/// حقول محدّدة، حالة `pending` إجبارياً، وحدود على الأطوال والمبالغ —
/// وإلا لأمكن لأي شخص ملء قاعدة البيانات بما شاء.
class PublicOrder {
  const PublicOrder({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.customerName,
    required this.phone,
    required this.wilaya,
    required this.items,
    required this.total,
    this.address = '',
    this.notes = '',
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.deposit = 0,
    this.status = OrderStatus.pending,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String orderNumber;

  /// `purchase` طلب شراء، `inquiry` استفسار.
  final String type;

  final String customerName;
  final String phone;
  final String wilaya;
  final String address;
  final String notes;

  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final double deposit;

  final OrderStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get pieceCount => items.fold(0, (acc, i) => acc + i.quantity);
  double get remaining => (total - deposit).clamp(0, double.infinity);
  bool get isInquiry => type == 'inquiry';

  String get productsTitle {
    if (items.isEmpty) return tr('بلا منتجات');
    final names = items.map((i) => i.name).toList();
    if (names.length <= 2) return names.join(' + ');
    return trf('{0} + {1} أخرى', [names.take(2).join(' + '), names.length - 2]);
  }

  factory PublicOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    final customer =
        Map<String, dynamic>.from((m['customer'] ?? const {}) as Map);

    return PublicOrder(
      id: doc.id,
      orderNumber: (m['orderNumber'] ?? '') as String,
      type: (m['type'] ?? 'purchase') as String,
      customerName: (customer['fullName'] ?? '') as String,
      phone: (customer['phone'] ?? '') as String,
      wilaya: (customer['wilaya'] ?? '') as String,
      address: (customer['address'] ?? '') as String,
      notes: (customer['notes'] ?? '') as String,
      items: ((m['items'] ?? const []) as List)
          .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      subtotal: toDouble(m['subtotal']),
      deliveryFee: toDouble(m['deliveryFee']),
      total: toDouble(m['total']),
      deposit: toDouble(m['deposit']),
      status: OrderStatusLabel.parse(m['status'] as String?),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(customerName).contains(q) ||
        phone.contains(query.trim()) ||
        orderNumber.toLowerCase().contains(query.trim().toLowerCase()) ||
        items.any((i) => normalizeForSearch(i.name).contains(q));
  }
}
