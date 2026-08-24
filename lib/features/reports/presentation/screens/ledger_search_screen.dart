import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/scanner_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../sales/domain/models/sale.dart';
import '../providers/reports_providers.dart';
import '../widgets/invoice_detail_sheet.dart';
import '../../../../core/i18n/app_strings.dart';

/// نتيجة البحث عن منتج في كل الفواتير.
class _Hit {
  const _Hit(this.sale, this.item);
  final Sale sale;
  final SaleItem item;
}

/// بحث في السجل — **في كل الفواتير بلا تقيّد بالفترة**.
///
/// سؤال صاحب المحل المعتاد: «هذه القطعة، متى بِعتُها وبكم؟». الفترة
/// المختارة في شاشة التقارير لا تعنيه هنا.
class LedgerSearchScreen extends ConsumerStatefulWidget {
  const LedgerSearchScreen({super.key});

  @override
  ConsumerState<LedgerSearchScreen> createState() =>
      _LedgerSearchScreenState();
}

class _LedgerSearchScreenState extends ConsumerState<LedgerSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await ScannerService.scanOnce(context);
    if (code == null || !mounted) return;
    setState(() {
      _searchCtrl.text = code;
      _query = code;
    });
  }

  List<_Hit> _search(List<Sale> sales) {
    final q = normalizeForSearch(_query);
    final code = cleanBarcode(_query);
    if (q.isEmpty) return const [];

    final hits = <_Hit>[];
    for (final sale in sales) {
      for (final item in sale.items) {
        final byBarcode = code.isNotEmpty && item.barcode.contains(code);
        final byName = normalizeForSearch(item.name).contains(q);
        if (byBarcode || byName) hits.add(_Hit(sale, item));
      }
    }
    hits.sort((a, b) => (b.sale.createdAt ?? DateTime(0))
        .compareTo(a.sale.createdAt ?? DateTime(0)));
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(allSalesProvider);
    final sales = salesAsync.value ?? const <Sale>[];
    final hits = _search(sales);

    // اقتراحات من المخزون لتسهيل كتابة الاسم.
    final suggestions = _query.trim().isEmpty
        ? const <Product>[]
        : ref
            .watch(inventoryProvider)
            .where((p) => p.matches(_query))
            .take(6)
            .toList();

    var quantity = 0;
    var total = 0.0;
    var profit = 0.0;
    final invoices = <String>{};
    for (final hit in hits) {
      quantity += hit.item.quantity;
      total += hit.item.lineTotal;
      profit += hit.item.lineProfit;
      invoices.add(hit.sale.id);
    }

    return AppScaffold(
      route: AppRoutes.ledgerSearch,
      title: tr('بحث في السجل'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: AppSearchField(
              controller: _searchCtrl,
              autofocus: true,
              hint: tr('باركود أو اسم منتج — في كل الفواتير'),
              resultCount: hits.length,
              onChanged: (v) => setState(() => _query = v),
              onSubmitted: (v) => setState(() => _query = v),
              onScan: _scan,
            ),
          ),

          if (suggestions.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final p in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ActionChip(
                        avatar: const Icon(Icons.inventory_2, size: 15),
                        label: Text(p.name,
                            style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() {
                          _searchCtrl.text = p.name;
                          _query = p.name;
                        }),
                      ),
                    ),
                ],
              ),
            ),

          if (hits.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: tr('الفواتير'),
                      value: '${invoices.length}',
                    ),
                  ),
                  Expanded(
                    child: _Metric(label: tr('الكمية'), value: '$quantity'),
                  ),
                  Expanded(
                    child: _Metric(label: tr('الإجمالي'), value: money(total)),
                  ),
                  Expanded(
                    child: _Metric(
                      label: tr('الفائدة'),
                      value: money(profit),
                      color: profit >= 0 ? AppTheme.success : AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1),
          Expanded(
            child: salesAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _query.trim().isEmpty
                    ? EmptyState(
                        icon: Icons.manage_search,
                        message: tr('اكتب باركوداً أو اسم منتج،\nأو امسح بالكاميرا — يبحث في كل الفواتير.'),
                      )
                    : hits.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off,
                            message: trf('لم يُبَع «{0}» في أي فاتورة', [_query]),
                          )
                        : ListView.builder(
                            itemCount: hits.length,
                            itemBuilder: (context, i) {
                              final hit = hits[i];
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    hit.item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${formatDateTime(hit.sale.createdAt)} · '
                                        '${hit.item.quantity} × '
                                        '${money(hit.item.unitPrice)}'
                                        '${hit.sale.customerName.isNotEmpty ? ' · ${hit.sale.customerName}' : ''}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      SellerBadge(name: hit.sale.createdByName),
                                    ],
                                  ),
                                  trailing: Text(
                                    money(hit.item.lineTotal),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                  onTap: () =>
                                      showInvoiceSheet(context, hit.sale),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
