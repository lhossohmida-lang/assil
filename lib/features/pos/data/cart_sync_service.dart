import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/device_id.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../inventory/domain/models/product.dart';
import '../../inventory/presentation/providers/inventory_providers.dart';
import '../presentation/providers/cart_provider.dart';

/// مزامنة السلة بين الهاتف والحاسوب عبر مستند واحد.
///
/// البائع يمسح القطع بهاتفه وهو واقف عند الرفوف، فتظهر في سلة الحاسوب
/// عند الطاولة — أو العكس.
class CartSyncService {
  CartSyncService(this._ref, this._db, this.storeId);

  final Ref _ref;
  final FirebaseFirestore _db;
  final String storeId;

  DocumentReference<Map<String, dynamic>> get _doc => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.posSync)
      .doc(FirestorePaths.sharedCartDoc);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _debounce;

  /// حارس ضدّ الحلقة اللانهائية: أثناء تطبيق سلة قادمة من جهاز آخر
  /// لا ننشر التغيير مرة أخرى، وإلا تبادل الجهازان النشر إلى ما لا نهاية.
  bool _applyingRemote = false;

  void start() {
    _sub?.cancel();
    _sub = _doc.snapshots().listen(_onRemote, onError: (Object e) {
      debugPrint('[KMSAN] مزامنة السلة: $e');
    });

    _ref.listen<CartState>(cartProvider, (_, next) {
      if (_applyingRemote) return;
      _schedulePublish(next);
    });
  }

  /// نشر بعد **200 مللي ثانية** من آخر تعديل.
  ///
  /// بلا التأخير كانت كل ضغطة على «+» تكتب مستنداً كاملاً — عشرات
  /// الكتابات في الثانية أثناء تعديل الكميات.
  void _schedulePublish(CartState cart) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _publish(cart));
  }

  Future<void> _publish(CartState cart) async {
    try {
      await _doc.set({
        ...cart.toSyncMap(),
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // وضع عدم الاتصال أمر طبيعي في المحل — لا نُزعج البائع برسالة خطأ،
      // فالبيع نفسه يعمل محلياً و Firestore يُزامن لاحقاً.
      debugPrint('[KMSAN] تعذّر نشر السلة: $e');
    }
  }

  void _onRemote(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return;

    // ما أرسلناه نحن يعود إلينا — نتجاهله.
    if ((data['deviceId'] ?? '') == deviceId) return;

    // سلة منسيّة من الأمس: لا نُعيد ملء شاشة البائع ببضاعة قديمة.
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    if (updatedAt != null &&
        DateTime.now().difference(updatedAt) > const Duration(hours: 12)) {
      return;
    }

    final inventory = <String, Product>{
      for (final p in _ref.read(inventoryProvider)) p.id: p,
    };

    _applyingRemote = true;
    try {
      _ref
          .read(cartProvider.notifier)
          .replaceAll(CartState.fromSyncMap(data, inventory));
    } finally {
      _applyingRemote = false;
    }
  }

  /// تفريغ السلة المشتركة بعد إتمام البيع.
  Future<void> clearShared() async {
    try {
      await _doc.set({
        'lines': <Map<String, dynamic>>[],
        'discount': 0,
        'customerName': '',
        'customerId': '',
        'isVip': false,
        'deviceId': deviceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[KMSAN] تعذّر تفريغ السلة المشتركة: $e');
    }
  }

  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
  }
}

/// تفعيل المزامنة — تُراقَب من شاشة نقطة البيع فقط.
final cartSyncProvider = Provider<CartSyncService?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;

  final service = CartSyncService(ref, ref.watch(firestoreProvider), storeId);
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
