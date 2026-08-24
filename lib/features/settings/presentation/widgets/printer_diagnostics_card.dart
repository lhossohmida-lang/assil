import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../printing/data/windows_printer_ffi.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/services/ticket_service.dart';
import '../../../../core/i18n/app_strings.dart';

/// بطاقة تشخيص الطابعة — تكشف سبب الملصقات الفارغة بالأرقام لا بالتخمين.
class PrinterDiagnosticsCard extends ConsumerStatefulWidget {
  const PrinterDiagnosticsCard({super.key});

  @override
  ConsumerState<PrinterDiagnosticsCard> createState() =>
      _PrinterDiagnosticsCardState();
}

class _PrinterDiagnosticsCardState
    extends ConsumerState<PrinterDiagnosticsCard> {
  PaperMeasurement? _measured;
  PaperApplyResult? _applyResult;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  void _measure() {
    final name = ref.read(printSettingsProvider).ticket.printerName;
    setState(() => _measured = WindowsPrinterFfi.measure(name));
  }

  Future<void> _apply() async {
    final ticket = ref.read(printSettingsProvider).ticket;
    setState(() => _busy = true);

    final result = WindowsPrinterFfi.applyCustomPaper(
      printerName: ticket.printerName,
      widthMm: ticket.labelWidthMm,
      heightMm: ticket.effectivePitchMm,
    );

    if (!mounted) return;
    setState(() {
      _applyResult = result;
      _measured = result.after ?? WindowsPrinterFfi.measure(ticket.printerName);
      _busy = false;
    });

    if (result.applied) {
      showOk(context, trf('ضُبط ورق الدرايفر — {0}', [result.message]));
    } else {
      showErr(context, result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(printSettingsProvider).ticket;

    if (!WindowsPrinterFfi.isAvailable) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text(tr('تشخيص الطابعة')),
          subtitle: Text(tr('متاح على ويندوز فقط.')),
        ),
      );
    }

    final measured = _measured;
    final labelHeight = ticket.effectivePitchMm;

    // كم ملصقاً يُهدر لكل طباعة = فورم الدرايفر ÷ خطوة الملصق.
    final waste = (measured == null || labelHeight <= 0)
        ? null
        : (measured.heightMm / labelHeight);

    final ok = measured != null &&
        (measured.widthMm - ticket.labelWidthMm).abs() <= 0.6 &&
        (measured.heightMm - labelHeight).abs() <= 0.6;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ok ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: ok ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('تشخيص ورق الطابعة'),
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  tooltip: tr('إعادة القياس'),
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _measure,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr('الطابعة تتقدّم بمقدار الفورم المضبوط في درايفرها، لا بمقدار الصفحة المرسلة. لو كان فورمها أكبر من الملصق خرجت ملصقات فارغة مع كل تيكت.'),
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            const Divider(height: 20),

            _row(tr('الطابعة'),
                ticket.printerName.isEmpty ? tr('— لم تُختر —') : ticket.printerName),
            _row(
              tr('الملصق المطلوب'),
              trf('{0} × {1} مم', [ticket.labelWidthMm.toStringAsFixed(1), labelHeight.toStringAsFixed(1)]),
            ),
            _row(
              tr('فورم الدرايفر الفعلي'),
              measured?.toString() ?? tr('تعذّر القياس'),
              color: ok ? AppTheme.success : AppTheme.danger,
            ),
            if (waste != null)
              _row(
                tr('ملصقات لكل طباعة'),
                waste.toStringAsFixed(2),
                color: waste > 1.15 ? AppTheme.danger : AppTheme.success,
                hint: waste > 1.15
                    ? trf('يُهدر نحو {0} ملصق مع كل تيكت', [(waste - 1).toStringAsFixed(2)])
                    : tr('لا هدر'),
              ),

            if (_applyResult != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_applyResult!.applied
                          ? AppTheme.success
                          : AppTheme.danger)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _applyResult!.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: _applyResult!.applied
                        ? AppTheme.success
                        : AppTheme.danger,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy || ticket.printerName.isEmpty ? null : _apply,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.build),
              label: Text(tr('اضبط ورق الدرايفر ثم قِس النتيجة')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String key, String value, {Color? color, String? hint}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                key,
                style: TextStyle(
                    fontSize: 12.5, color: AppTheme.textSecondary),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    textAlign: TextAlign.end,
                  ),
                  if (hint != null)
                    Text(
                      hint,
                      style: TextStyle(fontSize: 10.5, color: color),
                      textAlign: TextAlign.end,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}

/// بطاقة وضوح الباركود — تُظهر سماكة الخط لكل طول رقم بالألوان.
class BarcodeClarityCard extends ConsumerWidget {
  const BarcodeClarityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(printSettingsProvider).ticket;
    final available = ticket.labelWidthMm - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('وضوح الباركود'),
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              trf('على ملصق {0}مم بدقّة {1}dpi. أرفع خط في الرمز يجب أن يكون **3 نقاط فأكثر** ليُقرأ من مسافة وبإضاءة ضعيفة.', [ticket.labelWidthMm.toStringAsFixed(0), ticket.dpi]),
              style: TextStyle(
                  fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            const Divider(height: 18),
            for (final length in [6, 8, 10, 12, 13])
              _ClarityRow(
                length: length,
                availableWidthMm: available,
                dpi: ticket.dpi,
                isDefault: length == 8,
              ),
            const SizedBox(height: 8),
            Text(
              tr('لهذا يولّد التطبيق أرقاماً من 8 خانات: الطول الفردي (13) يُجبر Code128 على تبديل مجموعة المحارف فيضيف نحو 22 وحدة، فيضيق عرض الوحدة إلى نقطتين ولا يُقرأ الرمز.'),
              style: TextStyle(
                  fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClarityRow extends StatelessWidget {
  const _ClarityRow({
    required this.length,
    required this.availableWidthMm,
    required this.dpi,
    required this.isDefault,
  });

  final int length;
  final double availableWidthMm;
  final int dpi;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final sample = List.filled(length, '1').join();
    final metrics = computeBarcodeMetrics(
      data: sample,
      availableWidthMm: availableWidthMm,
      dpi: dpi,
    );

    final color = metrics.dotsPerModule >= 3
        ? AppTheme.success
        : (metrics.dotsPerModule == 2 ? AppTheme.warning : AppTheme.danger);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Row(
              children: [
                Text(
                  trf('{0} أرقام', [length]),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (isDefault)
                  Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(Icons.star, size: 12, color: AppTheme.primary),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: (metrics.dotsPerModule / 5).clamp(0.05, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              trf('{0} نقطة · {1}', [metrics.dotsPerModule, metrics.qualityLabel]),
              style: TextStyle(
                fontSize: 11.5,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
