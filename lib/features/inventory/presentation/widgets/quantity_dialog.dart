import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/services/ticket_service.dart';
import '../../domain/models/product.dart';
import '../providers/inventory_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// نافذة تعديل كمية سريعة: ± أو كتابة الكمية الجديدة مباشرة.
Future<void> showQuantityDialog(
  BuildContext context,
  WidgetRef ref,
  Product product,
) async {
  final controller = TextEditingController(text: '${product.quantity}');
  var value = product.quantity;

  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void setValue(int next) {
          value = next < 0 ? 0 : next;
          controller.text = '$value';
          setState(() {});
        }

        return AlertDialog(
          title: Text(product.name, maxLines: 2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trf('الكمية الحالية: {0}', [product.quantity]),
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    iconSize: 30,
                    icon: const Icon(Icons.remove),
                    onPressed: () => setValue(value - 1),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (v) => value = toInt(v),
                    ),
                  ),
                  IconButton.filledTonal(
                    iconSize: 30,
                    icon: const Icon(Icons.add),
                    onPressed: () => setValue(value + 1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final step in [-10, -5, 5, 10, 25, 50])
                    ActionChip(
                      label: Text(step > 0 ? '+$step' : '$step'),
                      onPressed: () => setValue(value + step),
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
              onPressed: () => Navigator.of(ctx).pop(value),
              child: Text(tr('حفظ')),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  if (result == null || result == product.quantity) return;

  final repo = ref.read(inventoryRepositoryProvider);
  if (repo == null) return;
  try {
    await repo.setQuantity(product, result);
    if (context.mounted) showOk(context, trf('الكمية الآن {0}', [result]));
  } catch (e) {
    if (context.mounted) showErr(context, '$e');
  }
}

/// نافذة عدد نسخ التيكت، مع تشخيص وضوح الباركود قبل الطباعة.
Future<int?> showTicketCopiesDialog(
  BuildContext context,
  Product product,
) async {
  var copies = 1;
  final controller = TextEditingController(text: '1');

  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void setCopies(int v) {
          copies = v.clamp(1, 200);
          controller.text = '$copies';
          setState(() {});
        }

        return AlertDialog(
          title: Text(tr('طباعة تيكت')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(product.name, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 4),
              Text(
                product.barcode.isEmpty ? tr('بلا باركود') : product.barcode,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              if (product.barcode.isNotEmpty)
                _ReadabilityHint(barcode: product.barcode),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove),
                    onPressed: () => setCopies(copies - 1),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: controller,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      onChanged: (v) => copies = toInt(v).clamp(1, 200),
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add),
                    onPressed: () => setCopies(copies + 1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  for (final n in [1, 5, 10, 20, 50])
                    ActionChip(
                      label: Text('$n'),
                      onPressed: () => setCopies(n),
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
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(copies),
              icon: const Icon(Icons.print),
              label: Text(tr('طباعة')),
            ),
          ],
        );
      },
    ),
  );

  controller.dispose();
  return result;
}

/// تشخيص وضوح الباركود قبل إهدار الملصقات.
class _ReadabilityHint extends ConsumerWidget {
  const _ReadabilityHint({required this.barcode});
  final String barcode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // نستعمل الإعدادات الفعلية للجهاز حتى يكون التشخيص صادقاً.
    final settings = ref.watch(printSettingsProvider).ticket;
    final metrics = computeBarcodeMetrics(
      data: barcode,
      availableWidthMm: settings.labelWidthMm - 1,
      dpi: settings.dpi,
    );

    final color = metrics.isReadable
        ? AppTheme.success
        : (metrics.isMarginal ? AppTheme.warning : AppTheme.danger);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            metrics.isReadable ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trf('وضوح الباركود: {0} — {1} نقطة لأرفع خط ({2} وحدة على {3}مم)', [metrics.qualityLabel, metrics.dotsPerModule, metrics.modules, metrics.widthMm.toStringAsFixed(1)]),
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
