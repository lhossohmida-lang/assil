import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/cloudinary_service.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/logo_watermark.dart';
import '../../../printing/domain/models/print_content.dart';
import '../../../printing/services/branding_marks.dart';
import '../../../printing/domain/models/receipt_content.dart';
import '../providers/settings_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// محرّر محتوى ورقة مطبوعة: اسم المحل، الأسطر الحرّة، الشعار، ورموز QR.
///
/// يخدم **وصل البيع وملصق الشحن معاً** عبر [PrintContent]: صاحب المحل
/// يضبطهما بالطريقة نفسها، وأي إصلاح هنا يصل الورقتين دفعةً واحدة.
class PrintContentEditor extends ConsumerWidget {
  const PrintContentEditor({
    super.key,
    required this.title,
    required this.content,
    required this.onChanged,
  });

  /// عنوان القسم («محتوى الوصل» / «محتوى ملصق الشحن»).
  final String title;
  final PrintContent content;
  final ValueChanged<PrintContent> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = content;
    final store = ref.watch(storeSettingsProvider).value;

    void save(PrintContent next) => onChanged(next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        _Title(title),

        // ─── اسم المحل ───
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: receipt.showStoreName,
          onChanged: (v) => save(receipt.copyWith(showStoreName: v)),
          title: Text(tr('طباعة اسم المحل')),
        ),
        if (receipt.showStoreName) ...[
          _StoreNameField(
            value: receipt.storeName,
            onSubmit: (v) => save(receipt.copyWith(storeName: v)),
          ),
          _AlignPicker(
            label: tr('محاذاة الاسم'),
            value: receipt.storeNameAlign,
            onChanged: (a) => save(receipt.copyWith(storeNameAlign: a)),
          ),
        ],

        const Divider(height: 20),

