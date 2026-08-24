import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/scanner_service.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../domain/models/product.dart';
import '../providers/inventory_providers.dart';
import '../widgets/product_tile.dart';
import '../widgets/quantity_dialog.dart';
import 'image_migration_screen.dart';
import 'product_form_screen.dart';
import '../../../../core/i18n/app_strings.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _lowStockOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> _filter(List<Product> all) {
    var list = all;
    if (_query.trim().isNotEmpty) {
      list = list.where((p) => p.matches(_query)).toList();
    }
    if (_lowStockOnly) {
      list = list.where((p) => p.isLowStock).toList();
    }
    return list;
  }

  Future<void> _scan() async {
    final code = await ScannerService.scanOnce(context);
    if (code == null || !mounted) return;
    setState(() {
      _searchCtrl.text = code;
      _query = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allProductsProvider);
    final products = ref.watch(inventoryProvider);
    final stats = ref.watch(inventoryStatsProvider);
    final filtered = _filter(products);

    return AppScaffold(
      route: AppRoutes.inventory,
      title: tr('المخزون'),
      actions: [
        IconButton(
          tooltip: tr('مسح بالكاميرا'),
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _scan,
        ),
        _InventoryMenu(onDone: () => setState(() {})),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<bool>(builder: (_) => const ProductFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(tr('منتج جديد')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: AppSearchField(
              controller: _searchCtrl,
              resultCount: filtered.length,
              onChanged: (v) => setState(() => _query = v),
              onScan: _scan,
            ),
          ),

          // ─── بطاقات الإحصاء ───
          SizedBox(
            height: 84,
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: tr('الأنواع'),
                    value: '${stats.typeCount}',
                    icon: Icons.category,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: tr('مجموع القطع'),
                    value: '${stats.pieceCount}',
                    icon: Icons.inventory_2,
                    color: AppTheme.accent,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: tr('قارب النفاد'),
                    value: '${stats.lowStockCount}',
                    icon: Icons.warning_amber_rounded,
                    color: AppTheme.warning,
                    onTap: () =>
                        setState(() => _lowStockOnly = !_lowStockOnly),
                  ),
                ),
              ],
            ),
          ),

          if (_lowStockOnly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt,
                      size: 16, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Text(tr('عرض ما قارب النفاد فقط')),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _lowStockOnly = false),
                    child: Text(tr('إلغاء الفلتر')),
                  ),
                ],
              ),
            ),

          const Divider(height: 8),

          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EmptyState(
                icon: Icons.cloud_off,
                message: trf('تعذّر تحميل المخزون:\n{0}', [e]),
              ),
              data: (_) {
                if (products.isEmpty) {
                  return EmptyState(
                    icon: Icons.inventory_2_outlined,
                    message: tr('المخزون فارغ — أضف أول منتج بالزر بالأسفل'),
                  );
                }
                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    message: trf('لا نتائج لـ «{0}»', [_query]),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => ProductTile(
                    product: filtered[i],
                    onEdit: () => Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (_) =>
                            ProductFormScreen(existing: filtered[i]),
                      ),
                    ),
                    onQuantity: () =>
                        showQuantityDialog(context, ref, filtered[i]),
                    onPrintTicket: () => _printTicket(filtered[i]),
                    onToggleStore: () => _toggleStore(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _printTicket(Product product) async {
    final copies = await showTicketCopiesDialog(context, product);
    if (copies == null || !mounted) return;

    final outcome =
        await ref.read(printServiceProvider).printTicket(product, copies: copies);
    if (!mounted) return;
    if (outcome.ok) {
      showOk(context, outcome.message);
    } else {
      showErr(context, outcome.message);
    }
  }

  Future<void> _toggleStore(Product product) async {
    final repo = ref.read(inventoryRepositoryProvider);
    if (repo == null) return;
    final next = !product.publishedToStore;
    try {
      await repo.setPublished(product, next);
      if (mounted) {
        showOk(
          context,
          next ? tr('أُعيد إلى المتجر الإلكتروني') : tr('أُزيل من المتجر الإلكتروني'),
        );
      }
    } catch (e) {
      if (mounted) showErr(context, '$e');
    }
  }
}

/// قائمة ⋮ في شاشة المخزون.
class _InventoryMenu extends ConsumerWidget {
  const _InventoryMenu({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: tr('المزيد'),
      onSelected: (value) => _handle(context, ref, value),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'import',
          child: ListTile(
            leading: Icon(Icons.upload_file),
            title: Text(tr('استيراد منتجات')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'migrate',
          child: ListTile(
            leading: Icon(Icons.cloud_upload_outlined),
            title: Text(tr('ترحيل الصور القديمة')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'sync',
          child: ListTile(
            leading: Icon(Icons.sync),
            title: Text(tr('مزامنة المتجر الإلكتروني')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'clear',
          child: ListTile(
            leading: Icon(Icons.storefront_outlined, color: AppTheme.danger),
            title: Text(tr('إزالة كل المنتجات من المتجر'),
                style: TextStyle(color: AppTheme.danger)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _handle(
      BuildContext context, WidgetRef ref, String value) async {
    final repo = ref.read(inventoryRepositoryProvider);
    if (repo == null) return;

    switch (value) {
      case 'import':
        context.go(AppRoutes.importProducts);

      case 'migrate':
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ImageMigrationScreen(),
          ),
        );

      case 'sync':
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text(tr('جارٍ مزامنة المتجر...'))),
        );
        try {
          final count = await repo.rebuildCatalog();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(trf('تمت المزامنة — {0} منتجاً في المتجر', [count])),
                backgroundColor: AppTheme.success,
              ),
            );
        } catch (e) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(trf('فشلت المزامنة: {0}', [e])),
                backgroundColor: AppTheme.danger,
              ),
            );
        }

      case 'clear':
        final ok = await confirmDialog(
          context,
          title: tr('إزالة كل المنتجات من المتجر'),
          message: tr('سيصير المتجر الإلكتروني فارغاً أمام الزبائن.\n**المخزون لا يُمسّ إطلاقاً** — يمكنك إعادة النشر بالمزامنة.'),
          confirmLabel: tr('إفراغ المتجر'),
          destructive: true,
        );
        if (!ok || !context.mounted) return;
        try {
          final n = await repo.clearCatalog();
          if (context.mounted) showOk(context, trf('أُزيل {0} منتجاً من المتجر', [n]));
        } catch (e) {
          if (context.mounted) showErr(context, '$e');
        }
    }
  }
}
