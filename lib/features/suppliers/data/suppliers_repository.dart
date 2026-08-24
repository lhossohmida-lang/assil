import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../cashbox/domain/models/cashbox_transaction.dart';
import '../../inventory/domain/models/product.dart';
import '../../sales/data/sales_repository.dart' show Actor;
import '../domain/models/purchase.dart';
import '../domain/models/supplier.dart';

class SuppliersRepository {
  SuppliersRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(FirestorePaths.stores).doc(storeId).collection(name);

  CollectionReference<Map<String, dynamic>> get suppliers =>
      _col(FirestorePaths.suppliers);
  CollectionReference<Map<String, dynamic>> get purchases =>
      _col(FirestorePaths.purchases);
  CollectionReference<Map<String, dynamic>> get products =>
      _col(FirestorePaths.products);
  CollectionReference<Map<String, dynamic>> get cashbox =>
      _col(FirestorePaths.cashboxTransactions);

  CollectionReference<Map<String, dynamic>> get publicProducts => _db
      .collection(FirestorePaths.publicCatalog)
      .doc(storeId)
      .collection(FirestorePaths.products);

  // ───────────────────────── الموردون ─────────────────────────

  Stream<List<Supplier>> watchSuppliers() => suppliers.snapshots().map((s) {
        final list = s.docs.map(Supplier.fromDoc).toList();
        // غير المسدَّد أولاً ثم بالاسم — ما عليك دفعه يستحقّ الصدارة.
        list.sort((a, b) {
          if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
          return a.name.compareTo(b.name);
        });
        return list;
      });

  Future<String> saveSupplier(Supplier s) async {
    if (s.id.isEmpty) {
      final ref = suppliers.doc();
      await ref.set(s.toMap());
      return ref.id;
    }
    await suppliers.doc(s.id).set(s.toMap(), SetOptions(merge: true));
    return s.id;
  }

  Future<void> deleteSupplier(String id) => suppliers.doc(id).delete();

  /// يبحث عن مورّد بالاسم أو يُنشئه — يمنع تكرار المورّد الواحد.
  Future<Supplier> findOrCreateSupplier(String name, {String phone = ''}) async {
    final snap =
        await suppliers.where('name', isEqualTo: name.trim()).limit(1).get();
    if (snap.docs.isNotEmpty) return Supplier.fromDoc(snap.docs.first);

    final ref = suppliers.doc();
    final supplier = Supplier(id: ref.id, name: name.trim(), phone: phone);
    await ref.set(supplier.toMap());
    return supplier;
  }

  // ───────────────────────── المشتريات ─────────────────────────

