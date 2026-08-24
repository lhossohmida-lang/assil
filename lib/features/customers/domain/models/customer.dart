import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';

/// زبونة المحل. تُنشأ تلقائياً عند أول بيع باسمها.
class Customer {
  final String id;
  final String name;
  final String phone;

  /// زبونة VIP: تُخصم لها نسبة تلقائياً من إعدادات المتجر.
  final bool isVip;

  final double totalPurchases;
  final int purchaseCount;
  final DateTime? createdAt;
  final DateTime? lastPurchaseAt;

  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.isVip = false,
    this.totalPurchases = 0,
    this.purchaseCount = 0,
    this.createdAt,
    this.lastPurchaseAt,
  });

  factory Customer.fromMap(String id, Map<String, dynamic> m) => Customer(
        id: id,
        name: (m['name'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        isVip: (m['isVip'] ?? false) as bool,
        totalPurchases: toDouble(m['totalPurchases']),
        purchaseCount: toInt(m['purchaseCount']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        lastPurchaseAt: (m['lastPurchaseAt'] as Timestamp?)?.toDate(),
      );

  factory Customer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Customer.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'isVip': isVip,
        'totalPurchases': totalPurchases,
        'purchaseCount': purchaseCount,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        if (lastPurchaseAt != null)
          'lastPurchaseAt': Timestamp.fromDate(lastPurchaseAt!),
      };

  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(name).contains(q) || phone.contains(query.trim());
  }
}

/// دفعة سداد على حساب كريدي.
class CreditPayment {
  const CreditPayment({
    required this.amount,
    required this.at,
    this.note = '',
    this.byName = '',
  });

  final double amount;
  final DateTime at;
  final String note;
  final String byName;

  factory CreditPayment.fromMap(Map<String, dynamic> m) => CreditPayment(
        amount: toDouble(m['amount']),
        at: (m['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        note: (m['note'] ?? '') as String,
        byName: (m['byName'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'at': Timestamp.fromDate(at),
        'note': note,
        'byName': byName,
      };
}

/// حساب كريدي (بيع آجل) لزبونة.
class CreditAccount {
  final String id;
  final String customerName;
  final String phone;

  /// مجموع ما اشترته بالآجل.
  final double totalDebt;

  /// مجموع ما سدّدته.
  final double totalPaid;

  final List<CreditPayment> payments;

  /// معرّفات الفواتير المرتبطة بهذا الحساب.
  final List<String> saleIds;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CreditAccount({
    required this.id,
    required this.customerName,
    this.phone = '',
    this.totalDebt = 0,
    this.totalPaid = 0,
    this.payments = const [],
    this.saleIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// المتبقّي في الذمّة.
  double get remaining {
    final v = totalDebt - totalPaid;
    return v < 0 ? 0 : v;
  }

  bool get isSettled => remaining <= 0.009;

  factory CreditAccount.fromMap(String id, Map<String, dynamic> m) =>
      CreditAccount(
        id: id,
        customerName: (m['customerName'] ?? '') as String,
        phone: (m['phone'] ?? '') as String,
        totalDebt: toDouble(m['totalDebt']),
        totalPaid: toDouble(m['totalPaid']),
        payments: ((m['payments'] ?? const []) as List)
            .map((e) =>
                CreditPayment.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        saleIds: ((m['saleIds'] ?? const []) as List).cast<String>(),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );

  factory CreditAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      CreditAccount.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'phone': phone,
        'totalDebt': totalDebt,
        'totalPaid': totalPaid,
        'payments': payments.map((p) => p.toMap()).toList(),
        'saleIds': saleIds,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(customerName).contains(q) ||
        phone.contains(query.trim());
  }
}
