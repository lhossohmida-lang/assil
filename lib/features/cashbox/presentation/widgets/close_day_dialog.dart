import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/i18n/app_strings.dart';

/// إغلاق الصندوق.
///
/// حقلان مربوطان: **كم سحبت** و**كم يبقى للغد**. كتابة أحدهما تحسب الآخر
/// فوراً، لأن صاحب المحل أحياناً يعدّ ما أخذه في يده وأحياناً يعدّ ما تركه
/// في الدرج — وإجباره على الطرح ذهنياً مصدر أخطاء في آخر اليوم.
///
/// تُرجع **المبلغ المتروك للغد** (وهو ما تنتظره `closeDay`).
Future<double?> showCloseDayDialog(
  BuildContext context, {
  required double balance,
}) async {
  final withdrawnCtrl = TextEditingController(text: moneyPlain(balance));
  final keepCtrl = TextEditingController(text: '0');

  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        double clampAmount(double v) => v.clamp(0, balance).toDouble();

        final withdrawn = clampAmount(toDouble(withdrawnCtrl.text));
        final keep = clampAmount(balance - withdrawn);

        void fromWithdrawn(String _) {
          final w = clampAmount(toDouble(withdrawnCtrl.text));
          keepCtrl.text = moneyPlain(balance - w);
          setState(() {});
        }

        void fromKeep(String _) {
          final k = clampAmount(toDouble(keepCtrl.text));
          withdrawnCtrl.text = moneyPlain(balance - k);
          setState(() {});
        }

        void preset(double amount) {
          withdrawnCtrl.text = moneyPlain(clampAmount(amount));
          fromWithdrawn('');
        }

        return AlertDialog(
          title: Text(tr('إغلاق الصندوق')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.point_of_sale,
                            color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tr('رصيد الصندوق الآن'))),
                        Text(
                          money(balance),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  MoneyField(
                    controller: withdrawnCtrl,
                    label: tr('كم سحبت؟'),
                    autofocus: true,
                    onChanged: fromWithdrawn,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      ActionChip(
                        label: Text(tr('كل الرصيد')),
                        onPressed: () => preset(balance),
                      ),
                      ActionChip(
                        label: Text(tr('النصف')),
                        onPressed: () => preset(balance / 2),
                      ),
                      ActionChip(
                        label: Text(tr('لا شيء')),
                        onPressed: () => preset(0),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Center(
                    child: Icon(
                      Icons.swap_vert,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 8),

                  MoneyField(
                    controller: keepCtrl,
                    label: tr('كم يبقى في الصندوق للغد؟'),
                    onChanged: fromKeep,
                  ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _row(tr('يُسحب أرباحاً'), money(withdrawn), bold: true),
                        _row(tr('يبقى في الدرج'), money(keep)),
                        const SizedBox(height: 6),
                        Text(
                          tr('سحب الأرباح يُسجَّل نوعاً مستقلاً — لا يُحسب مصروفاً ولا يُنقص «الفائدة بعد المصاريف».'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('بعد الإغلاق تبدأ فترة «اليوم» من هذه اللحظة، فتعود كل الأرقام صفراً فوراً.'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(keep),
              child: Text(tr('إغلاق الصندوق')),
            ),
          ],
        );
      },
    ),
  );

  withdrawnCtrl.dispose();
  keepCtrl.dispose();
  return result;
}

Widget _row(String key, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 17 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? AppTheme.primary : null,
            ),
          ),
        ],
      ),
    );
