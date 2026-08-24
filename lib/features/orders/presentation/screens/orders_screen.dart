import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/services/order_label_service.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/models/public_order.dart';
import '../providers/orders_providers.dart';
import '../../../../core/i18n/app_strings.dart';


class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  OrderStatus? _filter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(ordersProvider);
    final all = async.value ?? const <PublicOrder>[];

    var list = all;
    if (_filter != null) list = list.where((o) => o.status == _filter).toList();
    if (_query.trim().isNotEmpty) {
      list = list.where((o) => o.matches(_query)).toList();
    }

    final pending = all.where((o) => o.status == OrderStatus.pending).length;

    final storefrontUrl =
        (ref.watch(storeSettingsProvider).value?.storefrontUrl ?? '').trim();

    return AppScaffold(
      route: AppRoutes.orders,
      title: tr('الطلبات'),
      actions: [
        IconButton(
          tooltip: storefrontUrl.isEmpty
              ? tr('اضبط عنوان المتجر في الإعدادات أوّلاً')
              : tr('فتح المتجر الإلكتروني'),
          icon: const Icon(Icons.storefront_outlined),
          // مُعطَّل بلا عنوان: زرّ يفتح صفحة فارغة أسوأ من زرّ باهت
          // يقول للمستخدم إن شيئاً ينقص.
          onPressed: storefrontUrl.isEmpty
              ? null
              : () => _openStorefront(context, storefrontUrl),
        ),
      ],
      body: Column(
        children: [
          if (pending > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: AppTheme.danger),
                  const SizedBox(width: 10),
                  Text(
                    trf('{0} طلب جديد بانتظار التأكيد', [pending]),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AppSearchField(
              controller: _searchCtrl,
              hint: tr('ابحث بالاسم أو الهاتف أو رقم الطلب'),
              resultCount: list.length,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(tr('الكل')),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final status in OrderStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(status.label),
                      selected: _filter == status,
                      onSelected: (_) => setState(() => _filter = status),
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
                        icon: Icons.shopping_bag_outlined,
                        message: _query.isNotEmpty
                            ? trf('لا نتائج لـ «{0}»', [_query])
                            : tr('لا طلبات في هذا التصنيف'),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) =>
                            _OrderTile(order: list[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends ConsumerStatefulWidget {
  const _OrderTile({required this.order});
  final PublicOrder order;

  @override
  ConsumerState<_OrderTile> createState() => _OrderTileState();
}

class _OrderTileState extends ConsumerState<_OrderTile> {
  bool _busy = false;

  PublicOrder get order => widget.order;

  Color get _color => switch (order.status) {
        OrderStatus.pending => AppTheme.danger,
        OrderStatus.confirmed => AppTheme.warning,
        OrderStatus.shipped => AppTheme.primary,
        OrderStatus.delivered => AppTheme.success,
        OrderStatus.cancelled => AppTheme.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _color.withValues(alpha: 0.12),
          child: Icon(
            order.isInquiry ? Icons.help_outline : Icons.shopping_bag,
            color: _color,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.customerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                order.status.label,
                style: TextStyle(fontSize: 11, color: _color),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${order.orderNumber} · ${order.wilaya}\n'
          '${order.productsTitle} · ${formatDateTime(order.createdAt)}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (order.isInquiry)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      tr('استفسار — ليس طلب شراء'),
                      style: TextStyle(color: AppTheme.warning),
                    ),
                  ),
                _kv(tr('الهاتف'), order.phone),
                if (order.address.isNotEmpty) _kv(tr('العنوان'), order.address),
                if (order.notes.isNotEmpty) _kv(tr('ملاحظة'), order.notes),
                const Divider(),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name +
                                (item.size.isNotEmpty ? ' · ${item.size}' : '') +
                                (item.color.isNotEmpty
                                    ? ' · ${item.color}'
                                    : ''),
                          ),
                        ),
                        Text('${item.quantity} × ${money(item.price)}'),
                      ],
                    ),
                  ),
                const Divider(),
                if (order.deliveryFee > 0)
                  _kv(tr('التوصيل'), money(order.deliveryFee)),
                _kv(tr('الإجمالي'), money(order.total), bold: true),
                if (order.deposit > 0) ...[
                  _kv(tr('العربون'), money(order.deposit)),
                  _kv(tr('الباقي'), money(order.remaining), bold: true),
                ],
              ],
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            )
          else
            OverflowBar(
              children: [
                if (order.phone.isNotEmpty) ...[
                  TextButton.icon(
                    onPressed: () => _launch('tel:${_digits(order.phone)}'),
                    icon: const Icon(Icons.phone, size: 18),
                    label: Text(tr('اتصال')),
                  ),
                  TextButton.icon(
                    onPressed: () => _launch('https://wa.me/${_intl(order.phone)}'),
                    icon: const Icon(Icons.chat, size: 18),
                    label: Text(tr('واتساب')),
                  ),
                ],
                TextButton.icon(
                  onPressed: _printLabel,
                  icon: const Icon(Icons.print, size: 18),
                  label: Text(tr('ملصق شحن')),
                ),
                ..._statusActions(),
                TextButton.icon(
                  onPressed: _delete,
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

  List<Widget> _statusActions() => switch (order.status) {
        OrderStatus.pending => [
            TextButton.icon(
              onPressed: _confirm,
              icon: const Icon(Icons.check_circle_outline,
                  size: 18, color: AppTheme.success),
              label: Text(tr('تأكيد وحجز'),
                  style: TextStyle(color: AppTheme.success)),
            ),
            TextButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.cancel_outlined,
                  size: 18, color: AppTheme.danger),
              label: Text(tr('إلغاء'),
                  style: TextStyle(color: AppTheme.danger)),
            ),
          ],
        OrderStatus.confirmed => [
            TextButton.icon(
              onPressed: _ship,
              icon: Icon(Icons.local_shipping_outlined,
                  size: 18, color: AppTheme.primary),
              label: Text(tr('شحن'),
                  style: TextStyle(color: AppTheme.primary)),
            ),
            TextButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.cancel_outlined,
                  size: 18, color: AppTheme.danger),
              label: Text(tr('إلغاء'),
                  style: TextStyle(color: AppTheme.danger)),
            ),
          ],
        OrderStatus.shipped => [
            TextButton.icon(
              onPressed: _deliver,
              icon: const Icon(Icons.done_all,
                  size: 18, color: AppTheme.success),
              label: Text(tr('تمّ التسليم'),
                  style: TextStyle(color: AppTheme.success)),
            ),
          ],
        _ => const [],
      };

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showOk(context, successMessage);
    } catch (e) {
      if (mounted) showErr(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() => _run(
        () => ref.read(ordersRepositoryProvider)!.confirm(order),
        tr('أُكِّد الطلب وحُجزت البضاعة'),
      );

  Future<void> _ship() => _run(
        () => ref.read(ordersRepositoryProvider)!.ship(order),
        tr('شُحن الطلب وخرجت البضاعة من المخزون'),
      );

  Future<void> _deliver() => _run(
        () => ref.read(ordersRepositoryProvider)!.markDelivered(order),
        tr('سُجّل التسليم'),
      );

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: tr('إلغاء الطلب'),
      message: order.status == OrderStatus.confirmed
          ? tr('سيُحرَّر المحجوز وتعود البضاعة متاحة للبيع.')
          : tr('سيُعلَّم الطلب كملغى.'),
      confirmLabel: tr('إلغاء الطلب'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(ordersRepositoryProvider)!.cancel(order),
      tr('أُلغي الطلب'),
    );
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف الطلب'),
      message: trf('سيُحذف الطلب {0} نهائياً.{1}', [order.orderNumber, order.status == OrderStatus.confirmed ? tr('\n\n⚠️ الطلب مؤكَّد — ألغِه أولاً لتحرير المحجوز.') : '']),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(ordersRepositoryProvider)!.delete(order.id),
      tr('حُذف الطلب'),
    );
  }

  Future<void> _printLabel() async {
    final data = OrderLabelData(
      orderNumber: order.orderNumber,
      customerName: order.customerName,
      phone: order.phone,
      wilaya: order.wilaya,
      address: order.address,
      notes: order.notes,
      items: [
        for (final item in order.items)
          OrderLabelItem(item.name, item.quantity, item.price),
      ],
      total: order.total,
      deposit: order.deposit,
      deliveryFee: order.deliveryFee,
    );

    final outcome = await ref
        .read(printServiceProvider)
        .printOrderLabel(data, orderId: order.id);
    if (!mounted) return;
    outcome.ok
        ? showOk(context, outcome.message)
        : showErr(context, outcome.message);
  }

  static String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(
                key,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
}

/// يفتح المتجر الإلكتروني في المتصفّح الخارجي.
///
/// يُكمل البادئة إن نسيها صاحب المحل: `assil.vercel.app` بلا `https://`
/// يُفسَّر مساراً نسبياً فلا يُفتح شيء ولا تظهر رسالة خطأ.
Future<void> _openStorefront(BuildContext context, String url) async {
  final normalized =
      url.startsWith('http://') || url.startsWith('https://') ? url : 'https://$url';
  final uri = Uri.tryParse(normalized);
  if (uri == null || !await canLaunchUrl(uri)) {
    if (context.mounted) {
      showErr(context, trf('تعذّر فتح العنوان: {0}', [url]));
    }
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
