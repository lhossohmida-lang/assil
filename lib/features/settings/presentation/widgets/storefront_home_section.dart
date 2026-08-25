import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/cloudinary_service.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../providers/settings_providers.dart';

/// واجهة المتجر الإلكتروني: صور الأصناف والمنتجات المختارة.
///
/// الزائر يفتح الموقع فيرى بطاقات الأصناف بصورها أولاً، ثم المنتجات
/// المختارة تحتها. كلاهما يُضبط هنا ويُنشر إلى المرآة العامة فوراً.
class StorefrontHomeSection extends ConsumerWidget {
  const StorefrontHomeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider).value;
    if (settings == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  tr('واجهة المتجر الإلكتروني'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              tr('أول ما يراه الزائر: بطاقات الأصناف بصورها، وتحتها المنتجات المختارة.'),
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),

            const Divider(height: 22),
            _Label(tr('صور الأصناف')),
            if (settings.categories.isEmpty)
              Text(
                tr('أضف أنواع المنتجات أوّلاً من «أنواع المنتجات» أعلاه.'),
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              )
            else
              for (final category in settings.categories)
                _CategoryImageTile(
                  category: category,
                  imageUrl: settings.categoryImages[category] ?? '',
                ),

            const Divider(height: 22),
            _Label(tr('المنتجات المختارة')),
            _FeaturedPicker(selected: settings.featuredProductIds),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );
}

/// صورة صنف واحد — تُرفع إلى Cloudinary ويُخزَّن رابطها.
///
/// رابط لا base64: مستند المرآة عام تقرأه كل زيارة، وصورة واحدة بصيغة
/// base64 تكفي لتضخيمه فوق ما يُحتمل. Cloudinary يخدمها مضغوطة ومُخبَّأة.
class _CategoryImageTile extends ConsumerStatefulWidget {
  const _CategoryImageTile({required this.category, required this.imageUrl});

  final String category;
  final String imageUrl;

  @override
  ConsumerState<_CategoryImageTile> createState() => _CategoryImageTileState();
}

class _CategoryImageTileState extends ConsumerState<_CategoryImageTile> {
  bool _busy = false;

  Future<void> _pick() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = ref.read(storeSettingsProvider).value;
    if (repo == null || settings == null) return;

    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      setState(() => _busy = true);

      final uploaded = await const CloudinaryService()
          .upload(await file.readAsBytes(), filename: widget.category);

      await repo.setCategoryImages({
        ...settings.categoryImages,
        widget.category: uploaded.url,
      });
      if (mounted) showOk(context, tr('حُفظت صورة الصنف'));
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر رفع الصورة: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final repo = ref.read(settingsRepositoryProvider);
    final settings = ref.read(storeSettingsProvider).value;
    if (repo == null || settings == null) return;
    final next = {...settings.categoryImages}..remove(widget.category);
    await repo.setCategoryImages(next);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 52,
        height: 52,
        child: _busy
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: widget.imageUrl.isEmpty
                    ? Container(
                        color: AppTheme.cardBorder,
                        child: Icon(
                          Icons.image_outlined,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : Image.network(
                        widget.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.broken_image, color: AppTheme.danger),
                      ),
              ),
      ),
      title: Text(widget.category),
      subtitle: Text(
        widget.imageUrl.isEmpty ? tr('بلا صورة') : tr('صورة مضبوطة'),
        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tr('اختيار صورة'),
            icon: const Icon(Icons.upload),
            onPressed: _busy ? null : _pick,
          ),
          if (widget.imageUrl.isNotEmpty)
            IconButton(
              tooltip: tr('إزالة'),
              icon: Icon(Icons.close, color: AppTheme.danger),
              onPressed: _busy ? null : _remove,
            ),
        ],
      ),
    );
  }
}

/// اختيار المنتجات المختارة من بين المنشور في المتجر.
class _FeaturedPicker extends ConsumerWidget {
  const _FeaturedPicker({required this.selected});

  final List<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // المعروض هنا **المنشور في المتجر فقط**: اختيار منتج غير منشور يعني
    // بطاقة مميّزة تشير إلى لا شيء.
    final published =
        ref.watch(inventoryProvider).where((p) => p.publishedToStore).toList();

    if (published.isEmpty) {
      return Text(
        tr('لا منتجات منشورة في المتجر بعد — انشر منتجاً من بطاقته في المخزون.'),
        style: TextStyle(fontSize: 12, color: AppTheme.warning),
      );
    }

    Future<void> toggle(String id, bool on) async {
      final next = [...selected];
      if (on) {
        if (!next.contains(id)) next.add(id);
      } else {
        next.remove(id);
      }
      await ref.read(settingsRepositoryProvider)?.setFeaturedProducts(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          trf('مختار: {0}', [selected.length]),
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final product in published)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(product.id),
                  title: Text(product.name, maxLines: 1),
                  subtitle: Text(
                    product.category,
                    style: const TextStyle(fontSize: 11),
                  ),
                  onChanged: (v) => toggle(product.id, v ?? false),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