        // ─── الشعار ───
        _Title(tr('الشعار')),
        Row(
          children: [
            _LogoPreview(logo: receipt.logo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: receipt.logo.enabled,
                    onChanged: (v) => save(
                      receipt.copyWith(logo: receipt.logo.copyWith(enabled: v)),
                    ),
                    title: Text(tr('طباعة الشعار')),
                  ),
                  Row(
                    children: [
                      Text(tr('العرض'), style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          min: 8,
                          max: 60,
                          divisions: 52,
                          value: receipt.logo.widthMm.clamp(8, 60),
                          label: trf('{0}مم', [receipt.logo.widthMm.round()]),
                          onChanged: receipt.logo.enabled
                              ? (v) => save(
                                    receipt.copyWith(
                                      logo: receipt.logo.copyWith(widthMm: v),
                                    ),
                                  )
                              : null,
                        ),
                      ),
                      Text(trf('{0}مم', [receipt.logo.widthMm.round()]),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        _AlignPicker(
          label: tr('محاذاة الشعار'),
          value: receipt.logo.align,
          onChanged: (a) =>
              save(receipt.copyWith(logo: receipt.logo.copyWith(align: a))),
        ),
        _PositionPicker(
          footer: receipt.logo.footer,
          onChanged: (f) =>
              save(receipt.copyWith(logo: receipt.logo.copyWith(footer: f))),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickLogo(context, receipt, save),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(tr('اختيار صورة')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: receipt.logo.usesCustomImage
                    ? () => save(
                          receipt.copyWith(
                            logo: receipt.logo.copyWith(imageBase64: ''),
                          ),
                        )
                    : null,
                icon: const Icon(Icons.restore, size: 18),
                label: Text(tr('الشعار المضمَّن')),
              ),
            ),
          ],
        ),

        const Divider(height: 20),

        // ─── الأسطر الحرّة ───
        Row(
          children: [
            Expanded(child: _Title(tr('أسطر حرّة على الوصل'))),
            TextButton.icon(
              onPressed: () => _editLine(context, receipt, save, null),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr('سطر')),
            ),
          ],
        ),
        Text(
          tr('اكتب ما شئت: فيسبوك، رقم الهاتف، عبارة شكر، شروط الإرجاع...'),
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        if (receipt.lines.isEmpty)
          Text(
            tr('لا أسطر — اضغط «سطر» لإضافة أول سطر.'),
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          )
        else
          for (var i = 0; i < receipt.lines.length; i++)
            _LineTile(
              line: receipt.lines[i],
              onEdit: () =>
                  _editLine(context, receipt, save, i),
              onDelete: () {
                final next = [...receipt.lines]..removeAt(i);
                save(receipt.copyWith(lines: next));
              },
              onMoveUp: i == 0
                  ? null
                  : () {
                      final next = [...receipt.lines];
                      final item = next.removeAt(i);
                      next.insert(i - 1, item);
                      save(receipt.copyWith(lines: next));
                    },
            ),

        const Divider(height: 20),

        // ─── رموز QR ───
        _Title(tr('رموز QR')),
        if (store == null ||
            (!store.hasSocial && store.storefrontUrl.isEmpty))
          Text(
            tr('أضف روابط فيسبوك وإنستغرام وعنوان المتجر من قسم «المتجر الإلكتروني والتواصل» أعلاه ليمكن طباعتها.'),
            style: TextStyle(fontSize: 12, color: AppTheme.warning),
          )
        else ...[
          if (store.facebookUrl.isNotEmpty)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: receipt.qr.showFacebook,
              onChanged: (v) => save(
                receipt.copyWith(qr: receipt.qr.copyWith(showFacebook: v)),
              ),
              title: Text(tr('رمز فيسبوك')),
            ),
          if (store.instagramUrl.isNotEmpty)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: receipt.qr.showInstagram,
              onChanged: (v) => save(
                receipt.copyWith(qr: receipt.qr.copyWith(showInstagram: v)),
              ),
              title: Text(tr('رمز إنستغرام')),
            ),
          if (store.storefrontUrl.isNotEmpty)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: receipt.qr.showWebsite,
              onChanged: (v) => save(
                receipt.copyWith(qr: receipt.qr.copyWith(showWebsite: v)),
              ),
              title: Text(tr('رمز المتجر الإلكتروني')),
              subtitle: Text(
                prettyDomain(store.storefrontUrl),
                textDirection: TextDirection.ltr,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          if (receipt.qr.any) ...[
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: receipt.qr.withLabels,
              onChanged: (v) => save(
                receipt.copyWith(qr: receipt.qr.copyWith(withLabels: v)),
              ),
              title: Text(tr('أيقونة واسم تحت كل رمز')),
            ),
            Row(
              children: [
                Text(tr('حجم الرمز'), style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    min: 10,
                    max: 40,
                    divisions: 30,
                    value: receipt.qr.sizeMm.clamp(10, 40),
                    label: trf('{0}مم', [receipt.qr.sizeMm.round()]),
                    onChanged: (v) => save(
                      receipt.copyWith(qr: receipt.qr.copyWith(sizeMm: v)),
                    ),
                  ),
                ),
                Text(trf('{0}مم', [receipt.qr.sizeMm.round()]),
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickLogo(
    BuildContext context,
    PrintContent receipt,
    ValueChanged<PrintContent> save,
  ) async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;

      // نضغطها بشدّة: الصورة تُخزَّن base64 داخل إعدادات الجهاز، وشعار
      // 4 ميغابايت يجعل قراءة الإعدادات بطيئة عند كل إقلاع.
      final compressed = CloudinaryService.compress(
        await file.readAsBytes(),
        maxSide: 480,
        quality: 80,
      );
      save(
        receipt.copyWith(
          logo: receipt.logo.copyWith(imageBase64: base64Encode(compressed)),
        ),
      );
      if (context.mounted) showOk(context, tr('حُفظ شعار الوصل'));
    } catch (e) {
      if (context.mounted) showErr(context, trf('تعذّر اختيار الصورة: {0}', [e]));
    }
  }

  Future<void> _editLine(
    BuildContext context,
    PrintContent receipt,
    ValueChanged<PrintContent> save,
    int? index,
  ) async {
    final existing = index == null ? null : receipt.lines[index];
    final controller = TextEditingController(text: existing?.text ?? '');
    var align = existing?.align ?? ReceiptAlign.center;
    var bold = existing?.bold ?? false;
    var size = existing?.fontSize ?? 9.0;
    var footer = existing?.footer ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(index == null ? tr('سطر جديد') : tr('تعديل السطر')),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: tr('النصّ'),
                      hintText: 'facebook.com/alaseel',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AlignPicker(
                    label: tr('المحاذاة'),
                    value: align,
                    onChanged: (a) => setState(() => align = a),
                  ),
                  _PositionPicker(
                    footer: footer,
                    onChanged: (f) => setState(() => footer = f),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: bold,
                    onChanged: (v) => setState(() => bold = v),
                    title: Text(tr('خط عريض')),
                  ),
                  Row(
                    children: [
                      Text(tr('الحجم'), style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Slider(
                          min: 6,
                          max: 20,
                          divisions: 28,
                          value: size,
                          label: size.toStringAsFixed(1),
                          onChanged: (v) => setState(() => size = v),
                        ),
                      ),
                      Text(size.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
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
      ),
    );

    final text = controller.text.trim();
    controller.dispose();
    if (ok != true || text.isEmpty) return;

    final line = ReceiptLine(
      text: text,
      align: align,
      bold: bold,
      fontSize: size,
      footer: footer,
    );
    final next = [...receipt.lines];
    if (index == null) {
      next.add(line);
    } else {
      next[index] = line;
    }
    save(receipt.copyWith(lines: next));
  }
}

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.logo});
  final ReceiptLogo logo;

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (logo.usesCustomImage) {
      try {
        child = Image.memory(base64Decode(logo.imageBase64), fit: BoxFit.contain);
      } catch (_) {
        child = const Icon(Icons.broken_image);
      }
    } else {
      child = StoreLogo(size: 56, color: AppTheme.textPrimary);
    }

    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Opacity(opacity: logo.enabled ? 1 : 0.3, child: child),
    );
  }
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
  });

  final ReceiptLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        line.footer ? Icons.vertical_align_bottom : Icons.vertical_align_top,
        size: 20,
        color: AppTheme.textSecondary,
      ),
      title: Text(
        line.text,
        style: TextStyle(
          fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        trf('{0} · {1} · حجم {2}', [line.footer ? tr('أسفل') : tr('أعلى'), line.align.label, line.fontSize.toStringAsFixed(1)]),
        style: const TextStyle(fontSize: 11),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: onMoveUp,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppTheme.danger),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AlignPicker extends StatelessWidget {
  const _AlignPicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final ReceiptAlign value;
  final ValueChanged<ReceiptAlign> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(label, style: const TextStyle(fontSize: 12.5)),
        ),
        Expanded(
          child: SegmentedButton<ReceiptAlign>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ReceiptAlign.start,
                icon: Icon(Icons.format_align_right, size: 18),
              ),
              ButtonSegment(
                value: ReceiptAlign.center,
                icon: Icon(Icons.format_align_center, size: 18),
              ),
              ButtonSegment(
                value: ReceiptAlign.end,
                icon: Icon(Icons.format_align_left, size: 18),
              ),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }
}

