import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../cashbox/domain/models/cashbox_transaction.dart';
import '../../customers/domain/models/customer.dart';
import '../../inventory/domain/models/product.dart';
import '../../sales/data/sales_repository.dart';
import '../../sales/domain/models/sale.dart';
import '../domain/models/reservation.dart';

/// السلال المعلّقة والحجوزات (الفارسمون) وحسابات الكريدي.
class PosRepository {
  PosRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(FirestorePaths.stores).doc(storeId).collection(name);

  CollectionReference<Map<String, dynamic>> get heldCarts =>
      _col(FirestorePaths.heldCarts);
  CollectionReference<Map<String, dynamic>> get reservations =>
      _col(FirestorePaths.reservations);
  CollectionReference<Map<String, dynamic>> get creditAccounts =>
      _col(FirestorePaths.creditAccounts);
  CollectionReference<Map<String, dynamic>> get products =>
      _col(FirestorePaths.products);
  CollectionReference<Map<String, dynamic>> get cashbox =>
      _col(FirestorePaths.cashboxTransactions);

  CollectionReference<Map<String, dynamic>> get publicProducts => _db
      .collection(FirestorePaths.publicCatalog)
      .doc(storeId)
      .collection(FirestorePaths.products);

  // ───────────────────────── سلال الانتظار ─────────────────────────

