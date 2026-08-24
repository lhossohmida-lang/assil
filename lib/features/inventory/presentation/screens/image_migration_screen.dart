import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/services/cloudinary_service.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../domain/models/product.dart';
import '../providers/inventory_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// ترحيل الصور القديمة من base64 داخل Firestore إلى Cloudinary.
///
/// النسخ الأولى من التطبيق كانت تخزّن الصورة كاملةً نصّاً داخل مستند
/// المنتج. النتيجة: مستندات بمئات الكيلوبايتات تُبطئ كل قراءة للمخزون،
/// وتقترب من حدّ Firestore (1 ميغابايت للمستند).
class ImageMigrationScreen extends ConsumerStatefulWidget {
  const ImageMigrationScreen({super.key});

  @override
  ConsumerState<ImageMigrationScreen> createState() =>
      _ImageMigrationScreenState();
}

class _ImageMigrationScreenState
    extends ConsumerState<ImageMigrationScreen> {
  bool _running = false;
  int _done = 0;
  int _failed = 0;
  final List<String> _errors = [];

  List<Product> _legacy(List<Product> all) =>
      all.where((p) => p.hasLegacyBase64Image).toList();

  Future<void> _migrate(List<Product> products) async {
    final repo = ref.read(inventoryRepositoryProvider);
    if (repo == null) return;

    if (!AppConstants.isCloudinaryConfigured) {
      showErr(
        context,
        tr('رفع الصور غير مهيّأ — املأ إعدادات Cloudinary في app_constants.dart'),
      );
      return;
    }

    setState(() {
      _running = true;
      _done = 0;
      _failed = 0;
      _errors.clear();
    });

    const service = CloudinaryService();

    for (final product in products) {
      try {
        final bytes = _decodeDataUrl(product.imageUrl);
        if (bytes == null) {
          throw FormatException(tr('الصورة ليست بصيغة base64 صالحة'));
        }

        final uploaded = await service.upload(bytes, filename: '${product.id}.jpg');

        await repo.updateProduct(
          product.copyWith(
            images: [uploaded.url, ...product.images],
            imagePublicIds: [uploaded.publicId, ...product.imagePublicIds],
            // نُفرغ الحقل القديم: هو سبب تضخّم المستند.
            imageUrl: '',
          ),
        );
        if (mounted) setState(() => _done++);
      } catch (e) {
        if (mounted) {
          setState(() {
            _failed++;
            _errors.add('${product.name}: $e');
          });
        }
      }
    }

    if (mounted) setState(() => _running = false);
  }

  /// `data:image/jpeg;base64,XXXX` → بايتات.
  static Uint8List? _decodeDataUrl(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex < 0) return null;
    try {
      return base64Decode(dataUrl.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allProductsProvider).value ?? const <Product>[];
    final legacy = _legacy(all);

    return Scaffold(
      appBar: AppBar(title: Text(tr('ترحيل الصور القديمة'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trf('{0} منتجاً ما زالت صوره مخزّنة داخل قاعدة البيانات', [legacy.length]),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('الصور المخزّنة كنصّ base64 تُضخّم مستندات المنتجات وتُبطئ فتح المخزون. الترحيل يرفعها إلى Cloudinary ويترك رابطاً فقط.'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_running) ...[
                    LinearProgressIndicator(
                      value: legacy.isEmpty
                          ? null
                          : (_done + _failed) / legacy.length,
                    ),
                    const SizedBox(height: 8),
                    Text(trf('رُحّل {0} · فشل {1}', [_done, _failed])),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            legacy.isEmpty ? null : () => _migrate(legacy),
                        icon: const Icon(Icons.cloud_upload),
                        label: Text(
                          legacy.isEmpty
                              ? tr('لا صور تحتاج ترحيلاً')
                              : trf('ابدأ ترحيل {0} صورة', [legacy.length]),
                        ),
                      ),
                    ),
                  if (!_running && (_done > 0 || _failed > 0)) ...[
                    const Divider(height: 24),
                    Text(
                      trf('انتهى: رُحّل {0}، فشل {1}', [_done, _failed]),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            _failed == 0 ? AppTheme.success : AppTheme.warning,
                      ),
                    ),
                    for (final error in _errors.take(20))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          error,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.danger,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final product in legacy.take(50))
            Card(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.image_outlined),
                title: Text(product.name),
                subtitle: Text(
                  trf('حجم النصّ {0} ك.ب', [(product.imageUrl.length / 1024).round()]),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
