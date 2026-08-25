import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/scanner_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/services/receipt_service.dart';
import '../../../sales/domain/models/sale.dart';
import '../providers/reports_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// تفاصيل فاتورة مع كل عملياتها.
Future<void> showInvoiceSheet(BuildContext context, Sale sale) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InvoiceSheet(sale: sale),
    );

class _InvoiceSheet extends ConsumerStatefulWidget {
  const _InvoiceSheet({required this.sale});
  final Sale sale;

  @override
  ConsumerState<_InvoiceSheet> createState() => _InvoiceSheetState();
}

class _InvoiceSheetState extends ConsumerState<_InvoiceSheet> {
  bool _busy = false;

  /// نقرأ الفاتورة الحيّة من المزوّد: الإرجاع والاستبدال يعدّلانها،
  /// ولو عرضنا النسخة التي فُتحت بها الشاشة لبقيت الأرقام قديمة.
  Sale get _sale {
    final all = ref.watch(allSalesLookupProvider);
    return all[widget.sale.id] ?? widget.sale;
  }

  Map<String, Product> get _lookup => {
        for (final p in ref.read(allProductsProvider).value ?? const <Product>[])
          p.id: p,
      };

  @override
  Widget build(BuildContext context) {
    final sale = _sale;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  sale.productsTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${sale.invoiceNumber} · ${formatDateTime(sale.createdAt)}',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (sale.customerName.isNotEmpty)
                  Text(
                    trf('الزبونة: {0}{1}', [sale.customerName, sale.isVip ? ' (VIP)' : '']),
                    style: const TextStyle(fontSize: 13),
                  ),
                if (sale.createdByName.isNotEmpty)
                  Text(
                    trf('البائع: {0}', [sale.createdByName]),
                    style: const TextStyle(fontSize: 13),
                  ),
                const Divider(height: 24),

                for (var i = 0; i < sale.items.length; i++)
                  _ItemRow(
                    item: sale.items[i],
                    onReturn: _busy ? null : () => _returnItem(sale, i),
                    onExchange: _busy ? null : () => _exchangeItem(sale, i),
                  ),

                const Divider(height: 24),
                _kv(tr('المجموع'), money(sale.subtotal)),
                if (sale.vipDiscount > 0)
                  _kv(tr('خصم VIP'), '- ${money(sale.vipDiscount)}'),
                if (sale.discount > 0)
                  _kv(tr('التخفيض'), '- ${money(sale.discount)}'),
                _kv(tr('الإجمالي'), money(sale.total), bold: true),
                _kv(tr('طريقة الدفع'), sale.paymentMethod.label),
                if (sale.paymentMethod == PaymentMethod.credit) ...[
                  _kv(tr('المدفوع'), money(sale.paidAmount)),
                  _kv(tr('الباقي (دين)'), money(sale.remaining)),
                ],

                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _showReceiptImage(sale),
                      icon: const Icon(Icons.receipt_long),
                      label: Text(tr('صورة الفاتورة')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _reprint(sale),
                      icon: const Icon(Icons.print),
                      label: Text(tr('إعادة الطباعة')),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _deleteSale(sale),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                      ),
                      icon: const Icon(Icons.delete_forever),
                      label: Text(tr('حذف الفاتورة')),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// حساب الكريدي المرتبط بالفاتورة — يُمرَّر للإرجاع والحذف حتى يعود
  /// الدَّين مع البضاعة، فلا تُطالَب الزبونة بثمن سلعة عادت إلى الرفّ.
  String _creditAccountId(Sale sale) => creditAccountIdForSale(
        ref.read(creditAccountsProvider).value ?? const [],
        sale.id,
      );

  // ───────────────────────── العمليات ─────────────────────────

  Future<void> _returnItem(Sale sale, int index) async {
    final item = sale.items[index];
    final qty = await _askQuantity(
      title: trf('إرجاع «{0}»', [item.name]),
      max: item.quantity,
      hint: tr('يعود للمخزون وتنقص الفاتورة بقيمته — كأنه لم يُبَع. ما دفعه الزبون زائداً عن الفاتورة الجديدة يُردّ نقداً، والباقي يُخصم من ذمّته.'),
    );
    if (qty == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(salesRepositoryProvider)!.returnItem(
            sale: sale,
            itemIndex: index,
            quantity: qty,
            actor: ref.read(actorProvider),
            product: _lookup[item.productId],
            creditAccountId: _creditAccountId(sale),
          );
      if (mounted) {
        showOk(context, trf('أُرجع {0} × {1}', [item.name, qty]));
        if (sale.items.length == 1 && qty >= item.quantity) {
          Navigator.of(context).pop(); // فرغت الفاتورة فحُذفت.
        }
      }
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر الإرجاع: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exchangeItem(Sale sale, int index) async {
    final item = sale.items[index];
    final result = await showDialog<_ExchangeResult>(
      context: context,
      builder: (_) => _ExchangeDialog(item: item),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(salesRepositoryProvider)!.exchangeItem(
            sale: sale,
            itemIndex: index,
            quantity: result.quantity,
            replacement: result.product,
            replacementPrice: result.price,
            actor: ref.read(actorProvider),
            originalProduct: _lookup[item.productId],
          );
      if (mounted) showOk(context, trf('تمّ الاستبدال بـ {0}', [result.product.name]));
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر الاستبدال: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteSale(Sale sale) async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف الفاتورة نهائياً'),
      message: trf('ستعود كل منتجاتها ({0} قطعة) إلى المخزون، وتُحذف حركتها من الصندوق ومن السجل.\n\nلا يمكن التراجع.', [sale.pieceCount]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(salesRepositoryProvider)!
          .deleteSale(
            sale,
            productLookup: _lookup,
            creditAccountId: _creditAccountId(sale),
            reservationId: reservationIdForSale(
              ref.read(reservationsProvider).value ?? const [],
              sale.id,
            ),
          );
      if (mounted) {
        Navigator.of(context).pop();
        showOk(context, tr('حُذفت الفاتورة وعادت البضاعة للمخزون'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showErr(context, trf('تعذّر الحذف: {0}', [e]));
      }
    }
  }

  Future<void> _reprint(Sale sale) async {
    final outcome = await ref.read(printServiceProvider).printReceipt(sale);
    if (!mounted) return;
    outcome.ok
        ? showOk(context, outcome.message)
        : showErr(context, outcome.message);
  }

  /// يعرض الوصل كصورة — **مولّدة من نفس الملف الذي يُرسَل للطابعة**،
  /// فما تراه هنا هو ما سيخرج على الورق حرفياً.
  Future<void> _showReceiptImage(Sale sale) async {
    setState(() => _busy = true);
    try {
      final built = await ReceiptService.build(
        sale: sale,
        settings: ref.read(printSettingsProvider).receipt,
      );
      final raster =
          await Printing.raster(built.bytes, dpi: 110).first;
      final png = await raster.toPng();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trf('الوصل — {0}مم', [built.heightMm.toStringAsFixed(0)]),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    child: Image.memory(Uint8List.fromList(png)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _reprint(sale);
                  },
                  icon: const Icon(Icons.print),
                  label: Text(tr('طباعة')),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر توليد صورة الوصل: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<int?> _askQuantity({
    required String title,
    required int max,
    String hint = '',
  }) async {
    var value = max;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint.isNotEmpty)
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: value > 1
                        ? () => setState(() => value--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: value < max
                        ? () => setState(() => value++)
                        : null,
                  ),
                ],
              ),
              Text(trf('من أصل {0}', [max])),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(value),
              child: Text(tr('تأكيد')),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onReturn,
    required this.onExchange,
  });

  final SaleItem item;
  final VoidCallback? onReturn;
  final VoidCallback? onExchange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.quantity} × ${money(item.unitPrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(money(item.lineTotal)),
          IconButton(
            tooltip: tr('إرجاع'),
            icon: const Icon(Icons.undo, size: 20, color: AppTheme.warning),
            onPressed: onReturn,
          ),
          IconButton(
            tooltip: tr('استبدال'),
            icon: Icon(Icons.swap_horiz, size: 20, color: AppTheme.accent),
            onPressed: onExchange,
          ),
        ],
      ),
    );
  }
}

class _ExchangeResult {
  const _ExchangeResult(this.product, this.quantity, this.price);
  final Product product;
  final int quantity;
  final double price;
}

/// نافذة الاستبدال — **تُظهر فرق السعر قبل التأكيد**.
class _ExchangeDialog extends ConsumerStatefulWidget {
  const _ExchangeDialog({required this.item});
  final SaleItem item;

