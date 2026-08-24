import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/cloudinary_service.dart';
import '../../../../shared/services/scanner_service.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/models/product.dart';
import '../../../settings/domain/models/store_settings.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../providers/inventory_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// شاشة إضافة/تعديل منتج.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.existing});

  final Product? existing;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _purchase;
  late final TextEditingController _sell;
  late final TextEditingController _quantity;
  late final TextEditingController _minQuantity;
  late final TextEditingController _category;
  late final TextEditingController _supplier;
  late final TextEditingController _description;

  late List<String> _sizes;
  late List<String> _colors;
  late List<String> _images;
  late List<String> _imagePublicIds;

  /// معرّفات صور أُزيلت أثناء التعديل — تُسجَّل كأيتام عند الحفظ.
  final List<String> _removedPublicIds = [];

  late bool _published;
  bool _busy = false;
  bool _uploading = false;

  Product? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final p = _existing;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _purchase = TextEditingController(
        text: p == null ? '' : moneyPlain(p.purchasePrice));
    _sell =
        TextEditingController(text: p == null ? '' : moneyPlain(p.sellPrice));
    _quantity = TextEditingController(text: p == null ? '1' : '${p.quantity}');
    _minQuantity =
        TextEditingController(text: p == null ? '1' : '${p.minQuantity}');
    _category = TextEditingController(text: p?.category ?? '');
    _supplier = TextEditingController(text: p?.supplier ?? '');
    _description = TextEditingController(text: p?.description ?? '');

    _sizes = [...?p?.sizes];
    _colors = [...?p?.colors];
    _images = [...?p?.images];
    _imagePublicIds = [...?p?.imagePublicIds];
    _published = p?.publishedToStore ?? true;
    // ⚠️ الباركود يبدأ **فارغاً** عمداً: البائع يمسح رمز المنتج بالماسح
    // مباشرةً فيملأ الحقل. توليد رقم تلقائي عند الفتح كان يملأ الحقل
    // برقم لا يقابل أي ملصق على القطعة، فيُطبع ملصق جديد بلا داعٍ.
    // زرّ التوليد بجانب الحقل لمن أراد رقماً جديداً.
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _barcode,
      _purchase,
      _sell,
      _quantity,
      _minQuantity,
      _category,
      _supplier,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generateBarcode() async {
    final repo = ref.read(inventoryRepositoryProvider);
    if (repo == null) return;
    final code = await repo.generateUniqueBarcode();
    if (mounted) _barcode.text = code;
  }

  Future<void> _scanBarcode() async {
    final code = await ScannerService.scanOnce(context);
    if (code != null && code.isNotEmpty && mounted) {
      setState(() => _barcode.text = code);
    }
  }

  Future<void> _pickImages() async {
    if (!AppConstants.isCloudinaryConfigured) {
      showErr(
        context,
        tr('رفع الصور غير مهيّأ — املأ cloudinaryCloudName و cloudinaryUploadPreset في app_constants.dart'),
      );
      return;
    }

    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty || !mounted) return;

    setState(() => _uploading = true);
    const service = CloudinaryService();
    var failed = 0;

    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final uploaded = await service.upload(bytes, filename: file.name);
        if (!mounted) return;
        setState(() {
          _images.add(uploaded.url);
          _imagePublicIds.add(uploaded.publicId);
        });
      } catch (e) {
        failed++;
        if (mounted) showErr(context, '$e');
      }
    }

    if (mounted) {
      setState(() => _uploading = false);
      if (failed == 0) showOk(context, trf('رُفعت {0} صورة', [files.length]));
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      if (index < _imagePublicIds.length) {
        _removedPublicIds.add(_imagePublicIds.removeAt(index));
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(inventoryRepositoryProvider);
    if (repo == null) return;

    final barcode = cleanBarcode(_barcode.text);
    if (barcode.isNotEmpty &&
        await repo.barcodeExists(barcode, exceptId: _existing?.id)) {
      if (mounted) showErr(context, tr('هذا الباركود مستعمل في منتج آخر'));
      return;
    }

    setState(() => _busy = true);
    try {
      final product = Product(
        id: _existing?.id ?? '',
        name: _name.text.trim(),
        barcode: barcode,
        purchasePrice: toDouble(_purchase.text),
        sellPrice: toDouble(_sell.text),
        quantity: toInt(_quantity.text),
        minQuantity: toInt(_minQuantity.text),
        category: _category.text.trim(),
        supplier: _supplier.text.trim(),
        description: _description.text.trim(),
        imageUrl: _existing?.imageUrl ?? '',
        images: _images,
        imagePublicIds: _imagePublicIds,
        sizes: _sizes,
        colors: _colors,
        publishedToStore: _published,
        reserved: _existing?.reserved ?? 0,
        createdAt: _existing?.createdAt,
      );

      if (_existing == null) {
        await repo.addProduct(product);
      } else {
        await repo.updateProduct(product, removedPublicIds: _removedPublicIds);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        showOk(context, _existing == null ? tr('أُضيف المنتج') : tr('حُفظ التعديل'));
      }
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر الحفظ: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // الأنواع والمقاسات والألوان تُدار كلها من الإعدادات — لا قوائم
    // مكتوبة في الكود، فيغيّرها صاحب المحل بلا إعادة بناء التطبيق.
    final storeSettings =
        ref.watch(storeSettingsProvider).value ?? const StoreSettings();
    final suppliers = ref.watch(suppliersProvider);
    final isEdit = _existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? tr('تعديل منتج') : tr('منتج جديد')),
        actions: [
          if (isEdit)
            IconButton(
              tooltip: tr('حذف'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !isEdit,
              decoration: InputDecoration(
                labelText: tr('اسم المنتج *'),
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? tr('الاسم مطلوب') : null,
            ),
            const SizedBox(height: 12),

            // ─── الباركود ───
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _barcode,
                    decoration: InputDecoration(
                      labelText: tr('الباركود'),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: tr('توليد رقم جديد'),
                  icon: const Icon(Icons.autorenew),
                  onPressed: _generateBarcode,
                ),
                IconButton.filledTonal(
                  tooltip: tr('مسح بالكاميرا'),
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 4, right: 4),
              child: Text(
                // شرح موجز لماذا 8 — حتى لا يكتب أحد 13 رقماً يدوياً.
                tr('الأرقام المولّدة 8 خانات: تعطي خطوطاً أعرض تُقرأ من أبعد.'),
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),

            // ─── الأسعار ───
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchase,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('سعر الشراء *'),
                      suffixText: AppConstants.currencySymbol,
                    ),
                    validator: (v) =>
                        toDouble(v) < 0 ? tr('قيمة غير صحيحة') : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _sell,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: tr('سعر البيع *'),
                      suffixText: AppConstants.currencySymbol,
                    ),
                    validator: (v) =>
                        toDouble(v) <= 0 ? tr('أدخل سعر بيع') : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            _ProfitHint(
              purchase: toDouble(_purchase.text),
              sell: toDouble(_sell.text),
            ),
            const SizedBox(height: 12),

            // ─── الكميات ───
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('الكمية *')),
                    validator: (v) => toInt(v) < 0 ? tr('قيمة غير صحيحة') : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _minQuantity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('حد التنبيه'),
                      helperText: tr('تحذير عند الوصول إليه'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _CategoryField(
              controller: _category,
              categories: storeSettings.categories,
            ),
            const SizedBox(height: 12),
            _SuggestField(
              controller: _supplier,
              label: tr('المورّد'),
              icon: Icons.local_shipping_outlined,
              suggestions: suppliers,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: InputDecoration(labelText: tr('الوصف')),
            ),
            const SizedBox(height: 16),

            _ChipsEditor(
              title: tr('المقاسات'),
              values: _sizes,
              suggestions: storeSettings.sizes,
              emptyHint: tr('لا مقاسات مضبوطة — أضِفها من الإعدادات.'),
              onChanged: (v) => setState(() => _sizes = v),
            ),
            const SizedBox(height: 16),
            _ColorsPicker(
              selected: _colors,
              palette: storeSettings.colors,
              onChanged: (v) => setState(() => _colors = v),
            ),
            const SizedBox(height: 16),

            _ImagesEditor(
              images: _images,
              uploading: _uploading,
              onAdd: _pickImages,
              onRemove: _removeImage,
            ),
            const SizedBox(height: 16),

            Card(
              child: SwitchListTile(
                value: _published,
                onChanged: (v) => setState(() => _published = v),
                title: Text(tr('يظهر في المتجر الإلكتروني')),
                subtitle: Text(tr('إظهاره لا يؤثّر على المخزون')),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _busy || _uploading ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(isEdit ? tr('حفظ التعديل') : tr('إضافة المنتج')),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final p = _existing;
    if (p == null) return;
    final ok = await confirmDialog(
      context,
      title: tr('حذف المنتج'),
      message: trf('سيُحذف «{0}» نهائياً من المخزون ومن المتجر الإلكتروني.', [p.name]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !mounted) return;

    try {
      await ref.read(inventoryRepositoryProvider)!.deleteProduct(p);
      if (mounted) {
        Navigator.of(context).pop(true);
        showOk(context, tr('حُذف المنتج'));
      }
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر الحذف: {0}', [e]));
    }
  }
}

/// يعرض الفائدة على القطعة أثناء الكتابة — يمنع أخطاء التسعير.
class _ProfitHint extends StatelessWidget {
  const _ProfitHint({required this.purchase, required this.sell});
  final double purchase;
  final double sell;

  @override
  Widget build(BuildContext context) {
    if (sell <= 0) return const SizedBox.shrink();
    final profit = sell - purchase;
    final margin = sell == 0 ? 0.0 : (profit / sell) * 100;
    final color = profit <= 0 ? AppTheme.danger : AppTheme.success;
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 4),
      child: Text(
        profit <= 0
            ? trf('تنبيه: لا فائدة في هذا السعر ({0})', [money(profit)])
            : trf('الفائدة على القطعة {0} ({1}٪)', [money(profit), margin.toStringAsFixed(0)]),
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}

/// حقل نصّي مع اقتراحات من القيم المستعملة سابقاً.
class _SuggestField extends StatelessWidget {
  const _SuggestField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.suggestions,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
        if (suggestions.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in suggestions.take(12))
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 6),
                    child: ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      onPressed: () => controller.text = s,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// محرّر قائمة نصوص بشكل chips (المقاسات، الألوان).
class _ChipsEditor extends StatefulWidget {
  const _ChipsEditor({
    required this.title,
    required this.values,
    required this.suggestions,
    required this.onChanged,
    this.emptyHint,
  });

  final String title;
  final List<String> values;
  final List<String> suggestions;
  final ValueChanged<List<String>> onChanged;
  final String? emptyHint;

  @override
  State<_ChipsEditor> createState() => _ChipsEditorState();
}

class _ChipsEditorState extends State<_ChipsEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final value = raw.trim();
    if (value.isEmpty || widget.values.contains(value)) return;
    widget.onChanged([...widget.values, value]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
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
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: trf('أضف {0}', [widget.title]),
                  isDense: true,
                ),
                onSubmitted: _add,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _add(_controller.text),
            ),
          ],
        ),
        if (widget.suggestions.isEmpty && widget.emptyHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.emptyHint!,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          )
        else
          Wrap(
            spacing: 6,
            children: [
              for (final s in widget.suggestions)
                if (!widget.values.contains(s))
                  ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _add(s),
                  ),
            ],
          ),
      ],
    );
  }
}

