import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../../core/i18n/app_strings.dart';

/// سطر في فاتورة شراء.
///
/// يحمل **سعر الشراء القديم** إلى جانب الجديد: هذا ما يجعل تغيّر الأسعار
/// مرئياً لصاحب المحل بدل أن يتبدّل هامش ربحه بصمت.
class PurchaseItem {
  const PurchaseItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitCost,
    this.barcode = '',
    this.previousCost = 0,
    this.newSellPrice,
    this.previousSellPrice = 0,
  });

  final String productId;
  final String name;
  final String barcode;
  final int quantity;

  /// سعر الشراء الجديد للقطعة.
  final double unitCost;

  /// سعر الشراء قبل هذه الفاتورة.
  final double previousCost;

  /// سعر بيع جديد اختياري — يُطبَّق على المنتج إن ذُكر.
  final double? newSellPrice;
  final double previousSellPrice;

  double get lineTotal => unitCost * quantity;

  /// فرق سعر الشراء عن المرة السابقة.
  double get costDelta => unitCost - previousCost;
  bool get costChanged => previousCost > 0 && costDelta.abs() > 0.009;

  /// الفائدة المنتظرة على القطعة بعد هذا الشراء.
  double get expectedUnitProfit =>
      (newSellPrice ?? previousSellPrice) - unitCost;

  factory PurchaseItem.fromMap(Map<String, dynamic> m) => PurchaseItem(
        productId: (m['productId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        barcode: (m['barcode'] ?? '') as String,
        quantity: toInt(m['quantity']),
        unitCost: toDouble(m['unitCost']),
        previousCost: toDouble(m['previousCost']),
        newSellPrice:
            m['newSellPrice'] == null ? null : toDouble(m['newSellPrice']),
        previousSellPrice: toDouble(m['previousSellPrice']),
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'barcode': barcode,
        'quantity': quantity,
        'unitCost': unitCost,
        'previousCost': previousCost,
        if (newSellPrice != null) 'newSellPrice': newSellPrice,
        'previousSellPrice': previousSellPrice,
        'total': lineTotal,
      };

  PurchaseItem copyWith({
    int? quantity,
    double? unitCost,
    double? newSellPrice,
  }) =>
      PurchaseItem(
        productId: productId,
        name: name,
        barcode: barcode,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        previousCost: previousCost,
        newSellPrice: newSellPrice ?? this.newSellPrice,
        previousSellPrice: previousSellPrice,
      );
}

/// فاتورة شراء من مورّد.
class Purchase {
  final String id;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;

  final double subtotal;
  final double discount;
  final double total;

  /// ما دُفع للمورّد وقت الشراء. الباقي دَين عليك له.
  final double paidAmount;

  final String note;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;

  const Purchase({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.subtotal,
    required this.total,
    this.discount = 0,
    this.paidAmount = 0,
    this.note = '',
    this.createdBy = '',
    this.createdByName = '',
    this.createdAt,
  });

  double get remaining {
    final v = total - paidAmount;
    return v < 0 ? 0 : v;
  }

  int get pieceCount => items.fold(0, (acc, i) => acc + i.quantity);

  /// عنوان الفاتورة = **أسماء ما اشتُري**، كما في فواتير البيع.
  String get productsTitle {
    if (items.isEmpty) return tr('فاتورة فارغة');
    final names = items.map((i) => i.name).toList();
    if (names.length <= 2) return names.join(' + ');
    return trf('{0} + {1} أخرى', [names.take(2).join(' + '), names.length - 2]);
  }

  String get invoiceNumber {
    final raw = id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tail = raw.length >= 6 ? raw.substring(raw.length - 6) : raw;
    return 'SH-$tail';
  }

  factory Purchase.fromMap(String id, Map<String, dynamic> m) => Purchase(
        id: id,
        supplierId: (m['supplierId'] ?? '') as String,
        supplierName: (m['supplierName'] ?? '') as String,
        items: ((m['items'] ?? const []) as List)
            .map((e) =>
                PurchaseItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        subtotal: toDouble(m['subtotal']),
        discount: toDouble(m['discount']),
        total: toDouble(m['total']),
        paidAmount: toDouble(m['paidAmount']),
        note: (m['note'] ?? '') as String,
        createdBy: (m['createdBy'] ?? '') as String,
        createdByName: (m['createdByName'] ?? '') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  factory Purchase.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Purchase.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'total': total,
        'paidAmount': paidAmount,
        'note': note,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(supplierName).contains(q) ||
        invoiceNumber.toLowerCase().contains(query.trim().toLowerCase()) ||
        items.any((i) => normalizeForSearch(i.name).contains(q));
  }
}
