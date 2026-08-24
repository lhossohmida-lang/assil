import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/cashbox/domain/models/cashbox_transaction.dart';
import 'package:kmsan/features/reports/domain/reports_math.dart';
import 'package:kmsan/features/sales/domain/models/sale.dart';

Sale sale({
  required double total,
  required double cost,
  int pieces = 1,
  DateTime? at,
}) =>
    Sale(
      id: 's${total.toInt()}',
      items: [
        SaleItem(
          productId: 'p',
          name: 'سلعة',
          quantity: pieces,
          unitPrice: total / pieces,
          purchasePrice: cost / pieces,
        ),
      ],
      subtotal: total,
      total: total,
      createdAt: at,
    );

CashboxTransaction tx(
  CashboxType type,
  double amount, {
  String note = '',
}) =>
    CashboxTransaction(id: 't', type: type, amount: amount, note: note);

void main() {
  group('ملخّص الفترة', () {
    test('الأرقام الأساسية', () {
      final summary = computeReport(
        sales: [
          sale(total: 5000, cost: 3000, pieces: 2),
          sale(total: 3000, cost: 1800, pieces: 1),
        ],
        transactions: [
          tx(CashboxType.income, 8000),
          tx(CashboxType.expense, 1200, note: 'كهرباء'),
        ],
      );

      expect(summary.salesTotal, 8000);
      expect(summary.costOfGoodsSold, 4800);
      expect(summary.grossProfit, 3200);
      expect(summary.expenses, 1200);
      expect(summary.netProfit, 2000);
      expect(summary.invoiceCount, 2);
      expect(summary.pieceCount, 3);
    });

    test('🔒 سحب الأرباح لا يُنقص الفائدة بعد المصاريف', () {
      final withoutWithdrawal = computeReport(
        sales: [sale(total: 10000, cost: 6000)],
        transactions: [tx(CashboxType.expense, 1000, note: 'كراء')],
      );
      final withWithdrawal = computeReport(
        sales: [sale(total: 10000, cost: 6000)],
        transactions: [
          tx(CashboxType.expense, 1000, note: 'كراء'),
          tx(CashboxType.profitWithdrawal, 2500),
        ],
      );

      // نفس الفائدة تماماً — السحب لا يغيّرها.
      expect(withWithdrawal.netProfit, withoutWithdrawal.netProfit);
      expect(withWithdrawal.expenses, withoutWithdrawal.expenses);
      expect(withWithdrawal.netProfit, 3000);

      // لكنه يُعرض في سطره الخاص.
      expect(withWithdrawal.profitWithdrawals, 2500);
      expect(withoutWithdrawal.profitWithdrawals, 0);
    });

    test('🔒 التوافق الرجعي: سحب أرباح قديم مسجَّل كمصروف', () {
      final summary = computeReport(
        sales: [sale(total: 10000, cost: 6000)],
        transactions: [
          tx(CashboxType.expense, 1000, note: 'كراء'),
          // حركة قديمة من قبل وجود نوع مستقلّ.
          tx(CashboxType.expense, 2500, note: 'إغلاق الصندوق ليوم 12/05'),
        ],
      );

      expect(summary.expenses, 1000, reason: 'الكراء وحده مصروف');
      expect(summary.profitWithdrawals, 2500);
      expect(summary.netProfit, 3000);
    });

    test('لاروسات بعد المصاريف تختلف عن الفائدة عند البيع بالكريدي', () {
      // فاتورة 10000 لم يُدفع منها إلا 2000 نقداً.
      final summary = computeReport(
        sales: [sale(total: 10000, cost: 6000)],
        transactions: [
          tx(CashboxType.income, 2000),
          tx(CashboxType.expense, 500),
        ],
      );

      expect(summary.netProfit, 3500); // 4000 فائدة − 500 مصاريف
      expect(summary.netCash, 1500); // 2000 دخل − 500 خرج
      expect(summary.netCash, isNot(summary.netProfit));
    });

    test('الإيداع يزيد النقد ولا يزيد الفائدة', () {
      final summary = computeReport(
        sales: const [],
        transactions: [tx(CashboxType.deposit, 5000)],
      );
      expect(summary.cashIn, 5000);
      expect(summary.netCash, 5000);
      expect(summary.grossProfit, 0);
      expect(summary.netProfit, 0);
    });

    test('🔒 شراء البضاعة ليس مصروفاً ولا يُنقص الفائدة ولا النقد', () {
      // اليوم الذي تستلم فيه بضاعة بـ80 ألفاً يجب ألّا يظهر خاسراً:
      // كلفة البضاعة تُحسب وقت بيعها (رأس المال المُباع)، لا وقت شرائها.
      final withoutPurchase = computeReport(
        sales: [sale(total: 10000, cost: 6000)],
        transactions: [
          tx(CashboxType.income, 10000),
          tx(CashboxType.expense, 500, note: 'كهرباء'),
        ],
      );
      final withPurchase = computeReport(
        sales: [sale(total: 10000, cost: 6000)],
        transactions: [
          tx(CashboxType.income, 10000),
          tx(CashboxType.expense, 500, note: 'كهرباء'),
          tx(CashboxType.purchase, 80000, note: 'شراء من المورّد'),
        ],
      );

      expect(withPurchase.expenses, withoutPurchase.expenses);
      expect(withPurchase.netProfit, withoutPurchase.netProfit);
      expect(withPurchase.netCash, withoutPurchase.netCash);
      expect(withPurchase.netProfit, 3500);

      // لكنه يظهر في سطره الخاص.
      expect(withPurchase.purchases, 80000);
      expect(withoutPurchase.purchases, 0);
    });

    test('🔒 سحب الأرباح لا يُنقص «لاروسات بعد المصاريف»', () {
      final base = computeReport(
        sales: const [],
        transactions: [tx(CashboxType.income, 9000)],
      );
      final drawn = computeReport(
        sales: const [],
        transactions: [
          tx(CashboxType.income, 9000),
          tx(CashboxType.profitWithdrawal, 7000),
        ],
      );
      expect(drawn.netCash, base.netCash);
      expect(drawn.netCash, 9000);
      expect(drawn.profitWithdrawals, 7000);
    });

    test('فترة فارغة', () {
      final summary = computeReport(sales: const [], transactions: const []);
      expect(summary.salesTotal, 0);
      expect(summary.netProfit, 0);
      expect(summary.invoiceCount, 0);
    });
  });

  group('رصيد الصندوق', () {
    test('سحب الأرباح يُنقص الرصيد فعلاً — المال خرج من الدرج', () {
      final balance = cashboxBalance([
        tx(CashboxType.income, 10000),
        tx(CashboxType.expense, 1500),
        tx(CashboxType.profitWithdrawal, 3000),
        tx(CashboxType.deposit, 500),
      ]);
      expect(balance, 6000);
    });

    test('شراء البضاعة يُنقص الرصيد فعلاً وإن لم يكن مصروفاً', () {
      final balance = cashboxBalance([
        tx(CashboxType.income, 50000),
        tx(CashboxType.purchase, 30000),
      ]);
      expect(balance, 20000);
    });
  });

  group('نطاق الفترة', () {
    final now = DateTime(2026, 5, 12, 15, 30);

    test('اليوم بلا إغلاق سابق يبدأ من منتصف الليل', () {
      final range = resolveRange(ReportPeriod.today, now: now);
      expect(range.from, DateTime(2026, 5, 12));
      expect(range.to, DateTime(2026, 5, 13));
    });

    test('🔒 إغلاق الصندوق اليوم يبدأ يوماً محاسبياً جديداً فوراً', () {
      final closedAt = DateTime(2026, 5, 12, 14, 0);
      final range = resolveRange(
        ReportPeriod.today,
        now: now,
        lastDayClose: closedAt,
      );
      expect(range.from, closedAt);

      // بيعة قبل الإغلاق خارج الفترة، وبعده داخلها.
      expect(range.contains(DateTime(2026, 5, 12, 13, 0)), isFalse);
      expect(range.contains(DateTime(2026, 5, 12, 15, 0)), isTrue);
    });

    test('إغلاق من يوم مضى لا يؤثّر على اليوم', () {
      final range = resolveRange(
        ReportPeriod.today,
        now: now,
        lastDayClose: DateTime(2026, 5, 11, 20, 0),
      );
      expect(range.from, DateTime(2026, 5, 12));
    });

    test('إغلاق يبدأ يوم الغد صراحةً ينقل الفترة إليه', () {
      final tomorrow = DateTime(2026, 5, 13);
      final range = resolveRange(
        ReportPeriod.today,
        now: now,
        lastDayClose: tomorrow,
      );
      expect(range.from, tomorrow);
      expect(range.contains(now), isFalse,
          reason: 'أرقام اليوم تعود صفراً فوراً بعد الإغلاق');
    });

    test('الشهر والسنة', () {
      expect(resolveRange(ReportPeriod.month, now: now).from,
          DateTime(2026, 5, 1));
      expect(resolveRange(ReportPeriod.year, now: now).from,
          DateTime(2026, 1, 1));
    });

    test('الأسبوع يبدأ السبت', () {
      // 2026-05-12 هو ثلاثاء ⇒ السبت السابق 2026-05-09.
      expect(now.weekday, DateTime.tuesday);
      final range = resolveRange(ReportPeriod.week, now: now);
      expect(range.from, DateTime(2026, 5, 9));
      expect(range.from.weekday, DateTime.saturday);
    });

    test('الفترة المخصّصة تشمل يوم النهاية كاملاً', () {
      final range = resolveRange(
        ReportPeriod.custom,
        now: now,
        customFrom: DateTime(2026, 5, 1),
        customTo: DateTime(2026, 5, 10),
      );
      expect(range.contains(DateTime(2026, 5, 10, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 5, 11, 0, 1)), isFalse);
    });
  });
}