class _ImagesEditor extends StatelessWidget {
  const _ImagesEditor({
    required this.images,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> images;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(tr('الصور'), style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (images.isNotEmpty)
              Text(
                tr('(الأولى هي الغلاف)'),
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            const Spacer(),
            if (uploading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(tr('إضافة صور')),
              ),
          ],
        ),
        if (images.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images[i],
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: InkWell(
                        onTap: () => onRemove(i),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppTheme.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// حقل نوع المنتج — قائمة من الإعدادات، مع إبقاء أي قيمة قديمة غير
/// موجودة في القائمة حتى لا تُمحى بصمت عند فتح منتج قديم.
class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.controller, required this.categories});

  final TextEditingController controller;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    final options = [
      ...categories,
      if (current.isNotEmpty && !categories.contains(current)) current,
    ];

    if (options.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: tr('النوع'),
              prefixIcon: Icon(Icons.category_outlined),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(
              tr('لا أنواع مضبوطة — أضِفها من الإعدادات لتظهر كقائمة.'),
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: current.isEmpty ? null : current,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: tr('النوع'),
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(tr('بلا نوع'))),
        for (final c in options)
          DropdownMenuItem(value: c, child: Text(c)),
      ],
      onChanged: (v) => controller.text = v ?? '',
    );
  }
}

