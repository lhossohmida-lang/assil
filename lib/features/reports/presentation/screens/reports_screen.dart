import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../cashbox/domain/models/cashbox_transaction.dart';
import '../../../cashbox/presentation/widgets/cashbox_dialogs.dart';
import '../../../cashbox/presentation/widgets/close_day_dialog.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../suppliers/domain/models/purchase.dart';
import '../../../suppliers/presentation/providers/suppliers_providers.dart';
import '../../domain/reports_math.dart';
import '../providers/reports_providers.dart';
import '../widgets/invoice_detail_sheet.dart';
import '../widgets/report_cards.dart';
import '../../../../core/i18n/app_strings.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportSummaryProvider);
    final balance = ref.watch(cashboxBalanceProvider);
    final selected = ref.watch(selectedPeriodProvider);
    final ledger = ref.watch(ledgerProvider);
    final range = ref.watch(dateRangeProvider);

    return AppScaffold(
      route: AppRoutes.reports,
      title: tr('التقارير (لاروسات)'),
      actions: [
        IconButton(
          tooltip: tr('بحث في السجل'),
          icon: const Icon(Icons.manage_search),
          onPressed: () => context.go(AppRoutes.ledgerSearch),
        ),
        const _ReportsMenu(),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _PeriodSelector(selected: selected, range: range),
          const SizedBox(height: 4),
          _Dashboard(summary: summary, balance: balance),
          const SizedBox(height: 8),
          _CashActions(balance: balance),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18),
                const SizedBox(width: 6),
                Text(
                  trf('السجل — {0} عملية', [ledger.length]),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          if (ledger.isEmpty)
            Padding(
              padding: EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                message: tr('لا عمليات في هذه الفترة'),
              ),
            )
          else
            for (final entry in ledger) _LedgerTile(entry: entry),
        ],
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.selected, required this.range});
  final SelectedPeriod selected;
  final DateRange range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final period in ReportPeriod.values)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(period.label),
                    selected: selected.period == period,
                    onSelected: (_) async {
                      if (period == ReportPeriod.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          locale: const Locale('ar'),
                        );
                        if (picked != null) {
                          ref
                              .read(selectedPeriodProvider.notifier)
                              .setCustom(picked.start, picked.end);
                        }
                        return;
                      }
                      ref.read(selectedPeriodProvider.notifier).set(period);
                    },
                  ),
                ),
            ],
          ),
        ),
        Text(
          trf('من {0} إلى {1}', [formatDateTime(range.from), formatDateTime(range.to.subtract(const Duration(minutes: 1)))]),
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

/// لوحة الأرقام: ست بطاقات حول الدائرة الوسطى.
class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.summary, required this.balance});
  final ReportSummary summary;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      ReportCard(
        label: tr('المبيعات'),
        value: money(summary.salesTotal),
        icon: Icons.shopping_bag,
        color: AppTheme.primary,
        subtitle: trf('{0} فاتورة · {1} قطعة', [summary.invoiceCount, summary.pieceCount]),
      ),
      ReportCard(
        label: tr('الفائدة الخام'),
        value: money(summary.grossProfit),
        icon: Icons.trending_up,
        color: AppTheme.success,
        subtitle: tr('المبيعات − رأس المال المُباع'),
      ),
      ReportCard(
        label: tr('الفائدة بعد المصاريف'),
        value: money(summary.netProfit),
        icon: Icons.savings_outlined,
        color: summary.netProfit >= 0 ? AppTheme.success : AppTheme.danger,
        subtitle: trf('المصاريف {0}', [money(summary.expenses)]),
      ),
      ReportCard(
        label: tr('رأس المال المُباع'),
        value: money(summary.costOfGoodsSold),
        icon: Icons.inventory,
        color: AppTheme.accent,
        subtitle: tr('كلفة شراء ما خرج'),
      ),
      ReportCard(
        label: tr('لاروسات بعد المصاريف'),
        value: money(summary.netCash),
        icon: Icons.account_balance_wallet,
        color: summary.netCash >= 0 ? AppTheme.accent : AppTheme.danger,
        subtitle: tr('صافي النقد الداخل والخارج'),
      ),
      ReportCard(
        label: tr('رصيد الصندوق'),
        value: money(balance),
        icon: Icons.point_of_sale,
        color: AppTheme.warning,
        subtitle: tr('الآن — كل الفترات'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final dial = _DialWithDialog(amount: money(summary.profitWithdrawals));

        if (wide) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(children: cards.sublist(0, 3)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: dial,
                ),
                Expanded(
                  child: Column(children: cards.sublist(3)),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: dial,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  for (var i = 0; i < cards.length; i += 2)
                    Row(
                      children: [
                        Expanded(child: cards[i]),
                        if (i + 1 < cards.length)
                          Expanded(child: cards[i + 1])
                        else
                          const Expanded(child: SizedBox()),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DialWithDialog extends ConsumerWidget {
  const _DialWithDialog({required this.amount});
  final String amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfitDial(
      amount: amount,
      onTap: () => _closeDay(context, ref),
    );
  }

  Future<void> _closeDay(BuildContext context, WidgetRef ref) async {
    final balance = ref.read(cashboxBalanceProvider);
    final keep = await showCloseDayDialog(context, balance: balance);
    if (keep == null || !context.mounted) return;

    final repo = ref.read(cashboxRepositoryProvider);
    if (repo == null) return;

    // نبدأ اليوم المحاسبي التالي من **الآن**: تعود كل الأرقام صفراً فوراً
    // أمام صاحب المحل بدل أن ينتظر منتصف الليل.
    final closedAt = DateTime.now();
    try {
      await repo.closeDay(
        currentBalance: balance,
        keepForTomorrow: keep,
        actor: ref.read(actorProvider),
        closedAt: closedAt,
      );
      // ننقل عرض التقارير إلى الفترة الجديدة مباشرةً.
      ref.read(selectedPeriodProvider.notifier).set(ReportPeriod.today);
      if (context.mounted) {
        showOk(
          context,
          trf('أُغلق الصندوق — سُحب {0} أرباحاً، بقي {1} للغد', [money(balance - keep), money(keep)]),
        );
      }
    } catch (e) {
      if (context.mounted) showErr(context, trf('تعذّر إغلاق الصندوق: {0}', [e]));
    }
  }
}

class _CashActions extends ConsumerWidget {
  const _CashActions({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showDepositDialog(context, ref),
              icon: const Icon(Icons.add_circle_outline,
                  color: AppTheme.success),
              label: Text(tr('إيداع')),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showWithdrawDialog(context, ref),
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppTheme.danger),
              label: Text(tr('سحب / مصروف')),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entry.isSale) {
      final sale = entry.sale!;
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(0xFFE3F2FD),
            child: Icon(Icons.receipt, color: AppTheme.primary),
          ),
          // ⚠️ العنوان = **أسماء المنتجات** لا رقم الفاتورة: صاحب المحل
          // يتعرّف على البيعة بما بِيع فيها لا برقم لا يعني له شيئاً.
          title: Text(
            sale.productsTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trf('{0} · {1} قطعة · {2}{3}', [formatTime(sale.createdAt), sale.pieceCount, sale.paymentMethod.label, sale.customerName.isNotEmpty ? ' · ${sale.customerName}' : '']),
                style: const TextStyle(fontSize: 12),
              ),
              SellerBadge(name: sale.createdByName),
            ],
          ),
          trailing: Text(
            money(sale.total),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.success,
              fontSize: 15,
            ),
          ),
          onTap: () => showInvoiceSheet(context, sale),
        ),
      );
    }

    if (entry.isPurchase) return _purchaseTile(context, ref, entry.purchase!);

    final tx = entry.transaction!;
    final isWithdrawal = !tx.type.isCredit;
    final color = tx.isProfitWithdrawal
        ? AppTheme.primary
        : (isWithdrawal ? AppTheme.danger : AppTheme.success);

    return Card(
      color: isWithdrawal ? const Color(0xFFFFF5F5) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            tx.isProfitWithdrawal
                ? Icons.savings
                : (isWithdrawal ? Icons.arrow_upward : Icons.arrow_downward),
            color: color,
          ),
        ),
        title: Text(
          tx.note.isEmpty ? tx.type.label : tx.note,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            formatTime(tx.createdAt),
            if (tx.accountName.isNotEmpty) tx.accountName,
            if (tx.recipientName.isNotEmpty) tx.recipientName,
            if (tx.isProfitWithdrawal) tr('سحب أرباح — ليس مصروفاً'),
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isWithdrawal ? '-' : '+'} ${money(tx.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 15,
              ),
            ),
            IconButton(
              tooltip: tr('حذف الحركة'),
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _deleteTransaction(context, ref, tx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    CashboxTransaction tx,
  ) async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف الحركة'),
      message: trf('سيعود المبلغ {0} إلى الصندوق{1}{2}.', [money(tx.amount), tx.accountName.isNotEmpty ? '، ويُنقص من حساب «${tx.accountName}»' : '', tx.recipientName.isNotEmpty ? '، ويُنقص من سحوبات «${tx.recipientName}»' : '']),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref.read(cashboxRepositoryProvider)!.deleteTransaction(tx);
      if (context.mounted) showOk(context, tr('حُذفت الحركة وأُعيد المبلغ'));
    } catch (e) {
      if (context.mounted) showErr(context, '$e');
    }
  }
}