class _PositionPicker extends StatelessWidget {
  const _PositionPicker({required this.footer, required this.onChanged});

  final bool footer;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(tr('الموضع'), style: TextStyle(fontSize: 12.5)),
        ),
        Expanded(
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(tr('أعلى الوصل'))),
              ButtonSegment(value: true, label: Text(tr('أسفل الوصل'))),
            ],
            selected: {footer},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      );
}

/// حقل اسم المحل المطبوع على الوصل.
///
/// يُحفظ عند فقدان التركيز أو الضغط على «تمّ» لا عند كل حرف: الإعدادات
/// تُكتب على القرص، وحفظها مع كل ضغطة مفتاح يُتلعثم الكتابة على الهاتف.
class _StoreNameField extends StatefulWidget {
  const _StoreNameField({required this.value, required this.onSubmit});

  final String value;
  final ValueChanged<String> onSubmit;

  @override
  State<_StoreNameField> createState() => _StoreNameFieldState();
}

class _StoreNameFieldState extends State<_StoreNameField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Focus(
        onFocusChange: (has) {
          if (!has) widget.onSubmit(_controller.text);
        },
        child: TextField(
          controller: _controller,
          textInputAction: TextInputAction.done,
          onSubmitted: widget.onSubmit,
          decoration: InputDecoration(
            isDense: true,
            labelText: tr('اسم المحل على الوصل'),
            hintText: AppConstants.storeDisplayName,
            helperText:
                tr('اتركه فارغاً لاستعمال الاسم الافتراضي. هذا الاسم لهذا الجهاز وحده.'),
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.storefront_outlined),
          ),
        ),
      ),
    );
  }
}
