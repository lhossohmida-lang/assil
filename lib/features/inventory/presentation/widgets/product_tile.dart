import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../domain/models/product.dart';
import '../../../../core/i18n/app_strings.dart';

/// بطاقة منتج في قائمة المخزون.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onQuantity,
    required this.onPrintTicket,
    required this.onToggleStore,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onQuantity;
  final VoidCallback onPrintTicket;
  final VoidCallback onToggleStore;

  @override
  Widget build(BuildContext context) {
    final low = product.isLowStock;

    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumb(product: product),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (product.barcode.isNotEmpty)
                      Text(
                        product.barcode,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          money(product.sellPrice),
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        _Badge(
                          text: trf('{0} قطعة', [product.quantity]),
                          color: low ? AppTheme.warning : AppTheme.accent,
                          icon: low ? Icons.warning_amber_rounded : null,
                        ),
                        if (product.reserved > 0)
                          _Badge(
                            text: trf('محجوز {0}', [product.reserved]),
                            color: AppTheme.warning,
                          ),
                        if (!product.publishedToStore)
                          _Badge(
                            text: tr('خارج المتجر'),
                            color: AppTheme.textSecondary,
                          ),
                        if (product.category.isNotEmpty)
                          _Badge(
                            text: product.category,
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: tr('تعديل الكمية'),
                    icon: Icon(Icons.exposure, color: AppTheme.accent),
                    onPressed: onQuantity,
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('المزيد'),
                    onSelected: (v) {
                      switch (v) {
                        case 'ticket':
                          onPrintTicket();
                        case 'store':
                          onToggleStore();
                        case 'edit':
                          onEdit();
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'ticket',
                        child: ListTile(
                          leading: Icon(Icons.local_offer_outlined),
                          title: Text(tr('طباعة تيكت')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text(tr('تعديل المنتج')),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'store',
                        child: ListTile(
                            leading: Icon(
                              product.publishedToStore
                                  ? Icons.storefront_outlined
                                  : Icons.store_mall_directory_outlined,
                            ),
                            title: Text(
                              product.publishedToStore
                                  ? tr('إزالة من المتجر')
                                  : tr('إعادة إلى المتجر'),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final url = product.coverImage;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null || url.startsWith('data:')
            // الصور القديمة base64 لا نعرضها هنا: فكّها لكل بطاقة يُبطئ
            // القائمة كلها. شاشة الترحيل تنقلها إلى Cloudinary.
            ? Container(
                color: Colors.grey.shade200,
                child: Icon(
                  url == null ? Icons.checkroom : Icons.image_outlined,
                  color: Colors.grey.shade500,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
