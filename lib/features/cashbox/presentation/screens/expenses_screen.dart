import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../domain/models/cashbox_transaction.dart';
import '../widgets/cashbox_dialogs.dart';
import '../../../../core/i18n/app_strings.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(expenseAccountsProvider);
    final allTx = ref.watch(allTransactionsProvider).value ??
        const <CashboxTransaction>[];

    // مصاريف بلا حساب — نعرضها حتى لا تضيع بصمت.
    final unassigned = allTx
        .where((t) => t.isRealExpense && t.accountId.isEmpty && t.recipientId.isEmpty)
        .toList();

    return AppScaffold(
      route: AppRoutes.expenses,
      title: tr('المصاريف'),
      actions: [
        IconButton(
          tooltip: tr('سحب / مصروف'),
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => showWithdrawDialog(context, ref),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addAccount(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr('حساب مصروف')),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          message: trf('تعذّر التحميل:\n{0}', [e]),
        ),
        data: (accounts) {
          if (accounts.isEmpty && unassigned.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              message: tr('لا حسابات مصروف بعد.\nأنشئ حسابات مثل: كهرباء، كراء، مشتريات...'),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              for (final account in accounts)
                _AccountTile(
                  account: account,
                  transactions: allTx
                      .where((t) => t.accountId == account.id)
                      .toList(),
                ),
              if (unassigned.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    tr('مصاريف بلا حساب'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
                for (final tx in unassigned)
                  Card(
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.help_outline,
                          color: AppTheme.warning),
                      title: Text(tx.note.isEmpty ? tr('مصروف') : tx.note),
                      subtitle: Text(formatDateTime(tx.createdAt)),
                      trailing: Text(
                        money(tx.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.danger,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('حساب مصروف جديد')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('الاسم'),
            hintText: tr('كهرباء، كراء، مشتريات...'),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('إضافة')),
          ),
        ],
      ),
    );

    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;

    try {
      await ref.read(cashboxRepositoryProvider)!.addAccount(name);
      if (context.mounted) showOk(context, tr('أُضيف الحساب'));
    } catch (e) {
      if (context.mounted) showErr(context, '$e');
    }
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.transactions});

  final ExpenseAccount account;
  final List<CashboxTransaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFF3E0),
          child: Icon(Icons.receipt_long, color: AppTheme.warning),
        ),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(trf('{0} حركة', [transactions.length])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(account.totalExpenses),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.danger,
              ),
            ),
            Text(
              tr('المجموع'),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
        children: [
          if (transactions.isEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(tr('لا حركات على هذا الحساب')),
            )
          else
            for (final tx in transactions)
              ListTile(
                dense: true,
                title: Text(tx.note.isEmpty ? tr('مصروف') : tx.note),
                subtitle: Text(
                  '${formatDateTime(tx.createdAt)} · ${tx.createdByName}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  money(tx.amount),
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ),
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: () => _rename(context, ref),
                icon: const Icon(Icons.edit, size: 18),
                label: Text(tr('إعادة تسمية')),
              ),
              TextButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.danger),
                label: Text(tr('حذف'),
                    style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: account.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('إعادة تسمية الحساب')),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('حفظ')),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    controller.dispose();
    if (ok != true || name.isEmpty || !context.mounted) return;
    await ref.read(cashboxRepositoryProvider)!.renameAccount(account.id, name);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف الحساب'),
      message: trf('سيُحذف حساب «{0}».\nالحركات المرتبطة به تبقى في السجل بلا حساب.', [account.name]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(cashboxRepositoryProvider)!.deleteAccount(account.id);
    if (context.mounted) showOk(context, tr('حُذف الحساب'));
  }
}
