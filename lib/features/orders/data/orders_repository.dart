import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../inventory/domain/models/product.dart';
import '../domain/models/public_order.dart';

class OrdersRepository {
  OrdersRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> get orders => _db
      .collection(FirestorePaths.publicOrders)
      .doc(storeId)
      .collection('orders');

  CollectionReference<Map<String, dynamic>> get products => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.products);

  CollectionReference<Map<String, dynamic>> get publicProducts => _db
      .collection(FirestorePaths.publicCatalog)
      .doc(storeId)
      .collection(FirestorePaths.products);

  Stream<List<PublicOrder>> watchAll() => orders.snapshots().map((s) {
        final list = s.docs.map(PublicOrder.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// تأكيد الطلب: **حجز** الكمية بمعاملة ذرّية.
  ///
  /// الحجز يزيد `reserved` ولا يُنقص `quantity`: البضاعة ما زالت في
  /// الرفوف حتى الشحن، لكنها لم تعد متاحة للبيع في المحل ولا في المتجر.
  /// المعاملة تمنع حجز قطعة بيعت لتوّها من نقطة البيع.
  Future<void> confirm(PublicOrder order) async {
    await _db.runTransaction((tx) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      // كل القراءات أولاً — Firestore يشترط ذلك داخل المعاملة.
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        snapshots[item.productId] =
            await tx.get(products.doc(item.productId));
      }

      for (final item in order.items) {
        final snap = snapshots[item.productId];
        if (snap == null || !snap.exists) continue;

        final product = Product.fromMap(snap.id, snap.data() ?? const {});
        if (product.availableQuantity < item.quantity) {
          throw Exception(
            'الكمية غير كافية من «${product.name}»: '
            'المتاح ${product.availableQuantity} والمطلوب ${item.quantity}',
          );
        }

        final after = product.copyWith(
          reserved: product.reserved + item.quantity,
        );
        tx.update(snap.reference, {
          'reserved': after.reserved,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _mirror(tx, after);
      }

      tx.update(orders.doc(order.id), {
        'status': OrderStatus.confirmed.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// الشحن: البضاعة تخرج فعلاً — يُنقص `quantity` ويُحرَّر `reserved`.
  Future<void> ship(PublicOrder order) async {
    await _db.runTransaction((tx) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final item in order.items) {
        if (item.productId.isEmpty) continue;
        snapshots[item.productId] =
            await tx.get(products.doc(item.productId));
      }

      for (final item in order.items) {
        final snap = snapshots[item.productId];
        if (snap == null || !snap.exists) continue;

        final product = Product.fromMap(snap.id, snap.data() ?? const {});
        final after = product.copyWith(
          quantity: (product.quantity - item.quantity).clamp(0, 1 << 31),
          reserved: (product.reserved - item.quantity).clamp(0, 1 << 31),
        );
        tx.update(snap.reference, {
          'quantity': after.quantity,
          'reserved': after.reserved,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _mirror(tx, after);
      }

      tx.update(orders.doc(order.id), {
        'status': OrderStatus.shipped.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markDelivered(PublicOrder order) =>
      orders.doc(order.id).update({
        'status': OrderStatus.delivered.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// الإلغاء يحرّر المحجوز — لكن فقط إن كان الطلب قد حُجز أصلاً.
  Future<void> cancel(PublicOrder order) async {
    final wasReserved = order.status == OrderStatus.confirmed;

    await _db.runTransaction((tx) async {
      if (wasReserved) {
        final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final item in order.items) {
          if (item.productId.isEmpty) continue;
          snapshots[item.productId] =
              await tx.get(products.doc(item.productId));
        }

        for (final item in order.items) {
          final snap = snapshots[item.productId];
          if (snap == null || !snap.exists) continue;

          final product = Product.fromMap(snap.id, snap.data() ?? const {});
          final after = product.copyWith(
            reserved: (product.reserved - item.quantity).clamp(0, 1 << 31),
          );
          tx.update(snap.reference, {
            'reserved': after.reserved,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          _mirror(tx, after);
        }
      }

      tx.update(orders.doc(order.id), {
        'status': OrderStatus.cancelled.code,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> delete(String orderId) => orders.doc(orderId).delete();

  void _mirror(Transaction tx, Product product) {
    final ref = publicProducts.doc(product.id);
    if (product.publishedToStore) {
      tx.set(ref, product.toPublicMap());
    } else {
      tx.delete(ref);
    }
  }
}
