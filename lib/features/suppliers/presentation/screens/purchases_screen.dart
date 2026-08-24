import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../domain/models/purchase.dart';
import '../providers/suppliers_providers.dart';
import 'new_purchase_screen.dart';
import '../../../../core/i18n/app_strings.dart';

/// سجل فواتير الشراء.
class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(purchasesProvider);
    final all = async.value ?? const <Purchase>[];
    final list = _query.trim().isEmpty
        ? all
        : all.where((p) => p.matches(_query)).toList();

    final total = list.fold(0.0, (acc, p) => acc + p.total);
    final unpaid = list.fold(0.0, (acc, p) => acc + p.remaining);

    return AppScaffold(
      route: AppRoutes.purchases,
      title: tr('المشتريات'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<bool>(builder: (_) => const NewPurchaseScreen()),
        ),
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(tr('شراء جديد')),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: tr('عدد الفواتير'),
                  value: '${list.length}',
                  icon: Icons.receipt_long,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: tr('قيمة المشتريات'),
                  value: money(total),
                  icon: Icons.shopping_cart,
                  color: AppTheme.accent,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: tr('غير مدفوع'),
                  value: money(unpaid),
                  icon: Icons.pending_actions,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AppSearchField(
              controller: _searchCtrl,
              hint: tr('ابحث بالمورّد أو المنتج أو رقم الفاتورة'),
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
                        icon: Icons.shopping_cart_outlined,
                        message: _query.isNotEmpty
                            ? trf('لا نتائج لـ «{0}»', [_query])
                            : tr('لا مشتريات بعد.\nسجّل أول فاتورة شراء بالزر بالأسفل — ستُحدَّث كميات المخزون وأسعار الشراء تلقائياً.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 90),
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _PurchaseTile(purchase: list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseTile extends ConsumerWidget {
  const _PurchaseTile({required this.purchase});
  final Purchase purchase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paid = purchase.remaining <= 0.009;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: (paid ? AppTheme.success : AppTheme.warning)
              .withValues(alpha: 0.12),
          child: Icon(
            Icons.shopping_bag,
            color: paid ? AppTheme.success : AppTheme.warning,
          ),
        ),
        title: Text(
          purchase.productsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          trf('{0} · {1}\n{2} · {3} قطعة', [purchase.supplierName, purchase.invoiceNumber, formatDateTime(purchase.createdAt), purchase.pieceCount]),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          money(purchase.total),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in purchase.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(item.name)),
                            Text(
                              '${item.quantity} × ${money(item.unitCost)}',
                            ),
                          ],
                        ),
                        if (item.costChanged)
                          Text(
                            item.costDelta > 0
                                ? trf('ارتفع سعر الشراء {0} (كان {1})', [money(item.costDelta), money(item.previousCost)])
                                : trf('انخفض سعر الشراء {0} (كان {1})', [money(-item.costDelta), money(item.previousCost)]),
                            style: TextStyle(
                              fontSize: 11,
                              color: item.costDelta > 0
                                  ? AppTheme.danger
                                  : AppTheme.success,
                            ),
                          ),
                      ],
                    ),
                  ),
                const Divider(),
                _kv(tr('المجموع'), money(purchase.subtotal)),
                if (purchase.discount > 0)
                  _kv(tr('التخفيض'), '- ${money(purchase.discount)}'),
                _kv(tr('الإجمالي'), money(purchase.total), bold: true),
                _kv(tr('المدفوع'), money(purchase.paidAmount)),
                if (purchase.remaining > 0)
                  _kv(tr('الباقي للمورّد'), money(purchase.remaining), bold: true),
                if (purchase.note.isNotEmpty) _kv(tr('ملاحظة'), purchase.note),
              ],
            ),
          ),
          OverflowBar(
            children: [
              TextButton.icon(
                onPressed: () => _delete(context, ref),
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.danger),
                label: Text(tr('حذف الفاتورة'),
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
      title: tr('حذف فاتورة الشراء'),
      message: trf('ستُخصم {0} قطعة من المخزون، ويُصحَّح حساب المورّد، وتُحذف حركة الصندوق.\n\n⚠️ سعر الشراء لا يعود إلى قيمته السابقة تلقائياً — قد تكون فواتير أحدث غيّرته. عدّله من بطاقة المنتج إن لزم.', [purchase.pieceCount]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    final lookup = {
      for (final p in ref.read(allProductsProvider).value ?? const <Product>[])
        p.id: p,
    };

    try {
      await ref
          .read(suppliersRepositoryProvider)!
          .deletePurchase(purchase, productLookup: lookup);
      if (context.mounted) showOk(context, tr('حُذفت الفاتورة'));
    } catch (e) {
      if (context.mounted) showErr(context, '$e');
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
