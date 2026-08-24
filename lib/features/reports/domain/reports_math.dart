import '../../cashbox/domain/models/cashbox_transaction.dart';
import '../../sales/domain/models/sale.dart';
import '../../../core/i18n/app_strings.dart';

/// ملخّص فترة محاسبية.
///
/// ═══ القاعدة المحاسبية الصلبة في هذا الملف ═══
/// **سحب الأرباح ليس مصروفاً.** صاحب المحل يأخذ ربحه إلى جيبه؛ هذا نقل
/// مال من المحل إلى مالكه لا كلفة على المحل. لو حُسب مصروفاً لظهرت
/// «الفائدة بعد المصاريف» أقلّ مما هي كل يوم، ولبدا المحل خاسراً وهو رابح.
/// لذلك `expenses` تستثنيه دائماً، وله سطر خاص به.
class ReportSummary {
  const ReportSummary({
    required this.salesTotal,
    required this.costOfGoodsSold,
    required this.grossProfit,
    required this.expenses,
    required this.purchases,
    required this.netProfit,
    required this.cashIn,
    required this.cashOut,
    required this.netCash,
    required this.profitWithdrawals,
    required this.invoiceCount,
    required this.pieceCount,
  });

  /// مجموع الفواتير في الفترة.
  final double salesTotal;

  /// رأس المال المُباع = كلفة شراء البضاعة التي خرجت.
  final double costOfGoodsSold;

  /// الفائدة الخام = المبيعات − رأس المال المُباع.
  final double grossProfit;

  /// المصاريف الحقيقية — **بلا سحب الأرباح وبلا شراء البضاعة**.
  final double expenses;

  /// ما دُفع لشراء البضاعة في الفترة (تحويل نقد إلى مخزون).
  final double purchases;

  /// الفائدة بعد المصاريف = الفائدة الخام − المصاريف.
  final double netProfit;

  /// ما دخل الصندوق فعلاً (دخل + إيداعات).
  final double cashIn;

  /// ما خرج منه مصاريفَ حقيقية — **بلا سحب الأرباح وبلا شراء البضاعة**،
  /// فكلاهما ليس كلفة على المحل.
  final double cashOut;

  /// لاروسات بعد المصاريف = صافي النقد الذي بقي من حركة الفترة.
  ///
  /// يختلف عن `netProfit` لأن البيع بالكريدي يزيد الفائدة ولا يزيد النقد،
  /// والعربون يزيد النقد قبل أن تكتمل البيعة.
  final double netCash;

  /// سحب الأرباح في الفترة — يُعرض وحده ولا يدخل أي حساب أعلاه.
  final double profitWithdrawals;

  final int invoiceCount;
  final int pieceCount;

  static const ReportSummary empty = ReportSummary(
    salesTotal: 0,
    costOfGoodsSold: 0,
    grossProfit: 0,
    expenses: 0,
    purchases: 0,
    netProfit: 0,
    cashIn: 0,
    cashOut: 0,
    netCash: 0,
    profitWithdrawals: 0,
    invoiceCount: 0,
    pieceCount: 0,
  );
}