/// اختيار ألوان المنتج من ألوان الإعدادات — بعيّنات لونية حقيقية لا أسماء
/// مجرّدة، فيرى البائع اللون كما ستراه الزبونة.
class _ColorsPicker extends StatelessWidget {
  const _ColorsPicker({
    required this.selected,
    required this.palette,
    required this.onChanged,
  });

  final List<String> selected;
  final List<ColorOption> palette;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    // ألوان محفوظة في منتج قديم لم تعد في الإعدادات — نُبقيها ظاهرة.
    final extra =
        selected.where((n) => !palette.any((c) => c.name == n)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('الألوان'), style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (palette.isEmpty && extra.isEmpty)
          Text(
            tr('لا ألوان مضبوطة — أضِفها من الإعدادات (بدائرة الألوان).'),
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in palette)
                _Swatch(
                  name: option.name,
                  color: Color(option.value),
                  chosen: selected.contains(option.name),
                  onTap: () => _toggle(option.name),
                ),
              for (final name in extra)
                _Swatch(
                  name: name,
                  color: Colors.grey,
                  chosen: true,
                  onTap: () => _toggle(name),
                ),
            ],
          ),
      ],
    );
  }

  void _toggle(String name) => onChanged(
        selected.contains(name)
            ? selected.where((e) => e != name).toList()
            : [...selected, name],
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.name,
    required this.color,
    required this.chosen,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: chosen ? AppTheme.primary : AppTheme.cardBorder,
            width: chosen ? 2 : 1,
          ),
          color: chosen ? AppTheme.primary.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.cardBorder),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: chosen ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (chosen)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check, size: 14, color: AppTheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}
