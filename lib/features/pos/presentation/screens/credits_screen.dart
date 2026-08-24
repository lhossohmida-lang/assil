import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../customers/domain/models/customer.dart';
import '../providers/pos_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// الكريديات — حسابات البيع الآجل.
class CreditsScreen extends ConsumerStatefulWidget {
  const CreditsScreen({super.key});

  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _hideSettled = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(creditAccountsProvider);
    final all = async.value ?? const <CreditAccount>[];

    var list = all;
    if (_hideSettled) list = list.where((a) => !a.isSettled).toList();
    if (_query.trim().isNotEmpty) {
      list = list.where((a) => a.matches(_query)).toList();
    }

    final totalRemaining = all.fold(0.0, (acc, a) => acc + a.remaining);

    return AppScaffold(
      route: AppRoutes.credits,
      title: tr('الكريديات'),
      actions: [
        IconButton(
          tooltip: tr('استيراد كريديات من ملف'),
          icon: const Icon(Icons.upload_file),
          onPressed: () => context.go(AppRoutes.importCredits),
        ),
      ],
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.credit_score, color: AppTheme.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('مجموع الديون المتبقّية'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(totalRemaining),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AppSearchField(
              controller: _searchCtrl,
              hint: tr('ابحث بالاسم أو الهاتف'),
              resultCount: list.length,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SwitchListTile(
            dense: true,
            value: _hideSettled,
            onChanged: (v) => setState(() => _hideSettled = v),
            title: Text(tr('إخفاء الحسابات المسدَّدة')),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.credit_score,
                        message: _query.isNotEmpty
                            ? trf('لا نتائج لـ «{0}»', [_query])
                            : trf('لا كريديات{0}', [_hideSettled ? tr(' غير مسدَّدة') : '']),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _CreditTile(account: list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CreditTile extends ConsumerWidget {
  const _CreditTile({required this.account});
  final CreditAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (account.isSettled ? AppTheme.success : AppTheme.danger)
              .withValues(alpha: 0.12),
          child: Icon(
            account.isSettled ? Icons.check_circle : Icons.pending,
            color: account.isSettled ? AppTheme.success : AppTheme.danger,
          ),
        ),
        title: Text(
          account.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          account.phone.isEmpty ? tr('بلا هاتف') : account.phone,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(account.remaining),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: account.isSettled ? AppTheme.success : AppTheme.danger,
              ),
            ),
            Text(
              tr('المتبقّي'),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _kv(tr('إجمالي الدين'), money(account.totalDebt)),
                _kv(tr('المسدَّد'), money(account.totalPaid)),
                _kv(tr('المتبقّي'), money(account.remaining), bold: true),
              ],
            ),
          ),
          if (account.payments.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  tr('سجل السداد'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            for (final payment in account.payments.reversed)
              ListTile(
                dense: true,
                leading: const Icon(Icons.payments_outlined,
                    color: AppTheme.success, size: 20),
                title: Text(money(payment.amount)),
                subtitle: Text(
                  '${formatDateTime(payment.at)}'
                  '${payment.byName.isNotEmpty ? ' · ${payment.byName}' : ''}'
                  '${payment.note.isNotEmpty ? ' · ${payment.note}' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
          OverflowBar(
            children: [
              if (account.phone.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () => _call(account.phone),
                  icon: const Icon(Icons.phone, size: 18),
                  label: Text(tr('اتصال')),
                ),
                TextButton.icon(
                  onPressed: () => _whatsapp(account.phone),
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(tr('واتساب')),
                ),
              ],
              if (!account.isSettled)
                TextButton.icon(
                  onPressed: () => _addPayment(context, ref),
                  icon: const Icon(Icons.add_card, size: 18),
                  label: Text(tr('تسجيل دفعة')),
                ),
              TextButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.danger),
                label:
                    Text(tr('حذف'), style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'\s'), '')}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _whatsapp(String phone) async {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // أرقام الجزائر المحلّية تبدأ بـ0 — واتساب يريد رمز الدولة.
    if (clean.startsWith('0')) clean = '213${clean.substring(1)}';
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _addPayment(BuildContext context, WidgetRef ref) async {
    final amountCtrl =
        TextEditingController(text: moneyPlain(account.remaining));
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('دفعة من {0}', [account.customerName])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trf('المتبقّي: {0}', [money(account.remaining)])),
            const SizedBox(height: 12),
            MoneyField(
              controller: amountCtrl,
              label: tr('المبلغ المدفوع'),
              autofocus: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: tr('ملاحظة')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('تسجيل')),
          ),
        ],
      ),
    );

    final amount = toDouble(amountCtrl.text);
    final note = noteCtrl.text.trim();
    amountCtrl.dispose();
    noteCtrl.dispose();

    if (ok != true || amount <= 0 || !context.mounted) return;

    try {
      await ref.read(posRepositoryProvider)!.addCreditPayment(
            account,
            amount,
            actor: ref.read(actorProvider),
            note: note,
          );
      if (context.mounted) showOk(context, trf('سُجّلت دفعة {0}', [money(amount)]));
    } catch (e) {
      if (context.mounted) showErr(context, '$e');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف حساب الكريدي'),
      message: trf('سيُحذف حساب «{0}» ودَينه المتبقّي {1}.\n\nالفواتير تبقى في السجل.', [account.customerName, money(account.remaining)]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(posRepositoryProvider)!.deleteCreditAccount(account.id);
    if (context.mounted) showOk(context, tr('حُذف الحساب'));
  }

  Widget _kv(String key, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key),
            Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      );
}