  @override
  ConsumerState<_ExchangeDialog> createState() => _ExchangeDialogState();
}

class _ExchangeDialogState extends ConsumerState<_ExchangeDialog> {
  final _searchCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _query = '';
  Product? _selected;
  late int _quantity = widget.item.quantity;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _select(Product p) {
    setState(() {
      _selected = p;
      _priceCtrl.text = moneyPlain(p.sellPrice);
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
      _select(match);
    } else {
      setState(() {
        _searchCtrl.text = code;
        _query = code;
      });
      if (mounted) showErr(context, trf('لا يوجد منتج بالباركود «{0}»', [code]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final results = _query.trim().isEmpty
        ? const <Product>[]
        : inventory.where((p) => p.matches(_query)).take(20).toList();

    final oldValue = widget.item.unitPrice * _quantity;
    final newPrice = toDouble(_priceCtrl.text);
    final newValue = newPrice * _quantity;
    final difference = newValue - oldValue;

    return AlertDialog(
      title: Text(tr('استبدال منتج')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trf('المنتج الحالي: {0} ({1})', [widget.item.name, money(widget.item.unitPrice)]),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(tr('الكمية المستبدَلة:')),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: _quantity < widget.item.quantity
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                ],
              ),
              const Divider(height: 20),

              AppSearchField(
                controller: _searchCtrl,
                hint: tr('ابحث عن البديل بالاسم أو الباركود'),
                resultCount: results.length,
                onChanged: (v) => setState(() => _query = v),
                onScan: _scan,
              ),
              const SizedBox(height: 8),

              if (_selected == null)
                SizedBox(
                  height: 180,
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            tr('اكتب للبحث عن البديل'),
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) => ListTile(
                            dense: true,
                            title: Text(results[i].name),
                            subtitle: Text(
                              trf('{0} · متوفّر {1}', [money(results[i].sellPrice), results[i].availableQuantity]),
                            ),
                            onTap: () => _select(results[i]),
                          ),
                        ),
                )
              else ...[
                Card(
                  color: AppTheme.accent.withValues(alpha: 0.06),
                  child: ListTile(
                    title: Text(_selected!.name),
                    subtitle: Text(trf('متوفّر {0}', [_selected!.availableQuantity])),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _selected = null),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                MoneyField(
                  controller: _priceCtrl,
                  label: tr('سعر البديل'),
                  helper: tr('يمكن تعديله'),
                ),
                const SizedBox(height: 12),

                // ⚠️ فرق السعر يُعرض **قبل** التأكيد — البائع يعرف كم
                // يأخذ أو يُعيد للزبونة قبل أن يضغط.
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (difference.abs() < 0.01
                            ? AppTheme.textSecondary
                            : (difference > 0
                                ? AppTheme.success
                                : AppTheme.warning))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _kv(tr('قيمة القديم'), money(oldValue)),
                      _kv(tr('قيمة البديل'), money(newValue)),
                      const Divider(),
                      _kv(
                        difference > 0.009
                            ? tr('تأخذ من الزبونة')
                            : (difference < -0.009
                                ? tr('تُعيد للزبونة')
                                : tr('لا فرق')),
                        money(difference.abs()),
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: _selected == null
              ? null
              : () => Navigator.of(context).pop(
                    _ExchangeResult(_selected!, _quantity, newPrice),
                  ),
          child: Text(tr('تأكيد الاستبدال')),
        ),
      ],
    );
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
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );

/// فهرس الفواتير بالمعرّف — حتى تعرض شاشة التفاصيل النسخة الحيّة
/// بعد الإرجاع أو الاستبدال، لا النسخة التي فُتحت بها.
final allSalesLookupProvider = Provider<Map<String, Sale>>((ref) {
  final sales = ref.watch(allSalesProvider).value ?? const <Sale>[];
  return {for (final s in sales) s.id: s};
});
