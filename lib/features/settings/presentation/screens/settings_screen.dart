import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../printing/presentation/providers/printing_providers.dart';
import '../../../printing/services/order_label_service.dart';
import '../../../printing/services/print_service.dart';
import '../../../printing/services/receipt_service.dart';
import '../../../printing/services/ticket_service.dart';
import '../providers/settings_providers.dart';
import '../widgets/print_preview.dart';
import '../widgets/printer_diagnostics_card.dart';
import '../widgets/receipt_content_editor.dart';
import '../widgets/settings_sections.dart';
import '../../../../core/i18n/app_strings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      route: AppRoutes.settings,
      title: tr('الإعدادات'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          _SecuritySection(),
          SizedBox(height: 8),
          _StoreSection(),
          SizedBox(height: 8),
          AppearanceSection(),
          SizedBox(height: 8),
          CatalogListsSection(),
          SizedBox(height: 8),
          SocialSection(),
          SizedBox(height: 8),
          _PrintingSection(),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ───────────────────────── الأمان ─────────────────────────

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider).value;
    final hasPin = settings?.hasPin ?? false;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              hasPin ? Icons.lock : Icons.lock_open,
              color: hasPin ? AppTheme.success : AppTheme.warning,
            ),
            title: Text(tr('الرقم السرّي')),
            subtitle: Text(
              hasPin
                  ? tr('مضبوط — يقفل كل الأقسام عدا نقطة البيع')
                  : tr('غير مضبوط — كل الأقسام مفتوحة للجميع'),
            ),
            trailing: TextButton(
              onPressed: () => _setPin(context, ref, hasPin),
              child: Text(hasPin ? tr('تغيير') : tr('ضبط')),
            ),
          ),
          if (hasPin)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(tr('إقفال كل الأقسام الآن')),
              subtitle: Text(tr('يُطلب الرقم السرّي من جديد لكل قسم')),
              onTap: () {
                ref.read(unlockedSectionsProvider.notifier).lockAll();
                showOk(context, tr('أُقفلت كل الأقسام'));
              },
            ),
        ],
      ),
    );
  }

  Future<void> _setPin(
    BuildContext context,
    WidgetRef ref,
    bool hasPin,
  ) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasPin ? tr('تغيير الرقم السرّي') : tr('ضبط رقم سرّي')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: pinCtrl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(labelText: tr('الرقم الجديد')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(labelText: tr('تأكيد الرقم')),
              onSubmitted: (_) => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('حفظ')),
          ),
        ],
      ),
    );

    final pin = pinCtrl.text.trim();
    final confirm = confirmCtrl.text.trim();
    pinCtrl.dispose();
    confirmCtrl.dispose();

    if (ok != true || !context.mounted) return;
    if (pin.length < 4) {
      showErr(context, tr('الرقم السرّي 4 أرقام على الأقل'));
      return;
    }
    if (pin != confirm) {
      showErr(context, tr('الرقمان غير متطابقين'));
      return;
    }

    try {
      await ref.read(settingsRepositoryProvider)!.setPin(pin);
      if (context.mounted) showOk(context, tr('حُفظ الرقم السرّي'));
    } catch (e) {
      if (context.mounted) showErr(context, '$e');
    }
  }
}

// ───────────────────────── المتجر ─────────────────────────

class _StoreSection extends ConsumerStatefulWidget {
  const _StoreSection();

  @override
  ConsumerState<_StoreSection> createState() => _StoreSectionState();
}

