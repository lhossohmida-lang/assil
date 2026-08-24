import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/scanner_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../domain/models/purchase.dart';
import '../../domain/models/supplier.dart';
import '../providers/suppliers_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// تسجيل فاتورة شراء جديدة.
///
/// هنا يتغيّر سعر شراء المنتج. الفواتير القديمة لا تتأثّر لأن كل سطر بيع
/// يحمل سعر الشراء وقت بيعه، فأرباح الماضي تبقى كما حُسبت.
class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  Supplier? _supplier;
  final List<PurchaseItem> _items = [];

  final _searchCtrl = TextEditingController();
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();

  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0.0, (acc, i) => acc + i.lineTotal);
  double get _total =>
      (_subtotal - toDouble(_discountCtrl.text)).clamp(0, double.infinity);

  void _addProduct(Product p) {
    if (_items.any((i) => i.productId == p.id)) {
      showInfo(context, trf('«{0}» موجود في الفاتورة', [p.name]));
      return;
    }
    setState(() {
      _items.add(PurchaseItem(
        productId: p.id,
        name: p.name,
        barcode: p.barcode,
        quantity: 1,
        // نبدأ بسعر الشراء الحالي: أغلب المرات لا يتغيّر، والبائع
        // يعدّله فقط إن رفع المورّد سعره.
        unitCost: p.purchasePrice,
        previousCost: p.purchasePrice,
        previousSellPrice: p.sellPrice,
      ));
      _searchCtrl.clear();
      _query = '';
    });
  }

  Future<void> _scan() async {
    final code = await ScannerService.scanOnce(context);
    if (code == null || !mounted) return;
    final match = ref
        .read(inventoryProvider)
        .where((p) => p.barcode == code)
        .firstOrNull;
    if (match != null) {
      _addProduct(match);
    } else {
      showErr(context, trf('لا يوجد منتج بالباركود «{0}»', [code]));
    }
  }

  Future<void> _save() async {
    if (_supplier == null) {
      showErr(context, tr('اختر المورّد أولاً'));
      return;
    }
    if (_items.isEmpty) {
      showErr(context, tr('أضف منتجاً واحداً على الأقل'));
      return;
    }

    final repo = ref.read(suppliersRepositoryProvider);
    if (repo == null) return;

    setState(() => _busy = true);
    try {
      final actor = ref.read(actorProvider);
      final purchase = Purchase(
        id: repo.newPurchaseId(),
        supplierId: _supplier!.id,
        supplierName: _supplier!.name,
        items: _items,
        subtotal: _subtotal,
        discount: toDouble(_discountCtrl.text),
        total: _total,
        paidAmount: toDouble(_paidCtrl.text).clamp(0, _total).toDouble(),
        note: _noteCtrl.text.trim(),
        createdBy: actor.uid,
        createdByName: actor.name,
        createdAt: DateTime.now(),
      );

      final lookup = {
        for (final p
            in ref.read(allProductsProvider).value ?? const <Product>[])
          p.id: p,
      };

      await repo.commitPurchase(
        purchase,
        productLookup: lookup,
        actor: actor,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        showOk(
          context,
          trf('سُجّلت الفاتورة — دخل {0} قطعة للمخزون', [purchase.pieceCount]),
        );
      }
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر الحفظ: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers =
        ref.watch(suppliersListProvider).value ?? const <Supplier>[];
    final inventory = ref.watch(inventoryProvider);
    final results = _query.trim().isEmpty
        ? const <Product>[]
        : inventory.where((p) => p.matches(_query)).take(15).toList();

    final paid = toDouble(_paidCtrl.text).clamp(0, _total);
    final remaining = _total - paid;

    return Scaffold(
      appBar: AppBar(title: Text(tr('شراء جديد'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ─── المورّد ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping, color: AppTheme.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _supplier?.id,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: tr('المورّد *'),
                        isDense: true,
                      ),
                      items: [
                        for (final s in suppliers)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (id) => setState(
                        () => _supplier =
                            suppliers.where((s) => s.id == id).firstOrNull,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (suppliers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tr('لا موردين بعد — أضف مورّداً من شاشة الموردين أولاً.'),
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),

          const SizedBox(height: 8),

          // ─── إضافة منتجات ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSearchField(
                    controller: _searchCtrl,
                    hint: tr('ابحث عن منتج لإضافته للفاتورة'),
                    resultCount: results.length,
                    onChanged: (v) => setState(() => _query = v),
                    onScan: _scan,
                  ),
                  if (results.isNotEmpty)
                    SizedBox(
                      height: 170,
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) => ListTile(
                          dense: true,
                          title: Text(results[i].name),
                          subtitle: Text(
                            trf('شراء {0} · بيع {1} · المخزون {2}', [money(results[i].purchasePrice), money(results[i].sellPrice), results[i].quantity]),
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: const Icon(Icons.add_circle_outline),
                          onTap: () => _addProduct(results[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ─── أسطر الفاتورة ───
          if (_items.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.shopping_cart_outlined,
                message: tr('الفاتورة فارغة — ابحث عن منتج أو امسح باركوده'),
              ),
            )
          else
            for (var i = 0; i < _items.length; i++)
              _ItemCard(
                item: _items[i],
                onChanged: (next) => setState(() => _items[i] = next),
                onRemove: () => setState(() => _items.removeAt(i)),
              ),

          const SizedBox(height: 8),

          // ─── المجاميع ───
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(tr('مجموع الفاتورة'), money(_subtotal)),
                  const SizedBox(height: 8),
                  MoneyField(
                    controller: _discountCtrl,
                    label: tr('تخفيض من المورّد'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _row(tr('الإجمالي'), money(_total), bold: true),
                  const Divider(),
                  MoneyField(
                    controller: _paidCtrl,
                    label: tr('المدفوع الآن'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: Text(tr('دفع الكل')),
                        onPressed: () => setState(
                          () => _paidCtrl.text = moneyPlain(_total),
                        ),
                      ),
                      ActionChip(
                        label: Text(tr('بلا دفع')),
                        onPressed: () => setState(() => _paidCtrl.text = '0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _row(
                    tr('الباقي للمورّد (دَين عليك)'),
                    money(remaining.toDouble()),
                    bold: true,
                    color: remaining > 0 ? AppTheme.warning : AppTheme.success,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(labelText: tr('ملاحظة')),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              tr('عند الحفظ: تُضاف الكميات للمخزون، ويُحدَّث سعر شراء كل منتج إلى السعر الجديد، ويخرج المدفوع من الصندوق كـ«شراء بضاعة» — لا يُحسب مصروفاً ولا يُنقص الفائدة.\nأرباح الفواتير القديمة لا تتأثّر.'),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
          ),

          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(tr('حفظ فاتورة الشراء')),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(String key, String value,
          {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key, style: TextStyle(color: color)),
            Text(
              value,
              style: TextStyle(
                fontSize: bold ? 17 : 14,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      );
}

/// سطر منتج في فاتورة الشراء — الكمية وسعر الشراء الجديد وسعر بيع اختياري.
class _ItemCard extends StatefulWidget {
  const _ItemCard({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  final PurchaseItem item;
  final ValueChanged<PurchaseItem> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  late final TextEditingController _cost =
      TextEditingController(text: moneyPlain(widget.item.unitCost));
  late final TextEditingController _sell = TextEditingController(
    text: moneyPlain(widget.item.newSellPrice ?? widget.item.previousSellPrice),
  );

  @override
  void dispose() {
    _cost.dispose();
    _sell.dispose();
    super.dispose();
  }

  void _push() {
    final cost = toDouble(_cost.text);
    final sell = toDouble(_sell.text);
    widget.onChanged(widget.item.copyWith(
      unitCost: cost,
      newSellPrice: sell,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final profit = toDouble(_sell.text) - toDouble(_cost.text);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      size: 18, color: AppTheme.danger),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            Row(
              children: [
                Text(tr('الكمية')),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove, size: 16),
                  onPressed: item.quantity > 1
                      ? () => widget.onChanged(
                            item.copyWith(quantity: item.quantity - 1),
                          )
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.add, size: 16),
                  onPressed: () => widget.onChanged(
                    item.copyWith(quantity: item.quantity + 1),
                  ),
                ),
                const Spacer(),
                Text(
                  money(item.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MoneyField(
                    controller: _cost,
                    label: tr('سعر الشراء الجديد'),
                    onChanged: (_) => setState(_push),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MoneyField(
                    controller: _sell,
                    label: tr('سعر البيع'),
                    onChanged: (_) => setState(_push),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (item.costChanged)
              Text(
                item.costDelta > 0
                    ? trf('⚠️ ارتفع سعر الشراء {0} عن {1}', [money(item.costDelta), money(item.previousCost)])
                    : trf('انخفض سعر الشراء {0} عن {1}', [money(-item.costDelta), money(item.previousCost)]),
                style: TextStyle(
                  fontSize: 11.5,
                  color: item.costDelta > 0
                      ? AppTheme.danger
                      : AppTheme.success,
                ),
              ),
            Text(
              profit <= 0
                  ? trf('تنبيه: لا فائدة بهذا السعر ({0})', [money(profit)])
                  : trf('الفائدة على القطعة {0} · على الكمية {1}', [money(profit), money(profit * item.quantity)]),
              style: TextStyle(
                fontSize: 11.5,
                color: profit <= 0 ? AppTheme.danger : AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
