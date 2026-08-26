import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';

enum CashboxType {
  /// دخل من بيع (مربوط بـ saleId).
  income,

  /// إيداع نقدي يدوي.
  deposit,

  /// مصروف أو سحب عادي (كهرباء، كراء، سحب عامل...).
  expense,

  /// **شراء بضاعة من مورّد**.
  ///
  /// ⚠️ ليس مصروفاً ولا يُنقص الفائدة: شراء البضاعة **تحويل** للنقد إلى
  /// مخزون لا استهلاك له. كلفتها تُحسب وقت البيع (رأس المال المُباع)،
  /// فلو عددناها مصروفاً أيضاً لخُصمت مرّتين وظهر المحل خاسراً كلّما
  /// اشترى بضاعة. لكنها **تُنقص رصيد الصندوق** لأن المال خرج فعلاً.
  purchase,

  /// **إرجاع بضاعة** — المال يعود إلى الزبون.
  ///
  /// ⚠️ ليس مصروفاً. الإرجاع **إلغاءٌ لبيعة** لا كلفة على المحل: الفاتورة
  /// نفسها تنقص بقيمة السلعة المُرجَعة فتنقص الفائدة الخام تلقائياً. لو
  /// عُدّ مصروفاً أيضاً لخُصم مرّتين، فتُقرأ «الفائدة بعد المصاريف» أقلّ
  /// مما هي بمقدار قيمة الإرجاع كاملةً — وهو ما كان يحدث فعلاً.
  ///
  /// لكنه **يُنقص رصيد الصندوق وصافي النقد** لأن المال خرج من الدرج حقاً.
  saleReturn,

  /// **سحب أرباح** — يُسجَّل عند «إغلاق الصندوق».
  ///
  /// نوع مستقلّ عمداً: صاحب المحل يأخذ ربحه إلى جيبه، وهذا **ليس مصروفاً**
  /// على المحل. لو حُسب مصروفاً لظهرت «الفائدة بعد المصاريف» أقلّ مما هي
  /// كل يوم، وبدا المحل خاسراً وهو رابح.
  profitWithdrawal,
}

extension CashboxTypeLabel on CashboxType {
  String get label => switch (this) {
        CashboxType.income => 'دخل',
        CashboxType.deposit => 'إيداع',
        CashboxType.expense => 'سحب / مصروف',
        CashboxType.purchase => 'شراء بضاعة',
        CashboxType.saleReturn => 'إرجاع بضاعة',
        CashboxType.profitWithdrawal => 'سحب أرباح',
      };

  String get code => switch (this) {
        CashboxType.income => 'income',
        CashboxType.deposit => 'deposit',
        CashboxType.expense => 'expense',
        CashboxType.purchase => 'purchase',
        CashboxType.saleReturn => 'saleReturn',
        CashboxType.profitWithdrawal => 'profitWithdrawal',
      };

  /// هل تزيد رصيد الصندوق؟
  bool get isCredit =>
      this == CashboxType.income || this == CashboxType.deposit;
}

/// نصوص الحركات القديمة التي كانت تُسجَّل كمصروف قبل وجود نوع مستقلّ.
///
/// التوافق الرجعي مطلوب: بيانات أشهر مضت في المحل لا يمكن تعديلها يدوياً،
/// ولو صنّفناها مصاريف لأفسدت كل تقارير الفترات السابقة.
const List<String> legacyProfitWithdrawalNotes = [
  'إغلاق الصندوق',
  'سحب أرباح',
];

/// بادئة ملاحظة الإرجاعات التي سُجّلت **مصروفاً** قبل وجود نوع مستقلّ.
///
/// نتعرّف عليها بالنصّ بدل تعديل بيانات المحل: تقارير الأشهر الماضية
/// كانت تُظهر «الفائدة بعد المصاريف» أقلّ مما هي بمقدار كل إرجاع، وهذا
/// يصحّحها بأثر رجعي بلا كتابة حرف واحد في قاعدة البيانات.
const String legacyReturnNotePrefix = 'إرجاع ';

class CashboxTransaction {
  final String id;
  final CashboxType type;
  final double amount;
  final String note;

  /// الفاتورة المرتبطة (للدخل) — تسمح بحذف حركة الصندوق مع الفاتورة.
  final String saleId;

  /// حساب المصروف المرتبط (كهرباء، كراء...).
  final String accountId;
  final String accountName;

  /// المورّد المرتبط (لحركات الشراء ودفعات الموردين).
  final String supplierId;
  final String supplierName;

