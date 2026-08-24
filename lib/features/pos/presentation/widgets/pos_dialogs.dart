import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/models/reservation.dart';
import '../providers/pos_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// نتيجة بطاقة الزبونة في نافذة الدفع.
class CustomerChoice {
  const CustomerChoice(this.name, this.isVip);
  final String name;
  final bool isVip;
}

class CreditChoice {
  const CreditChoice(this.name, this.phone, this.paid);
  final String name;
  final String phone;
  final double paid;
}

class ReservationChoice {
  const ReservationChoice(this.name, this.phone, this.deposit, this.note);
  final String name;
  final String phone;
  final double deposit;
  final String note;
}

class HoldChoice {
  const HoldChoice(this.name, this.note);
  final String name;
  final String note;
}

/// تعديل سعر سطر بإدخال حرّ.
Future<double?> showPriceDialog(
  BuildContext context, {
  required String productName,
  required double currentPrice,
  required double originalPrice,
}) async {
  final controller = TextEditingController(text: moneyPlain(currentPrice));
  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('تعديل السعر')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(productName, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            trf('السعر الأصلي: {0}', [money(originalPrice)]),
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          MoneyField(
            controller: controller,
            label: tr('السعر الجديد'),
            autofocus: true,
            onSubmitted: (v) => Navigator.of(ctx).pop(toDouble(v)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final step in [-500, -100, 100, 500])
                ActionChip(
                  label: Text(step > 0 ? '+$step' : '$step'),
                  onPressed: () => controller.text =
                      moneyPlain(toDouble(controller.text) + step),
                ),
              ActionChip(
                label: Text(tr('الأصلي')),
                onPressed: () => controller.text = moneyPlain(originalPrice),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(toDouble(controller.text)),
          child: Text(tr('تطبيق')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// تخفيض على السلة كاملة (مبلغ).
Future<double?> showDiscountDialog(
  BuildContext context, {
  required double current,
  required double subtotal,
}) async {
  final controller =
      TextEditingController(text: current > 0 ? moneyPlain(current) : '');
  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('تخفيض على السلة')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            trf('مجموع السلة: {0}', [money(subtotal)]),
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          MoneyField(
            controller: controller,
            label: tr('مبلغ التخفيض'),
            autofocus: true,
            onSubmitted: (v) => Navigator.of(ctx).pop(toDouble(v)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final percent in [5, 10, 15, 20])
                ActionChip(
                  label: Text(trf('{0}٪', [percent])),
                  onPressed: () => controller.text =
                      moneyPlain(subtotal * percent / 100),
                ),
              ActionChip(
                label: Text(tr('بلا تخفيض')),
                onPressed: () => controller.text = '0',
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(toDouble(controller.text)),
          child: Text(tr('تطبيق')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// بطاقة الزبونة الاختيارية عند الدفع النقدي.
Future<CustomerChoice?> showCustomerDialog(
  BuildContext context, {
  required String initialName,
  required bool initialVip,
  required double vipPercent,
}) async {
  final controller = TextEditingController(text: initialName);
  var isVip = initialVip;

  final result = await showDialog<CustomerChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(tr('الزبونة (اختياري)')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr('اسم الزبونة'),
                prefixIcon: Icon(Icons.person_outline),
              ),
              onSubmitted: (_) => Navigator.of(ctx)
                  .pop(CustomerChoice(controller.text.trim(), isVip)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: isVip,
              onChanged: (v) => setState(() => isVip = v),
              title: Text(tr('زبونة VIP')),
              subtitle: Text(trf('خصم {0}٪ تلقائي', [vipPercent.toStringAsFixed(0)])),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(const CustomerChoice('', false)),
            child: Text(tr('بلا اسم')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx)
                .pop(CustomerChoice(controller.text.trim(), isVip)),
            child: Text(tr('متابعة')),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

/// بيع كريدي: المبلغ المدفوع الآن والباقي دين.
Future<CreditChoice?> showCreditDialog(
  BuildContext context, {
  required double total,
  String initialName = '',
}) async {
  final nameCtrl = TextEditingController(text: initialName);
  final phoneCtrl = TextEditingController();
  final paidCtrl = TextEditingController(text: '0');
  var paid = 0.0;

  final result = await showDialog<CreditChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final remaining = (total - paid).clamp(0, double.infinity);
        return AlertDialog(
          title: Text(tr('بيع كريدي')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('اسم الزبونة *'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: tr('الهاتف'),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                MoneyField(
                  controller: paidCtrl,
                  label: tr('المدفوع الآن'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: Text(tr('لا شيء')),
                      onPressed: () => setState(() {
                        paidCtrl.text = '0';
                        paid = 0;
                      }),
                    ),
                    ActionChip(
                      label: Text(tr('النصف')),
                      onPressed: () => setState(() {
                        paidCtrl.text = moneyPlain(total / 2);
                        paid = total / 2;
                      }),
                    ),
                    ActionChip(
                      label: Text(tr('تحديث')),
                      onPressed: () =>
                          setState(() => paid = toDouble(paidCtrl.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _kv(tr('إجمالي الفاتورة'), money(total)),
                      _kv(tr('المدفوع الآن'), money(paid)),
                      const Divider(),
                      _kv(
                        tr('الباقي (دين)'),
                        money(remaining.toDouble()),
                        bold: true,
                        color: AppTheme.danger,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  showErr(ctx, tr('اسم الزبونة مطلوب في البيع بالكريدي'));
                  return;
                }
                Navigator.of(ctx).pop(CreditChoice(
                  nameCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                  toDouble(paidCtrl.text),
                ));
              },
              child: Text(tr('تسجيل الكريدي')),
            ),
          ],
        );
      },
    ),
  );

  nameCtrl.dispose();
  phoneCtrl.dispose();
  paidCtrl.dispose();
  return result;
}

/// حجز بعربون (فارسمون).
Future<ReservationChoice?> showReservationDialog(
  BuildContext context, {
  required double total,
  String initialName = '',
}) async {
  final nameCtrl = TextEditingController(text: initialName);
  final phoneCtrl = TextEditingController();
  final depositCtrl = TextEditingController(text: '0');
  final noteCtrl = TextEditingController();
  var deposit = 0.0;

  final result = await showDialog<ReservationChoice>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final remaining = (total - deposit).clamp(0, double.infinity);
        return AlertDialog(
          title: Text(tr('فارسمون (حجز)')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: tr('اسم الزبونة *'),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: tr('الهاتف'),
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                MoneyField(controller: depositCtrl, label: tr('العربون')),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final percent in [25, 50])
                      ActionChip(
                        label: Text(trf('{0}٪', [percent])),
                        onPressed: () => setState(() {
                          depositCtrl.text = moneyPlain(total * percent / 100);
                          deposit = total * percent / 100;
                        }),
                      ),
                    ActionChip(
                      label: Text(tr('تحديث')),
                      onPressed: () =>
                          setState(() => deposit = toDouble(depositCtrl.text)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(labelText: tr('ملاحظة')),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _kv(tr('إجمالي الحجز'), money(total)),
                      _kv(tr('العربون'), money(deposit)),
                      const Divider(),
                      _kv(
                        tr('الباقي عند الاستلام'),
                        money(remaining.toDouble()),
                        bold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('البضاعة تخرج من المخزون فوراً وتعود إليه إن أُلغي الحجز.'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) {
                  showErr(ctx, tr('اسم الزبونة مطلوب في الحجز'));
                  return;
                }
                Navigator.of(ctx).pop(ReservationChoice(
                  nameCtrl.text.trim(),
                  phoneCtrl.text.trim(),
                  toDouble(depositCtrl.text),
                  noteCtrl.text.trim(),
                ));
              },
              child: Text(tr('تسجيل الحجز')),
            ),
          ],
        );
      },
    ),
  );

  nameCtrl.dispose();
  phoneCtrl.dispose();
  depositCtrl.dispose();
  noteCtrl.dispose();
  return result;
}

/// تعليق السلة باسم وملاحظة.
Future<HoldChoice?> showHoldDialog(BuildContext context) async {
  final nameCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  final result = await showDialog<HoldChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('تعليق السلة')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: tr('اسم مميّز'),
              hintText: tr('مثلاً: الزبونة ذات المعطف الأحمر'),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(labelText: tr('ملاحظة')),
            onSubmitted: (_) => Navigator.of(ctx).pop(
              HoldChoice(nameCtrl.text.trim(), noteCtrl.text.trim()),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(
            HoldChoice(nameCtrl.text.trim(), noteCtrl.text.trim()),
          ),
          child: Text(tr('تعليق')),
        ),
      ],
    ),
  );

  nameCtrl.dispose();
  noteCtrl.dispose();
  return result;
}

/// قائمة السلال المعلّقة **مع بحث** بالاسم أو الملاحظة أو اسم منتج داخلها.
Future<HeldCart?> showHeldCartsSheet(BuildContext context) =>
    showModalBottomSheet<HeldCart>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _HeldCartsSheet(),
    );

class _HeldCartsSheet extends ConsumerStatefulWidget {
  const _HeldCartsSheet();

  @override
  ConsumerState<_HeldCartsSheet> createState() => _HeldCartsSheetState();
}

class _HeldCartsSheetState extends ConsumerState<_HeldCartsSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(heldCartsProvider).value ?? const <HeldCart>[];
    final filtered =
        _query.trim().isEmpty ? all : all.where((c) => c.matches(_query)).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
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
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.pause_circle_outline),
                const SizedBox(width: 8),
                Text(
                  trf('السلال المعلّقة ({0})', [all.length]),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: AppSearchField(
              controller: _searchCtrl,
              hint: tr('ابحث بالاسم أو الملاحظة أو المنتج'),
              resultCount: filtered.length,
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: all.isEmpty
                ? EmptyState(
                    icon: Icons.pause_circle_outline,
                    message: tr('لا توجد سلال معلّقة'),
                  )
                : filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        message: trf('لا نتائج لـ «{0}»', [_query]),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final cart = filtered[i];
                          return Card(
                            child: ListTile(
                              title: Text(
                                cart.name.isEmpty ? tr('بلا اسم') : cart.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cart.productsTitle),
                                  if (cart.note.isNotEmpty)
                                    Text(
                                      cart.note,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  Text(
                                    trf('{0} قطعة · {1} · {2}', [cart.pieceCount, money(cart.total), formatDateTime(cart.createdAt)]),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                tooltip: tr('حذف'),
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.danger),
                                onPressed: () async {
                                  await ref
                                      .read(posRepositoryProvider)
                                      ?.removeHeldCart(cart.id);
                                },
                              ),
                              onTap: () => Navigator.of(context).pop(cart),
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

Widget _kv(String key, String value, {bool bold = false, Color? color}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(color: color)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
              fontSize: bold ? 16 : 14,
            ),
          ),
        ],
      ),
    );

/// نصّ تذكير الاختصارات على الحاسوب.
final String keyboardShortcutsHint =
    tr('Enter = بيع فوري بلا طباعة  ·  Space = بيع فوري مع الطباعة');