/// يحسب ملخّص الفترة من فواتيرها وحركات صندوقها.
ReportSummary computeReport({
  required List<Sale> sales,
  required List<CashboxTransaction> transactions,
}) {
  var salesTotal = 0.0;
  var cost = 0.0;
  var pieces = 0;

  for (final sale in sales) {
    salesTotal += sale.total;
    cost += sale.cost;
    pieces += sale.pieceCount;
  }

  var expenses = 0.0;
  var purchases = 0.0;
  var profitWithdrawals = 0.0;
  var cashIn = 0.0;
  var cashOut = 0.0;

  for (final tx in transactions) {
    if (tx.isProfitWithdrawal) {
      // ربح المالك — خارج كل حسابات الربح والنقد معاً.
      // (رصيد الدرج يُنقصه فعلاً، لكن ذلك حساب آخر: `cashboxBalance`.)
      profitWithdrawals += tx.amount;
      continue;
    }
    if (tx.type == CashboxType.purchase) {
      // شراء بضاعة: **ليس مصروفاً ولا خسارة** — تحويل نقد إلى مخزون.
      // كلفته تُحسب وقت البيع (رأس المال المُباع)، وعدّه هنا يخصمه مرّتين
      // ويُظهر المحل خاسراً في كل يوم استلام بضاعة.
      purchases += tx.amount;
      continue;
    }
    if (tx.type.isCredit) {
      cashIn += tx.amount;
    } else {
      expenses += tx.amount;
      cashOut += tx.amount;
    }
  }

  final grossProfit = salesTotal - cost;

  return ReportSummary(
    salesTotal: salesTotal,
    costOfGoodsSold: cost,
    grossProfit: grossProfit,
    expenses: expenses,
    purchases: purchases,
    netProfit: grossProfit - expenses,
    cashIn: cashIn,
    cashOut: cashOut,
    netCash: cashIn - cashOut,
    profitWithdrawals: profitWithdrawals,
    invoiceCount: sales.length,
    pieceCount: pieces,
  );
}

/// رصيد الصندوق = أثر **كل** الحركات منذ البداية (سحب الأرباح يُنقصه فعلاً،
/// فالمال خرج من الدرج حقيقةً حتى لو لم يكن مصروفاً محاسبياً).
double cashboxBalance(List<CashboxTransaction> allTransactions) =>
    allTransactions.fold(0.0, (acc, tx) => acc + tx.signedAmount);

/// نطاق فترة التقارير.
enum ReportPeriod { today, week, month, year, custom }

extension ReportPeriodLabel on ReportPeriod {
  String get label => switch (this) {
        ReportPeriod.today => tr('اليوم'),
        ReportPeriod.week => tr('الأسبوع'),
        ReportPeriod.month => tr('الشهر'),
        ReportPeriod.year => tr('السنة'),
        ReportPeriod.custom => tr('مخصّصة'),
      };
}

class DateRange {
  const DateRange(this.from, this.to);
  final DateTime from;
  final DateTime to;

  bool contains(DateTime? d) =>
      d != null && !d.isBefore(from) && d.isBefore(to);
}

/// يحسب نطاق الفترة.
///
/// «اليوم» يبدأ من **آخر إغلاق صندوق** إن كان في اليوم نفسه: الإغلاق يبدأ
/// يوماً محاسبياً جديداً فوراً، فتعود كل الأرقام صفراً أمام صاحب المحل
/// بدل أن ينتظر منتصف الليل.
DateRange resolveRange(
  ReportPeriod period, {
  required DateTime now,
  DateTime? lastDayClose,
  DateTime? customFrom,
  DateTime? customTo,
}) {
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));

  switch (period) {
    case ReportPeriod.today:
      var from = startOfDay;
      if (lastDayClose != null &&
          lastDayClose.isAfter(startOfDay) &&
          !lastDayClose.isAfter(now)) {
        from = lastDayClose;
      }
      // إغلاق وقع بعد «الآن» (بدأ يوم الغد صراحةً) ⇒ الفترة تبدأ منه.
      if (lastDayClose != null && lastDayClose.isAfter(now)) {
        return DateRange(lastDayClose, lastDayClose.add(const Duration(days: 1)));
      }
      return DateRange(from, endOfDay);

    case ReportPeriod.week:
      // الأسبوع يبدأ السبت (أول أيام العمل في الجزائر).
      final daysSinceSaturday = (now.weekday + 1) % 7;
      final from = startOfDay.subtract(Duration(days: daysSinceSaturday));
      return DateRange(from, endOfDay);

    case ReportPeriod.month:
      return DateRange(DateTime(now.year, now.month), endOfDay);

    case ReportPeriod.year:
      return DateRange(DateTime(now.year), endOfDay);

    case ReportPeriod.custom:
      final from = customFrom ?? startOfDay;
      final to = customTo ?? endOfDay;
      return DateRange(
        DateTime(from.year, from.month, from.day),
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1)),
      );
  }
}