  /// فاتورة الشراء المرتبطة.
  final String purchaseId;

  /// العامل المستفيد من السحب — يُزاد `withdrawnAmount` عنده.
  final String recipientId;
  final String recipientName;

  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;

  const CashboxTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.note = '',
    this.saleId = '',
    this.accountId = '',
    this.accountName = '',
    this.supplierId = '',
    this.supplierName = '',
    this.purchaseId = '',
    this.recipientId = '',
    this.recipientName = '',
    this.createdBy = '',
    this.createdByName = '',
    this.createdAt,
  });

  /// هل هذه الحركة سحب أرباح؟ تشمل الحركات القديمة المصنّفة بالملاحظة.
  bool get isProfitWithdrawal {
    if (type == CashboxType.profitWithdrawal) return true;
    if (type != CashboxType.expense) return false;
    return legacyProfitWithdrawalNotes.any((n) => note.contains(n));
  }

  /// هل هذه الحركة إرجاع بضاعة؟ تشمل الإرجاعات القديمة المصنّفة بالملاحظة.
  bool get isSaleReturn {
    if (type == CashboxType.saleReturn) return true;
    if (type != CashboxType.expense) return false;
    return note.startsWith(legacyReturnNotePrefix);
  }

  /// مصروف حقيقي يُنقص «الفائدة بعد المصاريف».
  ///
  /// مستثنى منه: سحب الأرباح (ربح المالك) وشراء البضاعة (تحويل لا
  /// استهلاك) وإرجاع البضاعة (إلغاء بيعة لا كلفة).
  bool get isRealExpense =>
      type == CashboxType.expense && !isProfitWithdrawal && !isSaleReturn;

  /// أثر الحركة على رصيد الصندوق.
  double get signedAmount => type.isCredit ? amount : -amount;

  /// ⚠️ **كل نوع جديد يجب أن يُضاف هنا أيضاً.**
  ///
  /// السقوط الافتراضي إلى `expense` مقصود للبيانات القديمة، لكنه فخّ:
  /// أُضيف `saleReturn` إلى التعداد وإلى الكاتب وإلى التقارير ونُسي هنا،
  /// فكانت الحركة تُكتب `saleReturn` وتُقرأ `expense` — والإرجاع يبقى
  /// محسوباً مصروفاً كأن الإصلاح لم يقع. يحرسه اختبار ذهاب-إياب.
  static CashboxType parseType(String? s) => switch (s) {
        'income' => CashboxType.income,
        'deposit' => CashboxType.deposit,
        'purchase' => CashboxType.purchase,
        'saleReturn' => CashboxType.saleReturn,
        'profitWithdrawal' => CashboxType.profitWithdrawal,
        _ => CashboxType.expense,
      };

  factory CashboxTransaction.fromMap(String id, Map<String, dynamic> m) =>
      CashboxTransaction(
        id: id,
        type: parseType(m['type'] as String?),
        amount: toDouble(m['amount']),
        note: (m['note'] ?? '') as String,
        saleId: (m['saleId'] ?? '') as String,
        accountId: (m['accountId'] ?? '') as String,
        accountName: (m['accountName'] ?? '') as String,
        supplierId: (m['supplierId'] ?? '') as String,
        supplierName: (m['supplierName'] ?? '') as String,
        purchaseId: (m['purchaseId'] ?? '') as String,
        recipientId: (m['recipientId'] ?? '') as String,
        recipientName: (m['recipientName'] ?? '') as String,
        createdBy: (m['createdBy'] ?? '') as String,
        createdByName: (m['createdByName'] ?? '') as String,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  factory CashboxTransaction.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      CashboxTransaction.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'type': type.code,
        'amount': amount,
        'note': note,
        'saleId': saleId,
        'accountId': accountId,
        'accountName': accountName,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'purchaseId': purchaseId,
        'recipientId': recipientId,
        'recipientName': recipientName,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}

/// حساب مصروف (كهرباء، كراء، مشتريات...).
class ExpenseAccount {
  final String id;
  final String name;
  final double totalExpenses;
  final DateTime? createdAt;

  const ExpenseAccount({
    required this.id,
    required this.name,
    this.totalExpenses = 0,
    this.createdAt,
  });

  factory ExpenseAccount.fromMap(String id, Map<String, dynamic> m) =>
      ExpenseAccount(
        id: id,
        name: (m['name'] ?? '') as String,
        totalExpenses: toDouble(m['totalExpenses']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'totalExpenses': totalExpenses,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };
}
