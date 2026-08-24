import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../../core/i18n/app_strings.dart';

enum ReservationStatus { active, completed, cancelled }

extension ReservationStatusLabel on ReservationStatus {
  String get label => switch (this) {
        ReservationStatus.active => tr('جارٍ'),
        ReservationStatus.completed => tr('مكتمل'),
        ReservationStatus.cancelled => tr('ملغى'),
      };

  String get code => switch (this) {
        ReservationStatus.active => 'active',
        ReservationStatus.completed => 'completed',
        ReservationStatus.cancelled => 'cancelled',
      };

  static ReservationStatus parse(String? s) => switch (s) {
        'completed' => ReservationStatus.completed,
        'cancelled' => ReservationStatus.cancelled,
        _ => ReservationStatus.active,
      };
}

/// «فارسمون» — حجز بضاعة بعربون.
///
/// المنتجات تخرج من المخزون فور الحجز (فهي موضوعة جانباً للزبونة)،
/// وتعود إليه إن أُلغي الحجز.
class Reservation {
  final String id;
  final String customerName;
  final String phone;
  final List<SaleItem> items;
  final double total;

  /// العربون المدفوع.
  final double deposit;

  final ReservationStatus status;
  final String note;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;
  final DateTime? closedAt;

  /// الفاتورة الناتجة عند الإكمال.
  final String saleId;

  const Reservation({
    required this.id,
    required this.customerName,
    required this.items,
    required this.total,
    this.phone = '',
    this.deposit = 0,
    this.status = ReservationStatus.active,
    this.note = '',
    this.createdBy = '',
    this.createdByName = '',
    this.createdAt,
    this.closedAt,
    this.saleId = '',
  });

  double get remaining {
    final v = total - deposit;
    return v < 0 ? 0 : v;
  }

  int get pieceCount => items.fold(0, (acc, i) => acc + i.quantity);

  String get productsTitle {
    if (items.isEmpty) return tr('بلا منتجات');
    final names = items.map((i) => i.name).toList();
    if (names.length <= 2) return names.join(' + ');
    return trf('{0} + {1} أخرى', [names.take(2).join(' + '), names.length - 2]);
  }

  factory Reservation.fromMap(String id, Map<String, dynamic> m) => Reservation(
        id: id,
        customerName: (m['customerName'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        items: ((m['items'] ?? const []) as List)
            .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        total: toDouble(m['total']),
        deposit: toDouble(m['deposit']),
        status: ReservationStatusLabel.parse(m['status'] as String?),
        note: (m['note'] ?? '') as String,
        createdBy: (m['createdBy'] ?? '') as String,
        createdByName: (m['createdByName'] ?? '') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        closedAt: (m['closedAt'] as Timestamp?)?.toDate(),
        saleId: (m['saleId'] ?? '') as String,
      );

  factory Reservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Reservation.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'phone': phone,
        'items': items.map((i) => i.toMap()).toList(),
        'total': total,
        'deposit': deposit,
        'status': status.code,
        'note': note,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'saleId': saleId,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      };

  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(customerName).contains(q) ||
        phone.contains(query.trim()) ||
        items.any((i) => normalizeForSearch(i.name).contains(q));
  }
}

/// سلة معلّقة («انتظار») — الزبونة ذهبت لتجرّب وتعود.
class HeldCart {
  final String id;
  final String name;
  final String note;
  final List<SaleItem> items;
  final double discount;
  final DateTime? createdAt;
  final String createdByName;

  const HeldCart({
    required this.id,
    required this.name,
    required this.items,
    this.note = '',
    this.discount = 0,
    this.createdAt,
    this.createdByName = '',
  });

  double get total =>
      items.fold(0.0, (acc, i) => acc + i.lineTotal) - discount;

  int get pieceCount => items.fold(0, (acc, i) => acc + i.quantity);

  String get productsTitle {
    if (items.isEmpty) return tr('سلة فارغة');
    return items.map((i) => i.name).take(3).join(' + ');
  }

  factory HeldCart.fromMap(String id, Map<String, dynamic> m) => HeldCart(
        id: id,
        name: (m['name'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        items: ((m['items'] ?? const []) as List)
            .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        discount: toDouble(m['discount']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        createdByName: (m['createdByName'] ?? '') as String,
      );

  factory HeldCart.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      HeldCart.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'name': name,
        'note': note,
        'items': items.map((i) => i.toMap()).toList(),
        'discount': discount,
        'createdByName': createdByName,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  /// البحث في السلال المعلّقة: بالاسم أو الملاحظة **أو اسم منتج داخلها**.
  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(name).contains(q) ||
        normalizeForSearch(note).contains(q) ||
        items.any((i) => normalizeForSearch(i.name).contains(q));
  }
}