class _ReportsMenu extends ConsumerWidget {
  const _ReportsMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<int>(
      tooltip: tr('حذف السجلات القديمة'),
      icon: const Icon(Icons.more_vert),
      onSelected: (months) => _purge(context, ref, months),
      itemBuilder: (_) => [
        PopupMenuItem(value: 0, enabled: false, child: Text(tr('حذف الأقدم من:'))),
        PopupMenuItem(value: 1, child: Text(tr('شهر'))),
        PopupMenuItem(value: 3, child: Text(tr('3 أشهر'))),
        PopupMenuItem(value: 6, child: Text(tr('6 أشهر'))),
        PopupMenuItem(value: 12, child: Text(tr('سنة'))),
      ],
    );
  }

  Future<void> _purge(BuildContext context, WidgetRef ref, int months) async {
    if (months <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(days: months * 30));

    final ok = await confirmDialog(
      context,
      title: tr('حذف السجلات القديمة'),
      message: trf('ستُحذف كل الفواتير وحركات الصندوق الأقدم من {0} نهائياً.\n\nالمخزون ورأس المال لا يتأثّران.', [formatDate(cutoff)]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      final n = await ref.read(salesRepositoryProvider)!.purgeOlderThan(cutoff);
      if (context.mounted) showOk(context, trf('حُذف {0} سجلاً', [n]));
    } catch (e) {
      if (context.mounted) showErr(context, '$e');
    }
  }
}