  Stream<List<HeldCart>> watchHeldCarts() => heldCarts.snapshots().map((s) {
        final list = s.docs.map(HeldCart.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  Future<void> holdCart(HeldCart cart) => heldCarts.add(cart.toMap());

  Future<void> removeHeldCart(String id) => heldCarts.doc(id).delete();

  // ───────────────────────── الفارسمون ─────────────────────────

  Stream<List<Reservation>> watchReservations() =>
      reservations.snapshots().map((s) {
        final list = s.docs.map(Reservation.fromDoc).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(0))
            .compareTo(a.createdAt ?? DateTime(0)));
        return list;
      });

  /// إنشاء حجز: البضاعة تخرج من المخزون فوراً (موضوعة جانباً للزبونة)،
  /// والعربون يدخل الصندوق.
  Future<void> createReservation(
    Reservation reservation, {
    required Map<String, Product> productLookup,
  }) async {
    final batch = _db.batch();
    final ref = reservations.doc();
    batch.set(ref, reservation.toMap());

    for (final item in reservation.items) {
      if (item.productId.isEmpty) continue;
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(-item.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _mirror(batch, productLookup[item.productId], -item.quantity);
    }

    if (reservation.deposit > 0) {
      batch.set(cashbox.doc(), {
        'type': CashboxType.income.code,
        'amount': reservation.deposit,
        'note': 'عربون فارسمون — ${reservation.customerName}',
        'saleId': '',
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': reservation.createdBy,
        'createdByName': reservation.createdByName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// إكمال الحجز: يتحوّل إلى فاتورة، ويدخل **الباقي فقط** الصندوق
  /// (العربون دخل يوم الحجز — تسجيله ثانيةً يضاعف الدخل).
  ///
  /// المخزون **لا يُنقص هنا**: نقص يوم الحجز.
  Future<Sale> completeReservation(
    Reservation reservation, {
    required Actor actor,
    required String saleId,
  }) async {
    final sale = Sale(
      id: saleId,
      items: reservation.items,
      subtotal: reservation.items.fold(0.0, (acc, i) => acc + i.lineTotal),
      discount: 0,
      total: reservation.total,
      paymentMethod: PaymentMethod.reservation,
      paidAmount: reservation.total,
      customerName: reservation.customerName,
      createdBy: actor.uid,
      createdByName: actor.name,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(_col(FirestorePaths.sales).doc(saleId), sale.toMap());
    batch.update(reservations.doc(reservation.id), {
      'status': ReservationStatus.completed.code,
      'saleId': saleId,
      'closedAt': FieldValue.serverTimestamp(),
    });

    if (reservation.remaining > 0) {
      batch.set(cashbox.doc(), {
        'type': CashboxType.income.code,
        'amount': reservation.remaining,
        'note': 'إكمال فارسمون ${sale.invoiceNumber} — '
            '${reservation.customerName}',
        'saleId': saleId,
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': actor.uid,
        'createdByName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return sale;
  }

  /// إلغاء الحجز: البضاعة تعود للمخزون.
  /// `refundDeposit` يسجّل إرجاع العربون مصروفاً.
  Future<void> cancelReservation(
    Reservation reservation, {
    required Map<String, Product> productLookup,
    required Actor actor,
    bool refundDeposit = false,
  }) async {
    final batch = _db.batch();

    for (final item in reservation.items) {
      if (item.productId.isEmpty) continue;
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(item.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _mirror(batch, productLookup[item.productId], item.quantity);
    }

    batch.update(reservations.doc(reservation.id), {
      'status': ReservationStatus.cancelled.code,
      'closedAt': FieldValue.serverTimestamp(),
    });

    if (refundDeposit && reservation.deposit > 0) {
      batch.set(cashbox.doc(), {
        'type': CashboxType.expense.code,
        'amount': reservation.deposit,
        'note': 'إرجاع عربون فارسمون — ${reservation.customerName}',
        'saleId': '',
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': actor.uid,
        'createdByName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteReservation(String id) => reservations.doc(id).delete();

  // ───────────────────────── الكريديات ─────────────────────────

  Stream<List<CreditAccount>> watchCreditAccounts() =>
      creditAccounts.snapshots().map((s) {
        final list = s.docs.map(CreditAccount.fromDoc).toList();
        // غير المسدَّد أولاً، ثم الأحدث.
        list.sort((a, b) {
          if (a.isSettled != b.isSettled) return a.isSettled ? 1 : -1;
          return (b.updatedAt ?? b.createdAt ?? DateTime(0))
              .compareTo(a.updatedAt ?? a.createdAt ?? DateTime(0));
        });
        return list;
      });

  /// دفعة سداد: تدخل الصندوق وتُنقص الذمّة.
  Future<void> addCreditPayment(
    CreditAccount account,
    double amount, {
    required Actor actor,
    String note = '',
  }) async {
    if (amount <= 0) return;
    final payment = CreditPayment(
      amount: amount,
      at: DateTime.now(),
      note: note,
      byName: actor.name,
    );

    final batch = _db.batch();
    batch.update(creditAccounts.doc(account.id), {
      'totalPaid': FieldValue.increment(amount),
      'payments': FieldValue.arrayUnion([payment.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(cashbox.doc(), {
      'type': CashboxType.income.code,
      'amount': amount,
      'note': 'سداد كريدي — ${account.customerName}',
      'saleId': '',
      'accountId': '',
      'accountName': '',
      'recipientId': '',
      'recipientName': '',
      'createdBy': actor.uid,
      'createdByName': actor.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> deleteCreditAccount(String id) =>
      creditAccounts.doc(id).delete();

  /// حساب كريدي موجود بنفس الاسم — حتى لا تتكرّر الزبونة الواحدة.
  Future<String> findOrCreateCreditAccount(String name, String phone) async {
    final snap = await creditAccounts
        .where('customerName', isEqualTo: name.trim())
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return snap.docs.first.id;
    final ref = creditAccounts.doc();
    await ref.set({
      'customerName': name.trim(),
      'phone': phone,
      'totalDebt': 0,
      'totalPaid': 0,
      'payments': <Map<String, dynamic>>[],
      'saleIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  void _mirror(WriteBatch batch, Product? product, int delta) {
    if (product == null) return;
    final after = product.copyWith(
      quantity: (product.quantity + delta).clamp(0, 1 << 31),
    );
    if (after.publishedToStore) {
      batch.set(publicProducts.doc(product.id), after.toPublicMap());
    } else {
      batch.delete(publicProducts.doc(product.id));
    }
  }
}