  Stream<List<Purchase>> watchPurchases() => purchases.snapshots().map((s) {
        final list = s.docs.map(Purchase.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// مشتريات مورّد بعينه — بلا `orderBy` مع الـ `where` (فهرس مركّب).
  Stream<List<Purchase>> watchPurchasesOf(String supplierId) => purchases
      .where('supplierId', isEqualTo: supplierId)
      .snapshots()
      .map((s) {
        final list = s.docs.map(Purchase.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// حركات الصندوق المرتبطة بمورّد (الشراء والدفعات).
  Stream<List<CashboxTransaction>> watchSupplierTransactions(
    String supplierId,
  ) =>
      cashbox.where('supplierId', isEqualTo: supplierId).snapshots().map((s) {
        final list = s.docs.map(CashboxTransaction.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// يسجّل فاتورة شراء بأثرها كاملاً في دفعة واحدة.
  ///
  /// الأثر:
  ///  1. مستند الفاتورة.
  ///  2. **زيادة كمية كل منتج وتحديث سعر شرائه** إلى السعر الجديد.
  ///     الفواتير القديمة لا تتأثّر: كل `SaleItem` يحمل سعر الشراء وقت
  ///     بيعه، فتبقى أرباح الماضي كما حُسبت، وتُحسب أرباح المستقبل
  ///     بالسعر الجديد.
  ///  3. رصيد المورّد (المشتريات والمدفوع).
  ///  4. حركة صندوق من نوع **purchase** — تُنقص النقد ولا تُعدّ مصروفاً.
  Future<void> commitPurchase(
    Purchase purchase, {
    required Map<String, Product> productLookup,
    required Actor actor,
  }) async {
    final batch = _db.batch();
    final ref = purchases.doc(purchase.id);
    batch.set(ref, purchase.toMap());

    for (final item in purchase.items) {
      if (item.productId.isEmpty) continue;

      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(item.quantity),
        'purchasePrice': item.unitCost,
        if (item.newSellPrice != null) 'sellPrice': item.newSellPrice,
        'supplier': purchase.supplierName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final p = productLookup[item.productId];
      if (p != null) {
        final after = p.copyWith(
          quantity: p.quantity + item.quantity,
          purchasePrice: item.unitCost,
          sellPrice: item.newSellPrice ?? p.sellPrice,
          supplier: purchase.supplierName,
        );
        if (after.publishedToStore) {
          batch.set(publicProducts.doc(p.id), after.toPublicMap());
        } else {
          batch.delete(publicProducts.doc(p.id));
        }
      }
    }

    if (purchase.supplierId.isNotEmpty) {
      batch.set(
        suppliers.doc(purchase.supplierId),
        {
          'name': purchase.supplierName,
          'totalPurchases': FieldValue.increment(purchase.total),
          'totalPaid': FieldValue.increment(purchase.paidAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    if (purchase.paidAmount > 0) {
      batch.set(cashbox.doc(), {
        'type': CashboxType.purchase.code,
        'amount': purchase.paidAmount,
        'note': 'شراء ${purchase.invoiceNumber} — ${purchase.supplierName}',
        'saleId': '',
        'accountId': '',
        'accountName': '',
        'supplierId': purchase.supplierId,
        'supplierName': purchase.supplierName,
        'purchaseId': purchase.id,
        'recipientId': '',
        'recipientName': '',
        'createdBy': actor.uid,
        'createdByName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// دفعة لمورّد على حسابه (خارج فاتورة معيّنة).
  Future<void> paySupplier(
    Supplier supplier,
    double amount, {
    required Actor actor,
    String note = '',
  }) async {
    if (amount <= 0) return;

    final batch = _db.batch();
    batch.set(
      suppliers.doc(supplier.id),
      {
        'totalPaid': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(cashbox.doc(), {
      'type': CashboxType.purchase.code,
      'amount': amount,
      'note': note.isEmpty ? 'دفعة للمورّد ${supplier.name}' : note,
      'saleId': '',
      'accountId': '',
      'accountName': '',
      'supplierId': supplier.id,
      'supplierName': supplier.name,
      'purchaseId': '',
      'recipientId': '',
      'recipientName': '',
      'createdBy': actor.uid,
      'createdByName': actor.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// حذف فاتورة شراء: تُعاد الكميات وتُصحَّح أرصدة المورّد وتُحذف حركته.
  ///
  /// ⚠️ **سعر الشراء لا يُعاد** إلى قيمته السابقة تلقائياً: قد تكون فواتير
  /// شراء أحدث غيّرته بعدها، فإرجاعه يفسد سعراً صحيحاً. يُعدَّل يدوياً من
  /// بطاقة المنتج إن لزم.
  Future<void> deletePurchase(
    Purchase purchase, {
    Map<String, Product> productLookup = const {},
  }) async {
    // القراءات قبل الدفعة (الاستعلام داخل batch لا يعمل على الويب).
    final linked =
        await cashbox.where('purchaseId', isEqualTo: purchase.id).get();

    final batch = _db.batch();

    for (final item in purchase.items) {
      if (item.productId.isEmpty) continue;
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(-item.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final p = productLookup[item.productId];
      if (p != null) {
        final after = p.copyWith(
          quantity: (p.quantity - item.quantity).clamp(0, 1 << 31),
        );
        if (after.publishedToStore) {
          batch.set(publicProducts.doc(p.id), after.toPublicMap());
        } else {
          batch.delete(publicProducts.doc(p.id));
        }
      }
    }

    if (purchase.supplierId.isNotEmpty) {
      batch.set(
        suppliers.doc(purchase.supplierId),
        {
          'totalPurchases': FieldValue.increment(-purchase.total),
          'totalPaid': FieldValue.increment(-purchase.paidAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    for (final doc in linked.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(purchases.doc(purchase.id));
    await batch.commit();
  }

  String newPurchaseId() => purchases.doc().id;
}
