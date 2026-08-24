import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../reports/presentation/widgets/invoice_detail_sheet.dart';
import '../../../sales/domain/models/sale.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/models/customer.dart';
import '../../../../core/i18n/app_strings.dart';

/// الزبائن — تُنشأ بطاقاتهم تلقائياً عند البيع باسمهم.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _vipOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersProvider);
    final all = async.value ?? const <Customer>[];
    final vipPercent = ref.watch(vipDiscountPercentProvider);

    var list = all;
    if (_vipOnly) list = list.where((c) => c.isVip).toList();
    if (_query.trim().isNotEmpty) {
      list = list.where((c) => c.matches(_query)).toList();
    }

    return AppScaffold(
      route: AppRoutes.customers,
      title: tr('الزبائن'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null, vipPercent),
        icon: const Icon(Icons.person_add),
        label: Text(tr('زبونة جديدة')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: AppSearchField(
              controller: _searchCtrl,
              hint: tr('ابحث بالاسم أو الهاتف'),
              resultCount: list.length,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SwitchListTile(
            dense: true,
            value: _vipOnly,
            onChanged: (v) => setState(() => _vipOnly = v),
            title: Text(trf('زبونات VIP فقط (خصم {0}٪)', [vipPercent.toInt()])),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        message: _query.isNotEmpty
                            ? trf('لا نتائج لـ «{0}»', [_query])
                            : tr('لا زبائن بعد — تُنشأ البطاقة تلقائياً عند البيع باسم زبونة'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _CustomerTile(
                          customer: list[i],
                          onEdit: () => _edit(list[i], vipPercent),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Customer? existing, double vipPercent) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    var isVip = existing?.isVip ?? false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? tr('زبونة جديدة') : tr('تعديل الزبونة')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: tr('الاسم *')),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('الهاتف')),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isVip,
                onChanged: (v) => setState(() => isVip = v),
                title: Text(tr('زبونة VIP')),
                subtitle: Text(trf('خصم {0}٪ تلقائي', [vipPercent.toInt()])),
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
              child: Text(tr('حفظ')),
            ),
          ],
        ),
      ),
    );

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    nameCtrl.dispose();
    phoneCtrl.dispose();

    if (ok != true || name.isEmpty || !mounted) return;

    try {
      await ref.read(salesRepositoryProvider)!.saveCustomer(
            Customer(
              id: existing?.id ?? '',
              name: name,
              phone: phone,
              isVip: isVip,
              totalPurchases: existing?.totalPurchases ?? 0,
              purchaseCount: existing?.purchaseCount ?? 0,
              createdAt: existing?.createdAt,
            ),
          );
      if (mounted) showOk(context, tr('حُفظت الزبونة'));
    } catch (e) {
      if (mounted) showErr(context, '$e');
    }
  }
}

class _CustomerTile extends ConsumerWidget {
  const _CustomerTile({required this.customer, required this.onEdit});

  final Customer customer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // مشتريات هذه الزبونة — مطابقة بالاسم لأن الفواتير القديمة قد لا
    // تحمل معرّفاً.
    final sales = (ref.watch(allSalesProvider).value ?? const <Sale>[])
        .where((s) =>
            s.customerId == customer.id ||
            (customer.id.isEmpty
                ? false
                : normalizeForSearch(s.customerName) ==
                    normalizeForSearch(customer.name)))
        .toList();

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor:
              (customer.isVip ? AppTheme.warning : AppTheme.primary)
                  .withValues(alpha: 0.12),
          child: Icon(
            customer.isVip ? Icons.star : Icons.person,
            color: customer.isVip ? AppTheme.warning : AppTheme.primary,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                customer.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (customer.isVip)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(fontSize: 11, color: AppTheme.warning),
                ),
              ),
          ],
        ),
        subtitle: Text(
          trf('{0} · {1} فاتورة · {2}', [customer.phone.isEmpty ? tr('بلا هاتف') : customer.phone, customer.purchaseCount, money(customer.totalPurchases)]),
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          if (sales.isEmpty)
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(tr('لا مشتريات مسجّلة')),
            )
          else
            for (final sale in sales.take(20))
              ListTile(
                dense: true,
                title: Text(
                  sale.productsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  formatDateTime(sale.createdAt),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(money(sale.total)),
                onTap: () => showInvoiceSheet(context, sale),
              ),
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: Text(tr('تعديل')),
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف الزبونة'),
      message: trf('ستُحذف بطاقة «{0}». فواتيرها تبقى في السجل.', [customer.name]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(salesRepositoryProvider)!.deleteCustomer(customer.id);
    if (context.mounted) showOk(context, tr('حُذفت البطاقة'));
  }
}
