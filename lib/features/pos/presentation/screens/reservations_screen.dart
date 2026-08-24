import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../domain/models/reservation.dart';
import '../providers/pos_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// الفارسمون — الحجوزات بعربون.
class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});

  @override
  ConsumerState<ReservationsScreen> createState() =>
      _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ReservationStatus? _filter = ReservationStatus.active;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reservationsProvider);
    final all = async.value ?? const <Reservation>[];

    var list = all;
    if (_filter != null) {
      list = list.where((r) => r.status == _filter).toList();
    }
    if (_query.trim().isNotEmpty) {
      list = list.where((r) => r.matches(_query)).toList();
    }

    final active = all.where((r) => r.status == ReservationStatus.active);
    final activeTotal = active.fold(0.0, (acc, r) => acc + r.remaining);

    return AppScaffold(
      route: AppRoutes.reservations,
      title: tr('الفارسمون'),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark_added, color: AppTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trf('{0} حجز جارٍ', [active.length]),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      trf('الباقي {0}', [money(activeTotal)]),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
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
              hint: tr('ابحث بالاسم أو الهاتف أو المنتج'),
              resultCount: list.length,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final entry in <(ReservationStatus?, String)>[
                  (ReservationStatus.active, tr('جارٍ')),
                  (ReservationStatus.completed, tr('مكتمل')),
                  (ReservationStatus.cancelled, tr('ملغى')),
                  (null, tr('الكل')),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: _filter == entry.$1,
                      onSelected: (_) => setState(() => _filter = entry.$1),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.isLoading
                ? const Center(child: CircularProgressIndicator())
                : list.isEmpty
                    ? EmptyState(
                        icon: Icons.bookmark_border,
                        message: _query.isNotEmpty
                            ? trf('لا نتائج لـ «{0}»', [_query])
                            : tr('لا حجوزات في هذا التصنيف'),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _ReservationTile(reservation: list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReservationTile extends ConsumerWidget {
  const _ReservationTile({required this.reservation});
  final Reservation reservation;

  Color get _color => switch (reservation.status) {
        ReservationStatus.active => AppTheme.accent,
        ReservationStatus.completed => AppTheme.success,
        ReservationStatus.cancelled => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = reservation.status == ReservationStatus.active;

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _color.withValues(alpha: 0.12),
          child: Icon(Icons.bookmark, color: _color),
        ),
        title: Text(
          reservation.customerName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${reservation.productsTitle}\n'
          '${formatDateTime(reservation.createdAt)} · '
          '${reservation.status.label}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(reservation.remaining),
              style: TextStyle(fontWeight: FontWeight.bold, color: _color),
            ),
            Text(
              tr('الباقي'),
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final item in reservation.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name)),
                        Text('${item.quantity} × ${money(item.unitPrice)}'),
                      ],
                    ),
                  ),
                const Divider(),
                _kv(tr('الإجمالي'), money(reservation.total)),
                _kv(tr('العربون'), money(reservation.deposit)),
                _kv(tr('الباقي'), money(reservation.remaining), bold: true),
                if (reservation.note.isNotEmpty)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      trf('ملاحظة: {0}', [reservation.note]),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          OverflowBar(
            children: [
              if (reservation.phone.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(
                      'tel:${reservation.phone.replaceAll(RegExp(r'\s'), '')}',
                    );
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                  icon: const Icon(Icons.phone, size: 18),
                  label: Text(tr('اتصال')),
                ),
              if (isActive) ...[
                TextButton.icon(
                  onPressed: () => _complete(context, ref),
                  icon: const Icon(Icons.check_circle_outline,
                      size: 18, color: AppTheme.success),
                  label: Text(tr('إكمال البيع'),
                      style: TextStyle(color: AppTheme.success)),
                ),
                TextButton.icon(
                  onPressed: () => _cancel(context, ref),
                  icon: const Icon(Icons.cancel_outlined,
                      size: 18, color: AppTheme.danger),
                  label: Text(tr('إلغاء'),
                      style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: tr('إكمال الحجز'),
      message: trf('ستُنشأ فاتورة بإجمالي {0}، ويدخل الباقي {1} إلى الصندوق.\n\nالمخزون لا يتغيّر — البضاعة خرجت يوم الحجز.', [money(reservation.total), money(reservation.remaining)]),
      confirmLabel: tr('إكمال'),
    );
    if (!ok || !context.mounted) return;

    final posRepo = ref.read(posRepositoryProvider);
    final salesRepo = ref.read(salesRepositoryProvider);
    if (posRepo == null || salesRepo == null) return;

    try {
      final sale = await posRepo.completeReservation(
        reservation,
        actor: ref.read(actorProvider),
        saleId: salesRepo.sales.doc().id,
      );
      if (context.mounted) {
        showOk(context, trf('اكتمل الحجز — الفاتورة {0}', [sale.invoiceNumber]));
      }
      // طباعة الوصل اختيارية ولا توقف العملية.
      final outcome = await ref.read(printServiceProvider).printReceipt(sale);
      if (context.mounted && !outcome.ok) showErr(context, outcome.message);
    } catch (e) {
      if (context.mounted) showErr(context, trf('تعذّر إكمال الحجز: {0}', [e]));
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    var refund = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(tr('إلغاء الحجز')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                trf('ستعود {0} قطعة إلى المخزون.', [reservation.pieceCount]),
              ),
              if (reservation.deposit > 0)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: refund,
                  onChanged: (v) => setState(() => refund = v ?? false),
                  title: Text(trf('إرجاع العربون {0}', [money(reservation.deposit)])),
                  subtitle: Text(
                    tr('يُسجَّل مصروفاً. اتركه بلا تحديد إن احتُجز العربون.'),
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('تراجع')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('إلغاء الحجز')),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;

    final lookup = {
      for (final p in ref.read(allProductsProvider).value ?? const <Product>[])
        p.id: p,
    };

    try {
      await ref.read(posRepositoryProvider)!.cancelReservation(
            reservation,
            productLookup: lookup,
            actor: ref.read(actorProvider),
            refundDeposit: refund,
          );
      if (context.mounted) showOk(context, tr('أُلغي الحجز وعادت البضاعة'));
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
