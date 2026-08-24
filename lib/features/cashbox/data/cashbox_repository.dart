import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/domain/models/app_user.dart';
import '../../sales/data/sales_repository.dart';
import '../domain/models/cashbox_transaction.dart';

/// وجهة السحب: حساب مصروف أو عامل.
class WithdrawalTarget {
  const WithdrawalTarget.account(this.id, this.name) : isEmployee = false;
  const WithdrawalTarget.employee(this.id, this.name) : isEmployee = true;
  const WithdrawalTarget.none()
      : id = '',
        name = '',
        isEmployee = false;

  final String id;
  final String name;
  final bool isEmployee;

  bool get isEmpty => id.isEmpty;
}

class CashboxRepository {
  CashboxRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(FirestorePaths.stores).doc(storeId).collection(name);

  CollectionReference<Map<String, dynamic>> get transactions =>
      _col(FirestorePaths.cashboxTransactions);
  CollectionReference<Map<String, dynamic>> get accounts =>
      _col(FirestorePaths.expenseAccounts);
  CollectionReference<Map<String, dynamic>> get users =>
      _col(FirestorePaths.users);

  /// كل الحركات — يلزم رصيد الصندوق منذ البداية.
  ///
  /// حجم المجموعة يبقى معقولاً لمحل واحد، وشاشة التقارير توفّر حذف
  /// السجلات الأقدم من فترة يختارها صاحب المحل.
  Stream<List<CashboxTransaction>> watchAll() =>
      transactions.snapshots().map((s) {
        final list = s.docs.map(CashboxTransaction.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Stream<List<ExpenseAccount>> watchAccounts() => accounts.snapshots().map((s) {
        final list = s.docs
            .map((d) => ExpenseAccount.fromMap(d.id, d.data()))
            .toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Future<void> addAccount(String name) => accounts.add({
        'name': name.trim(),
        'totalExpenses': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> renameAccount(String id, String name) =>
      accounts.doc(id).update({'name': name.trim()});

  Future<void> deleteAccount(String id) => accounts.doc(id).delete();

  /// سحوبات عامل بعينه.
  ///
  /// ⚠️ بلا `orderBy` مع الـ `where`: تركيبهما على حقلين مختلفين يطلب
  /// فهرساً مركّباً، فتتوقّف الشاشة عن العمل عند العميل. الترتيب محلياً.
  Stream<List<CashboxTransaction>> watchWithdrawalsFor(String uid) =>
      transactions.where('recipientId', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(CashboxTransaction.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// إيداع نقدي يدوي.
  Future<void> deposit({
    required double amount,
    required Actor actor,
    String note = '',
  }) =>
      transactions.add({
        'type': CashboxType.deposit.code,
        'amount': amount,
        'note': note,
        'saleId': '',
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': actor.uid,
        'createdByName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// سحب/مصروف مربوط بحساب مصروف أو بعامل.
  ///
  /// الربط يزيد `totalExpenses` للحساب أو `withdrawnAmount` للعامل
  /// **في نفس الدفعة** — فلا يمكن أن يُسجَّل سحب بلا أثر على وجهته.
  Future<void> withdraw({
    required double amount,
    required Actor actor,
    required WithdrawalTarget target,
    String note = '',
  }) async {
    final batch = _db.batch();

    batch.set(transactions.doc(), {
      'type': CashboxType.expense.code,
      'amount': amount,
      'note': note,
      'saleId': '',
      'accountId': target.isEmployee ? '' : target.id,
      'accountName': target.isEmployee ? '' : target.name,
      'recipientId': target.isEmployee ? target.id : '',
      'recipientName': target.isEmployee ? target.name : '',
      'createdBy': actor.uid,
      'createdByName': actor.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!target.isEmpty) {
      if (target.isEmployee) {
        batch.update(users.doc(target.id), {
          'withdrawnAmount': FieldValue.increment(amount),
        });
      } else {
        batch.update(accounts.doc(target.id), {
          'totalExpenses': FieldValue.increment(amount),
        });
      }
    }

    await batch.commit();
  }

  /// حذف حركة — **يعكس أثرها** على الحساب أو العامل المرتبط.
  Future<void> deleteTransaction(CashboxTransaction tx) async {
    final batch = _db.batch();
    batch.delete(transactions.doc(tx.id));

    if (tx.accountId.isNotEmpty) {
      batch.update(accounts.doc(tx.accountId), {
        'totalExpenses': FieldValue.increment(-tx.amount),
      });
    }
    if (tx.recipientId.isNotEmpty) {
      batch.update(users.doc(tx.recipientId), {
        'withdrawnAmount': FieldValue.increment(-tx.amount),
      });
    }

    await batch.commit();
  }

  /// إغلاق الصندوق: ما زاد عمّا يُترك للغد يُسجَّل **سحب أرباح**.
  ///
  /// نوع مستقلّ لا مصروف — انظر `ReportSummary`.
  Future<void> closeDay({
    required double currentBalance,
    required double keepForTomorrow,
    required Actor actor,
    required DateTime closedAt,
  }) async {
    final withdrawn = currentBalance - keepForTomorrow;

    final batch = _db.batch();
    if (withdrawn > 0.009) {
      batch.set(transactions.doc(), {
        'type': CashboxType.profitWithdrawal.code,
        'amount': withdrawn,
        'note': 'إغلاق الصندوق — سحب أرباح',
        'saleId': '',
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': actor.uid,
        'createdByName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(
      _col(FirestorePaths.settings).doc(FirestorePaths.storeSettingsDoc),
      {'lastDayClose': Timestamp.fromDate(closedAt)},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  /// قائمة وجهات السحب: حسابات المصروف + العمال.
  ///
  /// ⚠️ تُحمَّل **مرة واحدة كقائمة صريحة** ولا تُبنى بـ Autocomplete:
  /// نسخة Autocomplete كانت تُضيف مستمعاً في كل إعادة بناء يمسح الاختيار،
  /// فتُحفظ السحوبات بلا حساب ولا يظهر لها أثر في أي تقرير.
  Future<List<WithdrawalTarget>> loadTargets() async {
    final accountsSnap = await accounts.get();
    final usersSnap = await users.get();

    final targets = <WithdrawalTarget>[
      for (final d in accountsSnap.docs)
        WithdrawalTarget.account(d.id, (d.data()['name'] ?? '') as String),
      for (final d in usersSnap.docs)
        WithdrawalTarget.employee(
          d.id,
          AppUser.fromMap(d.id, d.data(), storeId).name,
        ),
    ];
    targets.sort((a, b) => a.name.compareTo(b.name));
    return targets;
  }
}
