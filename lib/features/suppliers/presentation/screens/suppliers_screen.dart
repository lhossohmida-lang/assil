import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../cashbox/domain/models/cashbox_transaction.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../domain/models/purchase.dart';
import '../../domain/models/supplier.dart';
import '../providers/suppliers_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// الموردون وحساباتهم.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(suppliersListProvider);
    final all = async.value ?? const <Supplier>[];
    final list = _query.trim().isEmpty
        ? all
        : all.where((s) => s.matches(_query)).toList();
    final debt = ref.watch(totalSupplierDebtProvider);

    return AppScaffold(
      route: AppRoutes.suppliers,
      title: tr('الموردون'),
      actions: [
        IconButton(
          tooltip: tr('استيراد موردين من ملف'),
          icon: const Icon(Icons.upload_file),
          onPressed: () => context.go(AppRoutes.importSuppliers),
        ),
        IconButton(
          tooltip: tr('المشتريات'),
          icon: const Icon(Icons.shopping_cart_checkout),
          onPressed: () => context.go(AppRoutes.purchases),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt),
        label: Text(tr('مورّد جديد')),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, color: AppTheme.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('مجموع ما عليك للموردين'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(debt),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warning,
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
          const Divider(height: 16),
          Expanded(
            child: async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.local_shipping_outlined,
                        message: _query.isNotEmpty
                            ? trf('لا نتائج لـ «{0}»', [_query])
                            : tr('لا موردين بعد — أضف أول مورّد بالزر بالأسفل'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _SupplierTile(
                          supplier: list[i],
                          onEdit: () => _edit(list[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Supplier? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? tr('مورّد جديد') : tr('تعديل المورّد')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(labelText: tr('العنوان')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(labelText: tr('ملاحظة')),
                ),
              ],
            ),
          ),
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
    );

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final address = addressCtrl.text.trim();
    final note = noteCtrl.text.trim();
    for (final c in [nameCtrl, phoneCtrl, addressCtrl, noteCtrl]) {
      c.dispose();
    }
    if (ok != true || name.isEmpty || !mounted) return;

    try {
      await ref.read(suppliersRepositoryProvider)!.saveSupplier(
            existing?.copyWith(
                  name: name,
                  phone: phone,
                  address: address,
                  note: note,
                ) ??
                Supplier(
                  id: '',
                  name: name,
                  phone: phone,
                  address: address,
                  note: note,
                ),
          );
      if (mounted) showOk(context, tr('حُفظ المورّد'));
    } catch (e) {
      if (mounted) showErr(context, '$e');
    }
  }
}

class _SupplierTile extends ConsumerWidget {
  const _SupplierTile({required this.supplier, required this.onEdit});

  final Supplier supplier;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases =
        ref.watch(supplierPurchasesProvider(supplier.id)).value ??
            const <Purchase>[];
    final transactions =
        ref.watch(supplierTransactionsProvider(supplier.id)).value ??
            const <CashboxTransaction>[];

    final color = supplier.isSettled ? AppTheme.success : AppTheme.warning;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.local_shipping, color: color),
        ),
        title: Text(
          supplier.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            supplier.phone.isEmpty ? tr('بلا هاتف') : supplier.phone,
            trf('{0} فاتورة', [purchases.length]),
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(supplier.remaining),
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              supplier.isSettled ? tr('مسدَّد') : tr('عليك'),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _kv(tr('مجموع المشتريات'), money(supplier.totalPurchases)),
                _kv(tr('المدفوع له'), money(supplier.totalPaid)),
                _kv(tr('المتبقّي عليك'), money(supplier.remaining), bold: true),
                if (supplier.advance > 0)
                  _kv(tr('رصيد لك عنده'), money(supplier.advance)),
                if (supplier.address.isNotEmpty)
                  _kv(tr('العنوان'), supplier.address),
                if (supplier.note.isNotEmpty) _kv(tr('ملاحظة'), supplier.note),
              ],
            ),
          ),

          if (purchases.isNotEmpty) ...[
            const Divider(),
            _SubTitle(tr('فواتير الشراء')),
            for (final p in purchases.take(15))
              ListTile(
                dense: true,
                leading: const Icon(Icons.receipt_long, size: 20),
                title: Text(
                  p.productsTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  trf('{0} · {1} · {2} قطعة', [p.invoiceNumber, formatDateTime(p.createdAt), p.pieceCount]),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  money(p.total),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],

          if (transactions.isNotEmpty) ...[
            const Divider(),
            _SubTitle(tr('حركات الصندوق معه')),
            for (final t in transactions.take(15))
              ListTile(
                dense: true,
                leading: const Icon(Icons.payments_outlined,
                    size: 20, color: AppTheme.warning),
                title: Text(t.note.isEmpty ? tr('دفعة') : t.note),
                subtitle: Text(
                  formatDateTime(t.createdAt),
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  money(t.amount),
                  style: const TextStyle(color: AppTheme.warning),
                ),
              ),
          ],

          OverflowBar(
            children: [
              if (supplier.phone.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () => _launch('tel:${_digits(supplier.phone)}'),
                  icon: const Icon(Icons.phone, size: 18),
                  label: Text(tr('اتصال')),
                ),
                TextButton.icon(
                  onPressed: () =>
                      _launch('https://wa.me/${_intl(supplier.phone)}'),
                  icon: const Icon(Icons.chat, size: 18),
                  label: Text(tr('واتساب')),
                ),
              ],
              if (!supplier.isSettled)
                TextButton.icon(
                  onPressed: () => _pay(context, ref),
                  icon: const Icon(Icons.payments,
                      size: 18, color: AppTheme.success),
                  label: Text(tr('تسجيل دفعة'),
                      style: TextStyle(color: AppTheme.success)),
                ),
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

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final amountCtrl =
        TextEditingController(text: moneyPlain(supplier.remaining));
    final noteCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('دفعة إلى {0}', [supplier.name])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(trf('المتبقّي عليك: {0}', [money(supplier.remaining)])),
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
            const SizedBox(height: 8),
            Text(
              tr('يخرج المبلغ من الصندوق كـ«شراء بضاعة» — لا يُحسب مصروفاً ولا يُنقص الفائدة.'),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
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
      await ref.read(suppliersRepositoryProvider)!.paySupplier(
            supplier,
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
      title: tr('حذف المورّد'),
      message: trf('سيُحذف «{0}» وحسابه.\nفواتير الشراء تبقى في سجل المشتريات.', [supplier.name]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await ref.read(suppliersRepositoryProvider)!.deleteSupplier(supplier.id);
    if (context.mounted) showOk(context, tr('حُذف المورّد'));
  }

  static String _digits(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  static String _intl(String phone) {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '213${clean.substring(1)}';
    return clean;
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

class _SubTitle extends StatelessWidget {
  const _SubTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      );
}