/// فاتورة شراء في السجل.
///
/// تظهر **ولو لم يُدفع منها شيء**: الشراء بالدَّين لا يكتب حركة صندوق،
/// فكان يغيب تماماً عن السجل ويستلم صاحب المحل بضاعة بلا أي أثر مكتوب.
///
/// الرقم المعروض هو **الباقي على المحل** حين يكون هناك باقٍ، بالسالب
/// وبالأحمر — لأنه دَين لا مصروف. وإن سُدّدت كاملةً عُرض المدفوع بلا
/// إشارة، فالمال خرج وانتهى الأمر.
Widget _purchaseTile(BuildContext context, WidgetRef ref, Purchase purchase) {
  final unpaid = (purchase.total - purchase.paidAmount)
      .clamp(0, double.infinity)
      .toDouble();
  final hasDebt = unpaid > 0.009;

  return Card(
    color: hasDebt ? const Color(0xFFFFF5F5) : const Color(0xFFF3F6FA),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: (hasDebt ? AppTheme.danger : AppTheme.primary)
            .withValues(alpha: 0.12),
        child: Icon(
          Icons.local_shipping_outlined,
          color: hasDebt ? AppTheme.danger : AppTheme.primary,
        ),
      ),
      title: Text(
        trf('شراء — {0}', [
          purchase.supplierName.isEmpty ? tr('مورّد') : purchase.supplierName,
        ]),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trf('{0} · {1} صنف · الإجمالي {2}', [
              formatTime(purchase.createdAt),
              purchase.items.length,
              money(purchase.total),
            ]),
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            hasDebt
                ? trf('مدفوع {0} — الباقي دَين', [money(purchase.paidAmount)])
                : tr('مسدَّدة بالكامل'),
            style: TextStyle(
              fontSize: 11,
              color: hasDebt ? AppTheme.danger : AppTheme.textSecondary,
            ),
          ),
          SellerBadge(name: purchase.createdByName),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            hasDebt ? '−${money(unpaid)}' : money(purchase.paidAmount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: hasDebt ? AppTheme.danger : AppTheme.textPrimary,
            ),
          ),
          Text(
            tr('شراء بضاعة — ليس مصروفاً'),
            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
        ],
      ),
      onTap: () => _confirmDeletePurchase(context, ref, purchase),
    ),
  );
}

/// حذف فاتورة شراء من السجل — إلغاء تامّ كأنها لم تقع.
Future<void> _confirmDeletePurchase(
  BuildContext context,
  WidgetRef ref,
  Purchase purchase,
) async {
  final ok = await confirmDialog(
    context,
    title: tr('حذف فاتورة الشراء'),
    message: trf(
      'ستُلغى نهائياً: تعود الكمية من المخزون، وينقص رصيد المورّد بـ{0}، وتُحذف حركتها من الصندوق.\n\nملاحظة: سعر الشراء الحالي للمنتجات **لا يعود** إلى سابقه — صحّحه يدوياً إن لزم.',
      [money(purchase.total)],
    ),
    confirmLabel: tr('حذف'),
    destructive: true,
  );
  if (!ok) return;

  final repo = ref.read(suppliersRepositoryProvider);
  if (repo == null) return;
  final lookup = {
    for (final p in ref.read(inventoryProvider)) p.id: p,
  };
  try {
    await repo.deletePurchase(purchase, productLookup: lookup);
    if (context.mounted) showOk(context, tr('حُذفت فاتورة الشراء'));
  } catch (e) {
    if (context.mounted) showErr(context, trf('تعذّر الحذف: {0}', [e]));
  }
}
