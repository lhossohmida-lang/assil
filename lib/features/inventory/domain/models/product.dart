import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/formatters.dart';

/// منتج في المخزون.
///
/// انتبه للفرق بين ثلاث كميات:
///  - `quantity`          : ما في الرفوف فعلاً.
///  - `reserved`          : محجوز لطلبات المتجر الإلكتروني المؤكَّدة (لم يُشحن بعد).
///  - `availableQuantity` : ما يمكن بيعه في المحل الآن = quantity - reserved.
class Product {
  final String id;
  final String name;
  final String barcode;
  final double purchasePrice;
  final double sellPrice;
  final int quantity;
  final int minQuantity;
  final String category;
  final String supplier;
  final String description;

  /// حقل قديم: كان يحوي صورة base64 كاملة داخل المستند.
  /// نُبقيه للتوافق الرجعي (منتجات قديمة) — لا تحذفه ولا تكتب فيه من جديد.
  final String imageUrl;

  /// روابط Cloudinary. الأولى هي صورة الغلاف.
  final List<String> images;

  /// معرّفات Cloudinary المقابلة — نحتاجها لحذف الصور من Cloudinary لاحقاً.
  final List<String> imagePublicIds;

  final List<String> sizes;
  final List<String> colors;

  /// هل يظهر في المتجر الإلكتروني؟
  final bool publishedToStore;

  final int reserved;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Product({
    required this.id,
    required this.name,
    this.barcode = '',
    this.purchasePrice = 0,
    this.sellPrice = 0,
    this.quantity = 0,
    this.minQuantity = 1,
    this.category = '',
    this.supplier = '',
    this.description = '',
    this.imageUrl = '',
    this.images = const [],
    this.imagePublicIds = const [],
    this.sizes = const [],
    this.colors = const [],
    this.publishedToStore = true,
    this.reserved = 0,
    this.createdAt,
    this.updatedAt,
  });

  int get availableQuantity {
    final v = quantity - reserved;
    return v < 0 ? 0 : v;
  }

  bool get isLowStock => quantity <= minQuantity;

  /// الفائدة على القطعة الواحدة (لا تُعرض في السلة — انظر شاشة نقطة البيع).
  double get unitProfit => sellPrice - purchasePrice;

  /// أول صورة صالحة للعرض: روابط Cloudinary أولاً، ثم الحقل القديم.
  String? get coverImage {
    if (images.isNotEmpty) return images.first;
    if (imageUrl.isNotEmpty) return imageUrl;
    return null;
  }

  /// هل ما زالت صورة هذا المنتج مخزّنة base64 داخل Firestore؟
  /// (تُستعمل في شاشة «ترحيل الصور القديمة»).
  bool get hasLegacyBase64Image =>
      images.isEmpty && imageUrl.startsWith('data:image');

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        name: (m['name'] ?? '') as String,
        barcode: (m['barcode'] ?? '') as String,
        purchasePrice: toDouble(m['purchasePrice']),
        sellPrice: toDouble(m['sellPrice']),
        quantity: toInt(m['quantity']),
        minQuantity: m['minQuantity'] == null ? 1 : toInt(m['minQuantity']),
        category: (m['category'] ?? '') as String,
        supplier: (m['supplier'] ?? '') as String,
        description: (m['description'] ?? '') as String,
        imageUrl: (m['imageUrl'] ?? '') as String,
        images: ((m['images'] ?? const []) as List).cast<String>(),
        imagePublicIds:
            ((m['imagePublicIds'] ?? const []) as List).cast<String>(),
        sizes: ((m['sizes'] ?? const []) as List).cast<String>(),
        colors: ((m['colors'] ?? const []) as List).cast<String>(),
        publishedToStore: (m['publishedToStore'] ?? true) as bool,
        reserved: toInt(m['reserved']),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      );

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Product.fromMap(doc.id, doc.data() ?? const {});

  Map<String, dynamic> toMap() => {
        'name': name,
        'barcode': barcode,
        'purchasePrice': purchasePrice,
        'sellPrice': sellPrice,
        'quantity': quantity,
        'minQuantity': minQuantity,
        'category': category,
        'supplier': supplier,
        'description': description,
        'imageUrl': imageUrl,
        'images': images,
        'imagePublicIds': imagePublicIds,
        'sizes': sizes,
        'colors': colors,
        'publishedToStore': publishedToStore,
        'reserved': reserved,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  /// 🚫 المرآة العامة — يقرأها **أي زائر على الإنترنت** بلا مصادقة.
  ///
  /// ممنوع منعاً باتاً إضافة `purchasePrice` أو `supplier` أو `barcode` هنا:
  /// سعر الشراء يكشف هامش الربح للمنافسين وللزبائن، والمورّد يكشف مصدر
  /// البضاعة، والباركود يسمح بتخمين مخزون المحل.
  ///
  /// إن أضفت حقلاً جديداً للمنتج فلا تُضفه هنا إلا بعد سؤال: «هل أقبل أن
  /// يراه أي شخص في العالم؟». يوجد اختبار يمنع تسرّب هذه الحقول الثلاثة.
  Map<String, dynamic> toPublicMap() => {
        'name': name,
        'description': description,
        'sellPrice': sellPrice,
        'category': category,
        'images': images,
        'sizes': sizes,
        'colors': colors,
        'inStock': availableQuantity > 0,
        'publishedToStore': publishedToStore,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Product copyWith({
    String? id,
    String? name,
    String? barcode,
    double? purchasePrice,
    double? sellPrice,
    int? quantity,
    int? minQuantity,
    String? category,
    String? supplier,
    String? description,
    String? imageUrl,
    List<String>? images,
    List<String>? imagePublicIds,
    List<String>? sizes,
    List<String>? colors,
    bool? publishedToStore,
    int? reserved,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id ?? this.id,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        sellPrice: sellPrice ?? this.sellPrice,
        quantity: quantity ?? this.quantity,
        minQuantity: minQuantity ?? this.minQuantity,
        category: category ?? this.category,
        supplier: supplier ?? this.supplier,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        images: images ?? this.images,
        imagePublicIds: imagePublicIds ?? this.imagePublicIds,
        sizes: sizes ?? this.sizes,
        colors: colors ?? this.colors,
        publishedToStore: publishedToStore ?? this.publishedToStore,
        reserved: reserved ?? this.reserved,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// هل يطابق هذا المنتج نصّ البحث (اسم أو باركود أو جزء منه)؟
  bool matches(String query) {
    final q = normalizeForSearch(query);
    if (q.isEmpty) return true;
    return normalizeForSearch(name).contains(q) ||
        barcode.contains(cleanBarcode(query)) ||
        normalizeForSearch(category).contains(q);
  }
}
