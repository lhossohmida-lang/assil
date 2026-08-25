import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/logo_watermark.dart';
import '../../domain/models/store_settings.dart';
import '../providers/settings_providers.dart';
import 'color_wheel_picker.dart';
import '../../../../core/i18n/app_strings.dart';

// ═══════════════════════════ المظهر واللغة ═══════════════════════════

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('المظهر واللغة'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ─── اللغة ───
            _Label(tr('اللغة')),
            Row(
              children: [
                for (final entry in [
                  ('ar', tr('العربية')),
                  ('fr', 'Français'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(entry.$2),
                      selected: appearance.languageCode == entry.$1,
                      onSelected: (_) => notifier.setLanguage(entry.$1),
                    ),
                  ),
              ],
            ),

            const Divider(height: 24),

            // ─── لوحة الألوان ───
            _Label(tr('لون التطبيق')),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final palette in AppPalette.all)
                  _PaletteChip(
                    palette: palette,
                    selected: appearance.paletteId == palette.id,
                    arabic: appearance.isArabic,
                    onTap: () => notifier.setPalette(palette.id),
                  ),
              ],
            ),

            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: appearance.dark,
              onChanged: notifier.setDark,
              secondary: Icon(
                appearance.dark ? Icons.dark_mode : Icons.light_mode,
              ),
              title: Text(tr('الوضع الداكن')),
              subtitle: Text(tr('مبنيّ بألوان صريحة — لا يتبع النظام')),
            ),

            const Divider(height: 24),

            // ─── العلامة المائية ───
            _Label(tr('شعار المحل خلف الشاشات')),
            Row(
              children: [
                StoreLogo(size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: appearance.showLogoWatermark,
                        onChanged: notifier.setWatermark,
                        title: Text(tr('إظهار العلامة المائية')),
                      ),
                      Row(
                        children: [
                          Text(tr('الوضوح'), style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: 0.4,
                              divisions: 20,
                              value: appearance.watermarkOpacity
                                  .clamp(0.0, 0.4),
                              label:
                                  trf('{0}٪', [(appearance.watermarkOpacity * 100).round()]),
                              onChanged: appearance.showLogoWatermark
                                  ? notifier.setWatermarkOpacity
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickLogo(context, ref),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(tr('اختيار شعار')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: ref
                                .watch(storeSettingsProvider)
                                .value
                                ?.hasCustomLogo ??
                            false
                        ? () => _resetLogo(context, ref)
                        : null,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: Text(tr('الافتراضي')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr('الشعار مشترك بين كل الأجهزة — غيّره هنا فيتغيّر على هاتف العامل أيضاً، وفي الوصل والقائمة وشاشة الدخول.'),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.palette,
    required this.selected,
    required this.arabic,
    required this.onTap,
  });

  final AppPalette palette;
  final bool selected;
  final bool arabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? palette.primary : AppTheme.cardBorder,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(palette.primary),
                _dot(palette.accent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              arabic ? palette.nameAr : palette.nameFr,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}

// ═══════════════ الأنواع والمقاسات والألوان ═══════════════

/// يختار صورة الشعار ويحفظها في الإعدادات المشتركة.
///
/// التصغير والترميز في المستودع لا هنا: الواجهة لا يجب أن تعرف سقف حجم
/// مستند Firestore، والقاعدة نفسها تلزم أي مسار آخر يحفظ شعاراً لاحقاً.
Future<void> _pickLogo(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  if (repo == null) return;
  try {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await repo.setLogo(await file.readAsBytes());
    if (context.mounted) showOk(context, tr('حُفظ الشعار'));
  } catch (e) {
    if (context.mounted) showErr(context, trf('تعذّر حفظ الشعار: {0}', [e]));
  }
}

Future<void> _resetLogo(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(settingsRepositoryProvider);
  if (repo == null) return;
  await repo.clearLogo();
  if (context.mounted) showOk(context, tr('أُعيد الشعار الافتراضي'));
}

class CatalogListsSection extends ConsumerWidget {
  const CatalogListsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(storeSettingsProvider).value ?? const StoreSettings();
    final repo = ref.watch(settingsRepositoryProvider);

    return Column(
      children: [
        _TextListCard(
          title: tr('أنواع المنتجات'),
          icon: Icons.category_outlined,
          hint: tr('قميص، جبّة، سروال...'),
          note: tr('تظهر في بطاقة المنتج وفي فرز نقطة البيع.'),
          values: settings.categories,
          onChanged: (v) => repo?.setCategories(v),
        ),
        _TextListCard(
          title: tr('المقاسات'),
          icon: Icons.straighten,
          hint: tr('M، L، XL، 42...'),
          note: tr('تُكتب كما تريدها أن تظهر على بطاقة المنتج.'),
          values: settings.sizes,
          onChanged: (v) => repo?.setSizes(v),
        ),
        _ColorsCard(
          colors: settings.colors,
          onChanged: (v) => repo?.setColors(v),
        ),
      ],
    );
  }
}

class _TextListCard extends StatefulWidget {
  const _TextListCard({
    required this.title,
    required this.icon,
    required this.hint,
    required this.note,
    required this.values,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final String hint;
  final String note;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_TextListCard> createState() => _TextListCardState();
}

class _TextListCardState extends State<_TextListCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final value = _controller.text.trim();
    if (value.isEmpty || widget.values.contains(value)) return;
    widget.onChanged([...widget.values, value]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.values.length}',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.values.isEmpty)
              Text(
                tr('لا شيء بعد — أضف أول عنصر.'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in widget.values)
                    Chip(
                      label: Text(v),
                      onDeleted: () => widget.onChanged(
                        widget.values.where((e) => e != v).toList(),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _add,
                ),
              ],
            ),
            Text(
              widget.note,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorsCard extends StatelessWidget {
  const _ColorsCard({required this.colors, required this.onChanged});

  final List<ColorOption> colors;
  final ValueChanged<List<ColorOption>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.color_lens_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('الألوان'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  '${colors.length}',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (colors.isEmpty)
              Text(
                tr('لا ألوان بعد — اضغط «إضافة لون» لتظهر دائرة الألوان.'),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in colors)
                    _ColorChip(
                      option: c,
                      onEdit: () => _edit(context, c),
                      onDelete: () => onChanged(
                        colors.where((e) => e != c).toList(),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _edit(context, null),
              icon: const Icon(Icons.add),
              label: Text(tr('إضافة لون')),
            ),
            Text(
              tr('اللون يُختار من دائرة الألوان بدقّة، ويظهر في بطاقة المنتج.'),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, ColorOption? existing) async {
    final picked = await showColorWheelDialog(
      context,
      initial: Color(existing?.value ?? 0xFF1565C0),
    );
    if (picked == null || !context.mounted) return;

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('اسم اللون')),
        content: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: picked,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: tr('الاسم'),
                  hintText: tr('أبيض، كحلي، بيج...'),
                ),
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
              ),
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

    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    if (ok != true || name.isEmpty) return;

    final option = ColorOption(name: name, value: picked.toARGB32());
    final next = [...colors];
    if (existing != null) {
      final index = next.indexOf(existing);
      if (index >= 0) {
        next[index] = option;
      } else {
        next.add(option);
      }
    } else if (!next.any((c) => c.name == name)) {
      next.add(option);
    }
    onChanged(next);
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.option,
    required this.onEdit,
    required this.onDelete,
  });

  final ColorOption option;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: Container(
        decoration: BoxDecoration(
          color: Color(option.value),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.cardBorder),
        ),
      ),
      label: Text('${option.name}  ${option.hex}'),
      onPressed: onEdit,
      onDeleted: onDelete,
    );
  }
}

// ═══════════════════════ فيسبوك وإنستغرام ═══════════════════════

class SocialSection extends ConsumerStatefulWidget {
  const SocialSection({super.key});

  @override
  ConsumerState<SocialSection> createState() => _SocialSectionState();
}

class _SocialSectionState extends ConsumerState<SocialSection> {
  final _facebook = TextEditingController();
  final _instagram = TextEditingController();
  final _storeName = TextEditingController();
  final _tagline = TextEditingController();
  final _phone = TextEditingController();
  final _storefrontUrl = TextEditingController();
  final _facebookName = TextEditingController();
  final _instagramName = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _facebook.dispose();
    _instagram.dispose();
    _storeName.dispose();
    _tagline.dispose();
    _phone.dispose();
    _storefrontUrl.dispose();
    _facebookName.dispose();
    _instagramName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(storeSettingsProvider).value ?? const StoreSettings();
    if (!_initialized && ref.watch(storeSettingsProvider).hasValue) {
      _facebook.text = settings.facebookUrl;
      _instagram.text = settings.instagramUrl;
      _storeName.text = settings.storeName;
      _tagline.text = settings.storeTagline;
      _phone.text = settings.storePhone;
      _storefrontUrl.text = settings.storefrontUrl;
      _facebookName.text = settings.facebookName;
      _instagramName.text = settings.instagramName;
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
                Icon(Icons.share_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('المتجر الإلكتروني والتواصل'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tr('هذه البيانات تظهر في المتجر الإلكتروني للزبائن، ويمكن طباعة رمز QR للروابط على وصل البيع (من إعدادات الوصل).'),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _storeName,
              decoration: InputDecoration(
                labelText: tr('اسم المحل في المتجر'),
                hintText: tr('الأصيل'),
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tagline,
              decoration: InputDecoration(
                labelText: tr('جملة تعريفية'),
                hintText: tr('قمصان رجالية بلمسة أصيلة'),
                prefixIcon: Icon(Icons.short_text),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('هاتف للزبائن'),
                hintText: '05XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _storefrontUrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('عنوان المتجر الإلكتروني'),
                hintText: 'https://assil.vercel.app',
                prefixIcon: Icon(Icons.link),
                helperText: tr('يفتحه زرّ «المتجر» في شاشة الطلبات.'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _facebook,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('رابط فيسبوك'),
                hintText: 'https://facebook.com/...',
                prefixIcon: Icon(Icons.facebook),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _facebookName,
              decoration: InputDecoration(
                isDense: true,
                labelText: tr('اسم صفحة فيسبوك'),
                hintText: tr('الأصيل'),
                helperText: tr('يُكتب بجانب الأيقونة تحت رمز QR على الوصل والملصق.'),
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instagram,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: tr('رابط إنستغرام'),
                hintText: 'https://instagram.com/...',
                prefixIcon: Icon(Icons.camera_alt_outlined),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _instagramName,
              decoration: InputDecoration(
                isDense: true,
                labelText: tr('اسم حساب إنستغرام'),
                hintText: '@alasil.dz',
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(settingsRepositoryProvider)?.saveStorefront(
                      facebook: _facebook.text,
                      instagram: _instagram.text,
                      storeName: _storeName.text,
                      tagline: _tagline.text,
                      phone: _phone.text,
                      storefrontUrl: _storefrontUrl.text,
                      facebookName: _facebookName.text,
                      instagramName: _instagramName.text,
                    );
                if (context.mounted) {
                  showOk(context, tr('حُفظت بيانات المتجر ونُشرت للموقع'));
                }
              },
              icon: const Icon(Icons.save),
              label: Text(tr('حفظ ونشر')),
            ),

            if (settings.hasSocial) ...[
              const Divider(height: 24),
              _Label(tr('معاينة رموز QR')),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (settings.facebookUrl.isNotEmpty)
                    _QrPreview(label: tr('فيسبوك'), data: settings.facebookUrl),
                  if (settings.instagramUrl.isNotEmpty)
                    _QrPreview(label: tr('إنستغرام'), data: settings.instagramUrl),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.label, required this.data});
  final String label;
  final String data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          color: Colors.white,
          child: BarcodeWidget(
            barcode: Barcode.qrCode(),
            data: data,
            width: 96,
            height: 96,
            drawText: false,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      );
}
