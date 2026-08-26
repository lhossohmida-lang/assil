import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cashbox/data/cashbox_repository.dart';
import '../../../cashbox/domain/models/cashbox_transaction.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../suppliers/domain/models/purchase.dart';
import '../../../suppliers/presentation/providers/suppliers_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/reports_math.dart';

final cashboxRepositoryProvider = Provider<CashboxRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return CashboxRepository(ref.watch(firestoreProvider), storeId);
});

/// كل حركات الصندوق — لازمة للرصيد التراكمي.
final allTransactionsProvider =
    StreamProvider<List<CashboxTransaction>>((ref) {
  final repo = ref.watch(cashboxRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll();
});

/// كل الفواتير — الترتيب والفلترة محلياً (لا فهارس مركّبة).
final allSalesProvider = StreamProvider<List<Sale>>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchSales();
});

final expenseAccountsProvider = StreamProvider<List<ExpenseAccount>>((ref) {
  final repo = ref.watch(cashboxRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAccounts();
});

/// رصيد الصندوق الحالي (كل الحركات منذ البداية).
final cashboxBalanceProvider = Provider<double>((ref) => cashboxBalance(
      ref.watch(allTransactionsProvider).value ?? const [],
    ));

/// الفترة المختارة في شاشة التقارير.
class SelectedPeriod {
  const SelectedPeriod(this.period, {this.from, this.to});
  final ReportPeriod period;
  final DateTime? from;
  final DateTime? to;
}

class PeriodNotifier extends Notifier<SelectedPeriod> {
  @override
  SelectedPeriod build() => const SelectedPeriod(ReportPeriod.today);

  void set(ReportPeriod period) => state = SelectedPeriod(period);

  void setCustom(DateTime from, DateTime to) =>
      state = SelectedPeriod(ReportPeriod.custom, from: from, to: to);
}

final selectedPeriodProvider =
    NotifierProvider<PeriodNotifier, SelectedPeriod>(PeriodNotifier.new);

/// النطاق الزمني الفعلي للفترة المختارة.
final dateRangeProvider = Provider<DateRange>((ref) {
  final selected = ref.watch(selectedPeriodProvider);
  final lastClose = ref.watch(storeSettingsProvider).value?.lastDayClose;
  return resolveRange(
    selected.period,
    now: DateTime.now(),
    lastDayClose: lastClose,
    customFrom: selected.from,
    customTo: selected.to,
  );
});

final periodSalesProvider = Provider<List<Sale>>((ref) {
  final range = ref.watch(dateRangeProvider);
  final all = ref.watch(allSalesProvider).value ?? const <Sale>[];
  return all.where((s) => range.contains(s.createdAt)).toList();
});

/// مشتريات الفترة — تظهر في السجل **ولو لم يُدفع منها شيء**.
///
/// الشراء بالدَّين لا يكتب حركة صندوق (لا نقد خرج)، فكان يغيب عن السجل
/// تماماً: يستلم صاحب المحل بضاعة بمليون دينار ولا يرى لها أثراً.
final periodPurchasesProvider = Provider<List<Purchase>>((ref) {
  final range = ref.watch(dateRangeProvider);
  final all = ref.watch(purchasesProvider).value ?? const <Purchase>[];
  return all.where((p) => range.contains(p.createdAt)).toList();
});

final periodTransactionsProvider = Provider<List<CashboxTransaction>>((ref) {
  final range = ref.watch(dateRangeProvider);
  final all =
      ref.watch(allTransactionsProvider).value ?? const <CashboxTransaction>[];
  return all.where((t) => range.contains(t.createdAt)).toList();
});

final reportSummaryProvider = Provider<ReportSummary>((ref) => computeReport(
      sales: ref.watch(periodSalesProvider),
      transactions: ref.watch(periodTransactionsProvider),
    ));

/// عنصر في السجل الموحّد: فاتورة أو حركة صندوق.
class LedgerEntry {
  const LedgerEntry.sale(this.sale)
      : transaction = null,
        purchase = null;
  const LedgerEntry.transaction(this.transaction)
      : sale = null,
        purchase = null;
  const LedgerEntry.purchase(this.purchase)
      : sale = null,
        transaction = null;

  final Sale? sale;
  final CashboxTransaction? transaction;
  final Purchase? purchase;

  bool get isSale => sale != null;
  bool get isPurchase => purchase != null;
  DateTime get at =>
      (sale?.createdAt ?? purchase?.createdAt ?? transaction?.createdAt) ??
      DateTime(0);
}

/// السجل الموحّد للفترة: الفواتير والسحوبات معاً، الأحدث أولاً.
///
/// حركات الدخل الناتجة عن البيع لا تُعرض: الفاتورة نفسها معروضة، وعرضهما
/// معاً يُظهر كل بيعة سطرين ويربك صاحب المحل.
final ledgerProvider = Provider<List<LedgerEntry>>((ref) {
  final sales = ref.watch(periodSalesProvider);
  final txs = ref.watch(periodTransactionsProvider);
  final buys = ref.watch(periodPurchasesProvider);

  final entries = <LedgerEntry>[
    for (final s in sales) LedgerEntry.sale(s),
    for (final b in buys) LedgerEntry.purchase(b),
    for (final t in txs)
      // حركة الدخل مخفيّة لأن فاتورتها معروضة، وحركة الشراء مخفيّة
      // لأن **فاتورة الشراء نفسها** معروضة — وعرضهما معاً يُظهر كل
      // عملية سطرين. وفاتورة الشراء أصدق: تظهر ولو لم يُدفع شيء.
      if (t.type != CashboxType.income && t.type != CashboxType.purchase)
        LedgerEntry.transaction(t),
  ];
  entries.sort((a, b) => b.at.compareTo(a.at));
  return entries;
});