class _StoreSectionState extends ConsumerState<_StoreSection> {
  final _vipCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _vipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeSettingsProvider).value;
    if (settings != null && !_initialized) {
      _vipCtrl.text = settings.vipDiscountPercent.toStringAsFixed(0);
      _initialized = true;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: AppTheme.primary),
                SizedBox(width: 8),
                Text(
                  tr('المتجر'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('اسم المحل على المطبوعات')),
              subtitle: Text(
                tr('يُغيَّر من AppConstants.storeDisplayName في الكود'),
              ),
              trailing: Text(
                AppConstants.storeDisplayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vipCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: tr('نسبة خصم زبونة VIP'),
                      suffixText: '٪',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final value = toDouble(_vipCtrl.text).clamp(0, 90);
                    await ref
                        .read(settingsRepositoryProvider)!
                        .setVipDiscount(value.toDouble());
                    if (context.mounted) {
                      showOk(context, trf('خصم VIP الآن {0}٪', [value.toInt()]));
                    }
                  },
                  child: Text(tr('حفظ')),
                ),
              ],
            ),
            if (!AppConstants.isCloudinaryConfigured) ...[
              const Divider(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image_not_supported_outlined,
                        color: AppTheme.warning, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tr('رفع صور المنتجات غير مهيّأ: املأ cloudinaryCloudName و cloudinaryUploadPreset في app_constants.dart'),
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── الطباعة ─────────────────────────

class _PrintingSection extends ConsumerStatefulWidget {
  const _PrintingSection();

  @override
  ConsumerState<_PrintingSection> createState() => _PrintingSectionState();
}

class _PrintingSectionState extends ConsumerState<_PrintingSection> {
  List<Printer> _printers = const [];
  bool _loadingPrinters = true;

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      if (mounted) {
        setState(() {
          _printers = printers;
          _loadingPrinters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(printSettingsProvider);
    final notifier = ref.read(printSettingsProvider.notifier);

    return Column(
      children: [
        if (!PrintService.canPrintLocally)
          Card(
            color: Color(0xFFE8F5E9),
            child: ListTile(
              leading: Icon(Icons.phone_android, color: AppTheme.success),
              title: Text(tr('الطباعة عن بُعد')),
              subtitle: Text(
                tr('هذا جهاز محمول: أوامر الطباعة تُرسَل إلى حاسوب المحل ليطبعها على طابعته بإعداداته.'),
              ),
            ),
          ),

        // ─── الوصل ───
        _PrintCard(
          title: tr('وصل البيع'),
          icon: Icons.receipt_long,
          printers: _printers,
          loadingPrinters: _loadingPrinters,
          selectedPrinter: settings.receipt.printerName,
          onPrinterChanged: (name) => notifier.updateReceipt(
            settings.receipt.copyWith(printerName: name),
          ),
          fields: [
            _NumField(
              label: tr('عرض البكرة (مم)'),
              value: settings.receipt.widthMm,
              onChanged: (v) => notifier.updateReceipt(
                settings.receipt.copyWith(widthMm: v),
              ),
            ),
            _NumField(
              label: tr('الهامش (مم)'),
              value: settings.receipt.marginMm,
              onChanged: (v) => notifier.updateReceipt(
                settings.receipt.copyWith(marginMm: v),
              ),
            ),
            _NumField(
              label: tr('تغذية بعد القصّ (مم)'),
              value: settings.receipt.extraFeedMm,
              onChanged: (v) => notifier.updateReceipt(
                settings.receipt.copyWith(extraFeedMm: v),
              ),
            ),
            _NumField(
              label: tr('مقياس الخط'),
              value: settings.receipt.fontScale,
              step: 0.1,
              onChanged: (v) => notifier.updateReceipt(
                settings.receipt.copyWith(fontScale: v),
              ),
            ),
          ],
          extra: const ReceiptContentEditor(),
          preview: PrintPreview(
            label: tr('معاينة الوصل'),
            signature: jsonEncode(settings.receipt.toMap()),
            build: () => ReceiptService.build(
              sale: PrintSamples.sale,
              settings: settings.receipt,
              branding: ref.read(receiptBrandingProvider),
            ),
          ),
          onTestPrint: () => _test(
            () => ref.read(printServiceProvider).printReceipt(PrintSamples.sale),
          ),
        ),

        // ─── التيكت ───
        _PrintCard(
          title: tr('تيكت الباركود'),
          icon: Icons.local_offer,
          printers: _printers,
          loadingPrinters: _loadingPrinters,
          selectedPrinter: settings.ticket.printerName,
          onPrinterChanged: (name) => notifier.updateTicket(
            settings.ticket.copyWith(printerName: name),
          ),
          fields: [
            _NumField(
              label: tr('عرض الملصق (مم)'),
              value: settings.ticket.labelWidthMm,
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(labelWidthMm: v),
              ),
            ),
            _NumField(
              label: tr('ارتفاع الملصق (مم)'),
              value: settings.ticket.labelHeightMm,
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(labelHeightMm: v),
              ),
            ),
            _NumField(
              label: tr('الخطوة بين ملصقين (مم)'),
              value: settings.ticket.pitchMm,
              helper: tr('الملصق + الفجوة. صفر = مثل الارتفاع'),
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(pitchMm: v),
              ),
            ),
            _NumField(
              label: tr('دقّة الطابعة (dpi)'),
              value: settings.ticket.dpi.toDouble(),
              step: 1,
              helper: tr('يُحسب بها عرض الباركود'),
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(dpi: v.round()),
              ),
            ),
            _NumField(
              label: tr('إزاحة أفقية (مم)'),
              value: settings.ticket.offsetXMm,
              step: 0.5,
              allowNegative: true,
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(offsetXMm: v),
              ),
            ),
            _NumField(
              label: tr('إزاحة عمودية (مم)'),
              value: settings.ticket.offsetYMm,
              step: 0.5,
              allowNegative: true,
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(offsetYMm: v),
              ),
            ),
            _NumField(
              label: tr('مقياس الخط'),
              value: settings.ticket.fontScale,
              step: 0.1,
              onChanged: (v) => notifier.updateTicket(
                settings.ticket.copyWith(fontScale: v),
              ),
            ),
          ],
          switches: [
            (tr('اسم المحل'), settings.ticket.showStoreName, (bool v) =>
                notifier.updateTicket(
                    settings.ticket.copyWith(showStoreName: v))),
            (tr('السعر'), settings.ticket.showPrice, (bool v) =>
                notifier.updateTicket(settings.ticket.copyWith(showPrice: v))),
            (tr('رقم الباركود'), settings.ticket.showBarcodeText, (bool v) =>
                notifier.updateTicket(
                    settings.ticket.copyWith(showBarcodeText: v))),
            (tr('إطار معايرة'), settings.ticket.drawCalibrationFrame, (bool v) =>
                notifier.updateTicket(
                    settings.ticket.copyWith(drawCalibrationFrame: v))),
            (
              tr('ضبط ورق الدرايفر قبل الطباعة'),
              settings.ticket.applyDriverPaperSize,
              (bool v) => notifier.updateTicket(
                  settings.ticket.copyWith(applyDriverPaperSize: v))
            ),
          ],
          preview: PrintPreview(
            label: tr('معاينة التيكت'),
            maxHeight: 180,
            signature: jsonEncode(settings.ticket.toMap()),
            build: () => TicketService.build(
              product: PrintSamples.product,
              settings: settings.ticket,
            ),
          ),
          onTestPrint: () => _test(
            () => ref
                .read(printServiceProvider)
                .printTicket(PrintSamples.product),
          ),
        ),

        const PrinterDiagnosticsCard(),
        const BarcodeClarityCard(),

        // ─── ملصق الشحن ───
        _PrintCard(
          title: tr('ملصق الشحن'),
          icon: Icons.local_shipping,
          printers: _printers,
          loadingPrinters: _loadingPrinters,
          selectedPrinter: settings.orderLabel.printerName,
          onPrinterChanged: (name) => notifier.updateOrderLabel(
            settings.orderLabel.copyWith(printerName: name),
          ),
          fields: [
            _NumField(
              label: tr('العرض (مم)'),
              value: settings.orderLabel.widthMm,
              onChanged: (v) => notifier.updateOrderLabel(
                settings.orderLabel.copyWith(widthMm: v),
              ),
            ),
            _NumField(
              label: tr('الارتفاع (مم)'),
              value: settings.orderLabel.heightMm,
              onChanged: (v) => notifier.updateOrderLabel(
                settings.orderLabel.copyWith(heightMm: v),
              ),
            ),
            _NumField(
              label: tr('الهامش (مم)'),
              value: settings.orderLabel.marginMm,
              onChanged: (v) => notifier.updateOrderLabel(
                settings.orderLabel.copyWith(marginMm: v),
              ),
            ),
            _NumField(
              label: tr('مقياس الخط'),
              value: settings.orderLabel.fontScale,
              step: 0.1,
              onChanged: (v) => notifier.updateOrderLabel(
                settings.orderLabel.copyWith(fontScale: v),
              ),
            ),
          ],
          preview: PrintPreview(
            label: tr('معاينة الملصق'),
            signature: jsonEncode(settings.orderLabel.toMap()),
            build: () => OrderLabelService.build(
              data: _sampleOrder,
              settings: settings.orderLabel,
            ),
          ),
          onTestPrint: () => _test(
            () => ref.read(printServiceProvider).printOrderLabel(_sampleOrder),
          ),
        ),
      ],
    );
  }

  static final OrderLabelData _sampleOrder = OrderLabelData(
    orderNumber: 'KM-2026-001',
    customerName: tr('زبونة تجريبية'),
    phone: '0555 12 34 56',
    wilaya: tr('الجزائر'),
    address: tr('حي النصر، عمارة 5'),
    items: [
      OrderLabelItem(tr('قميص قطن أبيض'), 2, 1800),
      OrderLabelItem(tr('بنطال جينز'), 1, 3500),
    ],
    total: 7100,
    deposit: 2000,
    deliveryFee: 400,
  );

  Future<void> _test(Future<PrintOutcome> Function() action) async {
    final outcome = await action();
    if (!mounted) return;
    outcome.ok
        ? showOk(context, outcome.message)
        : showErr(context, outcome.message);
  }
}

