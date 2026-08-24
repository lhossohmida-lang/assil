import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../providers/cart_provider.dart';
import 'pos_dialogs.dart';
import '../../../../core/i18n/app_strings.dart';

/// لوحة السلة.
///
/// ⚠️ **الفائدة لا تُعرض هنا إطلاقاً** — الشاشة مواجهة للزبونة، ولا يجوز
/// أن ترى هامش الربح على ما تشتريه.
class CartPanel extends ConsumerWidget {
  const CartPanel({
    super.key,
    required this.onPay,
    required this.onCredit,
    required this.onReservation,
    required this.onHold,
    required this.onShowHeld,
    required this.busy,
    this.showKeyboardHint = false,
  });

  final VoidCallback onPay;
  final VoidCallback onCredit;
  final VoidCallback onReservation;
  final VoidCallback onHold;
  final VoidCallback onShowHeld;
  final bool busy;
  final bool showKeyboardHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final totals = ref.watch(cartTotalsProvider);
    final notifier = ref.read(cartProvider.notifier);

    return Column(
      children: [
        _ActionsRow(
          onCredit: onCredit,
          onReservation: onReservation,
          onHold: onHold,
          onShowHeld: onShowHeld,
          enabled: cart.isNotEmpty && !busy,
        ),
        const Divider(height: 1),

        if (cart.customerName.isNotEmpty)
          _CustomerBanner(
            name: cart.customerName,
            isVip: cart.isVip,
            onClear: notifier.clearCustomer,
          ),

        Expanded(
          child: cart.isEmpty
              ? const _EmptyCart()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: cart.lines.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _CartLineTile(
                    line: cart.lines[i],
                    index: i,
                  ),
                ),
        ),

        const Divider(height: 1),
        _Totals(
          totals: totals,
          onEditDiscount: () async {
            final value = await showDiscountDialog(
              context,
              current: cart.discount,
              subtotal: totals.subtotal,
            );
            if (value != null) notifier.setDiscount(value);
          },
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: cart.isEmpty || busy ? null : onPay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.payments, size: 26),
                  label: Text(
                    cart.isEmpty ? tr('السلة فارغة') : trf('دفع  {0}', [money(totals.total)]),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              if (showKeyboardHint) ...[
                const SizedBox(height: 6),
                Text(
                  keyboardShortcutsHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.success.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.onCredit,
    required this.onReservation,
    required this.onHold,
    required this.onShowHeld,
    required this.enabled,
  });

  final VoidCallback onCredit;
  final VoidCallback onReservation;
  final VoidCallback onHold;
  final VoidCallback onShowHeld;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onCredit : null,
              icon: const Icon(Icons.credit_score, size: 18),
              label: Text(tr('كريدي')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onReservation : null,
              icon: const Icon(Icons.bookmark_added_outlined, size: 18),
              label: Text(tr('فارسمون')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            // ضغطة = تعليق السلة، ضغطة مطوّلة = عرض السلال المعلّقة.
            // `onLongPress` الخاص بالزرّ لا GestureDetector يلفّه: الزرّ
            // يملك ساحة الإيماءات فيبتلع الضغطة المطوّلة قبل أن تصل للأب.
            child: OutlinedButton.icon(
              onPressed: enabled ? onHold : onShowHeld,
              onLongPress: onShowHeld,
              icon: const Icon(Icons.pause_circle_outline, size: 18),
              label: Text(tr('انتظار')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerBanner extends StatelessWidget {
  const _CustomerBanner({
    required this.name,
    required this.isVip,
    required this.onClear,
  });

  final String name;
  final bool isVip;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: (isVip ? AppTheme.warning : AppTheme.primary)
          .withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            isVip ? Icons.star : Icons.person,
            size: 18,
            color: isVip ? AppTheme.warning : AppTheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isVip ? '$name — VIP' : name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: tr('إزالة'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.line, required this.index});

  final CartLine line;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                money(line.lineTotal),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.primary,
                ),
              ),
              IconButton(
                tooltip: tr('إزالة'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                onPressed: () => notifier.removeAt(index),
              ),
            ],
          ),
          Row(
            children: [
              // ─── الكمية ───
              _RoundButton(
                icon: Icons.remove,
                onTap: () => notifier.setQuantity(index, line.quantity - 1),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 34),
                alignment: Alignment.center,
                child: Text(
                  '${line.quantity}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _RoundButton(
                icon: Icons.add,
                onTap: () => notifier.setQuantity(index, line.quantity + 1),
              ),

              const SizedBox(width: 10),

              // ─── السعر مع ±100 ───
              _RoundButton(
                icon: Icons.remove,
                small: true,
                label: '100',
                onTap: () => notifier.bumpPrice(index, -100),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final price = await showPriceDialog(
                      context,
                      productName: line.product.name,
                      currentPrice: line.unitPrice,
                      originalPrice: line.product.sellPrice,
                    );
                    if (price != null) notifier.setPrice(index, price);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: line.priceChanged
                            ? AppTheme.warning
                            : AppTheme.cardBorder,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        money(line.unitPrice),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: line.priceChanged
                              ? AppTheme.warning
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              _RoundButton(
                icon: Icons.add,
                small: true,
                label: '100',
                onTap: () => notifier.bumpPrice(index, 100),
              ),
            ],
          ),
          if (line.quantity > line.product.availableQuantity)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                trf('المتوفّر {0} فقط', [line.product.availableQuantity]),
                style: const TextStyle(fontSize: 11, color: AppTheme.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.small = false,
    this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool small;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 5 : 6,
          vertical: small ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: small ? 14 : 18, color: AppTheme.primary),
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals, required this.onEditDiscount});

  final CartTotals totals;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          _row(tr('المجموع'), money(totals.subtotal)),
          if (totals.vipDiscount > 0)
            _row(tr('خصم VIP'), '- ${money(totals.vipDiscount)}',
                color: AppTheme.warning),
          InkWell(
            onTap: onEditDiscount,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(tr('تخفيض')),
                    SizedBox(width: 4),
                    Icon(Icons.edit, size: 13, color: AppTheme.textSecondary),
                  ],
                ),
                Text(
                  totals.discount > 0 ? '- ${money(totals.discount)}' : '—',
                  style: TextStyle(
                    color: totals.discount > 0
                        ? AppTheme.warning
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('الإجمالي'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(totals.total),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String key, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(key, style: TextStyle(color: color)),
            Text(value, style: TextStyle(color: color)),
          ],
        ),
      );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            tr('امسح الباركود أو اختر من المنتجات'),
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
