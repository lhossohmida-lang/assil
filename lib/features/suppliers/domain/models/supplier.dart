import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';

/// مورّد البضاعة.
///
/// `remaining` هو **ما عليك له**: مجموع مشترياتك منه ناقص ما دفعته.
class Supplier {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String note;

  /// مجموع فواتير الشراء منه.
  final double totalPurchases;

  /// مجموع ما دُفع له.
  final double totalPaid;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.note = '',
    this.totalPurchases = 0,
    this.totalPaid = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// الدَّين المتبقّي عليك للمورّد.
  double get remaining {
    final v = totalPurchases - totalPaid;
    return v < 0 ? 0 : v;
  }

  /// دفعتَ له أكثر مما اشتريت (رصيد لك عنده).
  double get advance {
    final v = totalPaid - totalPurchases;
    return v < 0 ? 0 : v;
  }

  bool get isSettled => remaining <= 0.009;

  factory Supplier.fromMap(String id, Map<String, dynamic> m) => Supplier(
        id: id,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        address: (m['address'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        totalPurchases: toDouble(m['totalPurchases']),
        totalPaid: toDouble(m['totalPaid']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );

  factory Supplier.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Supplier.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'address': address,
        'note': note,
        'totalPurchases': totalPurchases,
        'totalPaid': totalPaid,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Supplier copyWith({
    String? name,
    String? phone,
    String? address,
    String? note,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        note: note ?? this.note,
        totalPurchases: totalPurchases,
        totalPaid: totalPaid,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(name).contains(q) ||
        phone.contains(query.trim()) ||
        normalizeForSearch(address).contains(q);
  }
}