class _NumField {
  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.helper,
    this.allowNegative = false,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final String? helper;
  final bool allowNegative;
}

class _PrintCard extends StatelessWidget {
  const _PrintCard({
    required this.title,
    required this.icon,
    required this.printers,
    required this.loadingPrinters,
    required this.selectedPrinter,
    required this.onPrinterChanged,
    required this.fields,
    required this.preview,
    required this.onTestPrint,
    this.switches = const [],
    this.extra,
  });

  final String title;
  final IconData icon;
  final List<Printer> printers;
  final bool loadingPrinters;
  final String selectedPrinter;
  final ValueChanged<String> onPrinterChanged;
  final List<_NumField> fields;
  final List<(String, bool, ValueChanged<bool>)> switches;
  final Widget preview;
  final VoidCallback onTestPrint;

  /// محرّر إضافي يظهر قبل المعاينة (محتوى الوصل مثلاً).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          selectedPrinter.isEmpty ? tr('بلا طابعة محدَّدة') : selectedPrinter,
          style: const TextStyle(fontSize: 12),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (loadingPrinters)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<String>(
              initialValue: printers.any((p) => p.name == selectedPrinter)
                  ? selectedPrinter
                  : '',
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('الطابعة')),
              items: [
                DropdownMenuItem(
                  value: '',
                  child: Text(tr('نافذة الطباعة (اختيار يدوي)')),
                ),
                for (final printer in printers)
                  DropdownMenuItem(
                    value: printer.name,
                    child: Text(printer.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => onPrinterChanged(v ?? ''),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final field in fields)
                SizedBox(width: 168, child: _StepperField(field: field)),
            ],
          ),
          for (final entry in switches)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: entry.$2,
              onChanged: entry.$3,
              title: Text(entry.$1, style: const TextStyle(fontSize: 13)),
            ),
          ?extra,
          const SizedBox(height: 12),
          preview,
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTestPrint,
            icon: const Icon(Icons.print),
            label: Text(tr('طباعة تجريبية')),
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({required this.field});
  final _NumField field;

  @override
  Widget build(BuildContext context) {
    final text = field.step >= 1
        ? field.value.toStringAsFixed(0)
        : field.value.toStringAsFixed(1);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helper,
        helperMaxLines: 2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              final next = field.value - field.step;
              field.onChanged(
                field.allowNegative ? next : (next < 0 ? 0 : next),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove, size: 18, color: AppTheme.primary),
            ),
          ),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          InkWell(
            onTap: () => field.onChanged(field.value + field.step),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.add, size: 18, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
