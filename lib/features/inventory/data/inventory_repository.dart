import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/utils/id_utils.dart';
import '../domain/models/product.dart';

class InventoryRepository {
  InventoryRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> get products => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.products);

  /// المرآة العامة للمتجر الإلكتروني — يقرأها الزوّار بلا مصادقة.
  CollectionReference<Map<String, dynamic>> get publicProducts => _db
      .collection(FirestorePaths.publicCatalog)
      .doc(storeId)
      .collection(FirestorePaths.products);

  CollectionReference<Map<String, dynamic>> get orphanImages => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.orphanImages);

  /// كل المنتجات — الفلترة والترتيب محلياً.
  ///
  /// عمداً بلا `where`/`orderBy` على الخادم: أي تركيب منهما على حقلين
  /// مختلفين يطلب فهرساً مركّباً، وأول ما يحدث ذلك تتوقّف الشاشة عن العمل
  /// عند العميل برسالة إنجليزية غامضة. المخزون بضعة آلاف مستند على الأكثر.
  Stream<List<Product>> watchAll() => products.snapshots().map(
        (s) => s.docs.map(Product.fromDoc).toList(),
      );

  Future<List<Product>> readAll() async =>
      (await products.get()).docs.map(Product.fromDoc).toList();

  /// بحث بالباركود بمطابقة تامة على الخادم — أسرع طريق في نقطة البيع.
  Future<Product?> findByBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    final snap =
        await products.where('barcode', isEqualTo: clean).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Product.fromDoc(snap.docs.first);
  }

  Future<bool> barcodeExists(String barcode, {String? exceptId}) async {
    final snap =
        await products.where('barcode', isEqualTo: barcode).limit(2).get();
    return snap.docs.any((d) => d.id != exceptId);
  }

  /// باركود عشوائي فريد — يعيد المحاولة حتى يجد رقماً غير مستعمل.
  Future<String> generateUniqueBarcode() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final candidate =
          randomNumericBarcode(AppConstants.generatedBarcodeLength);
      if (!await barcodeExists(candidate)) return candidate;
    }
    // احتمال بعيد جداً: نضيف طابعاً زمنياً لضمان التفرّد.
    return '${DateTime.now().millisecondsSinceEpoch}'.substring(5);
  }

  /// يطبّق قرار المرآة على دفعة كتابة قائمة.
  ///
  /// **يُنادى من كل مسار يكتب منتجاً بلا استثناء** (إضافة، تعديل، استيراد،
  /// تعديل كمية). لو نسيه مسار واحد بقيت المرآة تعرض
  /// منتجاً محذوفاً أو سعراً قديماً للزبائن.
  void applyMirror(WriteBatch batch, Product p) {
    final ref = publicProducts.doc(p.id);
    if (p.publishedToStore) {
      batch.set(ref, p.toPublicMap());
    } else {
      // غير منشور ⇒ يختفي من المتجر فوراً.
      batch.delete(ref);
    }
  }

  Future<String> addProduct(Product p) async {
    final ref = products.doc();
    final withId = p.copyWith(id: ref.id);
    final batch = _db.batch();
    batch.set(ref, withId.toMap());
    applyMirror(batch, withId);
    await batch.commit();
    return ref.id;
  }

  Future<void> updateProduct(
    Product p, {
    List<String> removedPublicIds = const [],
  }) async {
    final batch = _db.batch();
    batch.set(products.doc(p.id), p.toMap(), SetOptions(merge: true));
    applyMirror(batch, p);
    _recordOrphans(batch, removedPublicIds);
    await batch.commit();
  }

  /// حذف منتج: المستند + مرآته + تسجيل صوره كأيتام لتنظيفها من Cloudinary.
  Future<void> deleteProduct(Product p) async {
    final batch = _db.batch();
    batch.delete(products.doc(p.id));
    batch.delete(publicProducts.doc(p.id));
    _recordOrphans(batch, p.imagePublicIds);
    await batch.commit();
  }

  /// صور لم يعد يشير إليها أي منتج.
  ///
  /// لا نحذفها من Cloudinary من التطبيق: الحذف يتطلب مفتاح إدارة، ووضع
  /// مفتاح إدارة في تطبيق العميل يعني تسليمه لكل من يفكّ الـ APK.
  /// تُنظَّف يدوياً من لوحة Cloudinary اعتماداً على هذه القائمة.
  void _recordOrphans(WriteBatch batch, List<String> publicIds) {
    for (final id in publicIds) {
      if (id.isEmpty) continue;
      batch.set(orphanImages.doc(), {
        'publicId': id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// تعديل الكمية بمقدار (± ) مع تحديث المرآة (`inStock` قد يتبدّل).
  Future<void> adjustQuantity(Product p, int delta) async {
    final next = (p.quantity + delta).clamp(0, 1 << 31);
    final updated = p.copyWith(quantity: next);
    final batch = _db.batch();
    batch.update(products.doc(p.id), {
      'quantity': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    applyMirror(batch, updated);
    await batch.commit();
  }

  Future<void> setQuantity(Product p, int quantity) =>
      adjustQuantity(p, quantity - p.quantity);

  /// إزالة/إعادة منتج إلى المتجر الإلكتروني — **لا يمسّ المخزون إطلاقاً**.
  Future<void> setPublished(Product p, bool published) async {
    final updated = p.copyWith(publishedToStore: published);
    final batch = _db.batch();
    batch.update(products.doc(p.id), {
      'publishedToStore': published,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    applyMirror(batch, updated);
    await batch.commit();
  }

  /// إعادة بناء المرآة كاملةً من المخزون الحقيقي.
  ///
  /// تُستعمل بعد أي شكّ في التزامن (تعديل يدوي من لوحة Firebase مثلاً).
  /// ترجع عدد المنتجات المنشورة.
  Future<int> rebuildCatalog({void Function(int done, int total)? onProgress}) async {
    final all = await readAll();
    final existing = (await publicProducts.get()).docs.map((d) => d.id).toSet();

    var published = 0;
    var batch = _db.batch();
    var ops = 0;
    var done = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final p in all) {
      applyMirror(batch, p);
      if (p.publishedToStore) published++;
      existing.remove(p.id);
      ops++;
      done++;
      onProgress?.call(done, all.length);
      if (ops >= AppConstants.batchLimit) await flush();
    }

    // مستندات في المرآة لا يقابلها منتج (حُذف من لوحة Firebase مثلاً).
    for (final staleId in existing) {
      batch.delete(publicProducts.doc(staleId));
      ops++;
      if (ops >= AppConstants.batchLimit) await flush();
    }
    await flush();
    return published;
  }

  /// تفريغ المتجر الإلكتروني بالكامل — **المخزون لا يُمسّ**.
  Future<int> clearCatalog() async {
    final docs = (await publicProducts.get()).docs;
    var batch = _db.batch();
    var ops = 0;
    for (final d in docs) {
      batch.delete(d.reference);
      ops++;
      if (ops >= AppConstants.batchLimit) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return docs.length;
  }
}
