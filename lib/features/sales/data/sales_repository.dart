import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../cashbox/domain/models/cashbox_transaction.dart';
import '../../customers/domain/models/customer.dart';
import '../../inventory/domain/models/product.dart';
import '../domain/models/sale.dart';

/// من نفّذ العملية — يُرفق بكل فاتورة وحركة صندوق.
class Actor {
  const Actor(this.uid, this.name);
  final String uid;
  final String name;
  static const Actor unknown = Actor('', '');
}

class SalesRepository {
  SalesRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection(FirestorePaths.stores).doc(storeId).collection(name);

  CollectionReference<Map<String, dynamic>> get sales =>
      _col(FirestorePaths.sales);
  CollectionReference<Map<String, dynamic>> get cashbox =>
      _col(FirestorePaths.cashboxTransactions);
  CollectionReference<Map<String, dynamic>> get products =>
      _col(FirestorePaths.products);
  CollectionReference<Map<String, dynamic>> get customers =>
      _col(FirestorePaths.customers);
  CollectionReference<Map<String, dynamic>> get creditAccounts =>
      _col(FirestorePaths.creditAccounts);

  CollectionReference<Map<String, dynamic>> get publicProducts => _db
      .collection(FirestorePaths.publicCatalog)
      .doc(storeId)
      .collection(FirestorePaths.products);

  /// يولّد فاتورة **بمعرّف جاهز قبل الكتابة**.
  ///
  /// هذا ما يجعل البيع «متفائلاً»: نعرف رقم الفاتورة فوراً فنطبع الوصل
  /// ونعرض النجاح للبائع بينما الكتابة ما زالت في طريقها إلى الخادم.
  Sale newSale({
    required List<SaleItem> items,
    required double discount,
    required double vipDiscount,
    required PaymentMethod paymentMethod,
    required Actor actor,
    double? paidAmount,
    String customerName = '',
    String customerId = '',
    bool isVip = false,
  }) {
    final subtotal = items.fold<double>(0, (acc, i) => acc + i.lineTotal);
    final total = (subtotal - discount - vipDiscount).clamp(0, double.infinity);
    return Sale(
      id: sales.doc().id,
      items: items,
      subtotal: subtotal,
      discount: discount,
      vipDiscount: vipDiscount,
      total: total.toDouble(),
      paymentMethod: paymentMethod,
      paidAmount: paidAmount ?? total.toDouble(),
      customerName: customerName.trim(),
      customerId: customerId,
      isVip: isVip,
      createdBy: actor.uid,
      createdByName: actor.name,
      createdAt: DateTime.now(),
    );
  }

  /// يكتب الفاتورة وأثرها كاملاً في دفعة واحدة.
  ///
  /// الأثر: نقص المخزون + تحديث مرآة المتجر + دخل في الصندوق مربوط
  /// بـ saleId + حساب الكريدي إن وُجد + بطاقة الزبونة إن ذُكر اسمها.
  Future<void> commitSale(
    Sale sale, {
    required Map<String, Product> productLookup,
    String creditAccountId = '',
    String creditPhone = '',
  }) async {
    final batch = _db.batch();

    batch.set(sales.doc(sale.id), sale.toMap());

    for (final item in sale.items) {
      if (item.productId.isEmpty) continue;

      // increment ذرّي: لو باع الهاتف والحاسوب نفس القطعة في اللحظة نفسها
      // فالنقص يُطبَّق مرّتين بشكل صحيح. قراءة ثم كتابة كانت ستُضيّع واحدة.
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(-item.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // المرآة العامة تُحدَّث من معرفتنا المحلية بالكمية. قد تتأخّر لحظة
      // عن الرقم الحقيقي، وهذا مقبول: «مزامنة المتجر» تصحّح أي انحراف،
      // والخطأ الوحيد الممكن هو ظهور «متوفّر» لدقيقة بعد نفاد القطعة.
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

    // الدخل = ما قُبض فعلاً. في الكريدي هذا أقلّ من إجمالي الفاتورة.
    if (sale.paidAmount > 0) {
      batch.set(cashbox.doc(), {
        'type': CashboxType.income.code,
        'amount': sale.paidAmount,
        'note': 'بيع ${sale.invoiceNumber}',
        'saleId': sale.id,
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': sale.createdBy,
        'createdByName': sale.createdByName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // كريدي: الباقي يُضاف إلى ذمّة الزبونة.
    if (sale.paymentMethod == PaymentMethod.credit && sale.remaining > 0) {
      final ref = creditAccountId.isEmpty
          ? creditAccounts.doc()
          : creditAccounts.doc(creditAccountId);
      batch.set(ref, {
        'customerName': sale.customerName,
        'phone': creditPhone,
        'totalDebt': FieldValue.increment(sale.remaining),
        'saleIds': FieldValue.arrayUnion([sale.id]),
        'updatedAt': FieldValue.serverTimestamp(),
        if (creditAccountId.isEmpty) ...{
          'totalPaid': 0,
          'payments': <Map<String, dynamic>>[],
          'createdAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    }

    // بطاقة الزبونة تُنشأ تلقائياً عند أول بيع باسمها.
    if (sale.customerName.trim().isNotEmpty) {
      final ref = sale.customerId.isEmpty
          ? customers.doc()
          : customers.doc(sale.customerId);
      batch.set(ref, {
        'name': sale.customerName.trim(),
        'isVip': sale.isVip,
        'totalPurchases': FieldValue.increment(sale.total),
        'purchaseCount': FieldValue.increment(1),
        'lastPurchaseAt': FieldValue.serverTimestamp(),
        if (sale.customerId.isEmpty) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ───────────────────────── القراءة ─────────────────────────

  /// فواتير فترة. الترتيب محلياً — `where` على التاريخ مع `orderBy` على
  /// حقل آخر يطلب فهرساً مركّباً.
  Stream<List<Sale>> watchSales({DateTime? from, DateTime? to}) {
    Query<Map<String, dynamic>> q = sales;
    if (from != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from),
      );
    }
    if (to != null) {
      q = q.where('createdAt', isLessThan: Timestamp.fromDate(to));
    }
    return q.snapshots().map((s) {
      final list = s.docs.map(Sale.fromDoc).toList();
      list.sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return list;
    });
  }

  Future<List<Sale>> readAllSales() async {
    final snap = await sales.get();
    final list = snap.docs.map(Sale.fromDoc).toList();
    list.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return list;
  }

  /// فواتير عامل بعينه — بلا `orderBy` مع الـ `where` (فهرس مركّب).
  Stream<List<Sale>> watchSalesByUser(String uid) =>
      sales.where('createdBy', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(Sale.fromDoc).toList();
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
        return list;
      });

  // ───────────────────── الإرجاع والاستبدال والحذف ─────────────────────

  /// إرجاع كمية من سطر في فاتورة.
  ///
  /// يُعيد القطع إلى المخزون، يُنقص الفاتورة (أو يحذفها إن فرغت)،
  /// ويسجّل مصروفاً بقيمة المبلغ المُعاد.
  Future<void> returnItem({
    required Sale sale,
    required int itemIndex,
    required int quantity,
    required Actor actor,
    Product? product,
    String creditAccountId = '',
  }) async {
    if (itemIndex < 0 || itemIndex >= sale.items.length) return;
    final item = sale.items[itemIndex];
    final qty = quantity.clamp(1, item.quantity);

    final batch = _db.batch();

    if (item.productId.isNotEmpty) {
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(qty),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _mirrorAfterQuantityChange(batch, product, qty);
    }

    final remainingItems = [...sale.items];
    if (qty >= item.quantity) {
      remainingItems.removeAt(itemIndex);
    } else {
      remainingItems[itemIndex] = item.copyWith(quantity: item.quantity - qty);
    }

    final newSubtotal = remainingItems.fold<double>(
      0,
      (acc, i) => acc + i.lineTotal,
    );
    final newTotal = (newSubtotal - sale.discount - sale.vipDiscount)
        .clamp(0, double.infinity)
        .toDouble();

    // ═══ كيف يُردّ المال ═══
    //
    // الإرجاع **إلغاء لسطر البيع** لا معاملة جديدة. لذلك:
    //  • ما دفعه الزبون يبقى في يدنا ما دام لا يتجاوز الفاتورة الجديدة،
    //    ويُردّ نقداً ما زاد عنها فقط.
    //  • والباقي في ذمّته يُنقص بالفرق — فلا يُطالَب بثمن سلعة أعادها.
    //
    // مثال: كريدي بـ3000 دفع 1000، أرجع سلعة بـ1500 ⇒ الفاتورة 1500،
    // المدفوع يبقى 1000، والدَّين ينزل من 2000 إلى 500. لا نقد يخرج.
    final newPaid = sale.paidAmount <= newTotal ? sale.paidAmount : newTotal;
    final cashRefund = sale.paidAmount - newPaid;
    final debtBefore = sale.remaining;
    final debtAfter = (newTotal - newPaid).clamp(0, double.infinity).toDouble();
    final debtDrop = debtBefore - debtAfter;

    if (remainingItems.isEmpty) {
      // لم يبقَ شيء في الفاتورة ⇒ تُحذف.
      batch.delete(sales.doc(sale.id));
    } else {
      batch.update(sales.doc(sale.id), {
        'items': remainingItems.map((i) => i.toMap()).toList(),
        'subtotal': newSubtotal,
        'total': newTotal,
        'paidAmount': newPaid,
        'cost': remainingItems.fold<double>(0, (acc, i) => acc + i.lineCost),
      });
    }

    // نقد يخرج فعلاً ⇒ حركة صندوق **بنوع الإرجاع لا المصروف**.
    if (cashRefund > 0.009) {
      batch.set(cashbox.doc(), {
        'type': CashboxType.saleReturn.code,
        'amount': cashRefund,
        'note': 'إرجاع ${item.name} × $qty من ${sale.invoiceNumber}',
        'saleId': sale.id,
        'accountId': '',
        'accountName': '',
        'recipientId': '',
        'recipientName': '',
        'createdBy': actor.uid,
        'createdByName': actor.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // كريدي: الدَّين ينزل بمقدار ما سقط من الفاتورة.
    if (sale.paymentMethod == PaymentMethod.credit &&
        debtDrop > 0.009 &&
        creditAccountId.isNotEmpty) {
      batch.set(creditAccounts.doc(creditAccountId), {
        'totalDebt': FieldValue.increment(-debtDrop),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // بطاقة الزبونة: مشترياتها تنقص بقيمة ما أعادته.
    if (sale.customerId.isNotEmpty) {
      batch.set(customers.doc(sale.customerId), {
        'totalPurchases': FieldValue.increment(-(sale.total - newTotal)),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// استبدال سطر بمنتج آخر.
  ///
  /// يصحّح المخزون في الاتجاهين، ويسجّل **فرق السعر** دخلاً أو مصروفاً.
  Future<void> exchangeItem({
    required Sale sale,
    required int itemIndex,
    required int quantity,
    required Product replacement,
    required double replacementPrice,
    required Actor actor,
    Product? originalProduct,
  }) async {
    if (itemIndex < 0 || itemIndex >= sale.items.length) return;
    final item = sale.items[itemIndex];
    final qty = quantity.clamp(1, item.quantity);

    final oldValue = item.unitPrice * qty;
    final newValue = replacementPrice * qty;
    final difference = newValue - oldValue;

    final batch = _db.batch();

    // القديم يعود للمخزون.
    if (item.productId.isNotEmpty) {
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(qty),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _mirrorAfterQuantityChange(batch, originalProduct, qty);
    }

    // الجديد يخرج منه.
    batch.update(products.doc(replacement.id), {
      'quantity': FieldValue.increment(-qty),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _mirrorAfterQuantityChange(batch, replacement, -qty);

    // تعديل أسطر الفاتورة.
    final newItems = [...sale.items];
    final replacementItem = SaleItem.fromProduct(
      replacement,
      qty,
      priceOverride: replacementPrice,
    );
    if (qty >= item.quantity) {
      newItems[itemIndex] = replacementItem;
    } else {
      newItems[itemIndex] = item.copyWith(quantity: item.quantity - qty);
      newItems.insert(itemIndex + 1, replacementItem);
    }

    final newSubtotal = newItems.fold<double>(0, (acc, i) => acc + i.lineTotal);
    final newTotal = (newSubtotal - sale.discount - sale.vipDiscount)
        .clamp(0, double.infinity)
        .toDouble();

    batch.update(sales.doc(sale.id), {
      'items': newItems.map((i) => i.toMap()).toList(),
      'subtotal': newSubtotal,
      'total': newTotal,
      'cost': newItems.fold<double>(0, (acc, i) => acc + i.lineCost),
    });

    // فرق السعر: البديل أغلى ⇒ دخل، أرخص ⇒ مصروف. صفر ⇒ لا حركة.
    if (difference.abs() > 0.009) {
      batch.set(cashbox.doc(), {
        'type':
            (difference > 0 ? CashboxType.income : CashboxType.expense).code,
        'amount': difference.abs(),
        'note':
            'استبدال ${item.name} بـ ${replacement.name} '
            'في ${sale.invoiceNumber}',
        'saleId': sale.id,
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

  /// حذف فاتورة نهائياً: إعادة كل منتجاتها للمخزون + حذف حركات صندوقها.
  ///
  /// ⚠️ **كل القراءات قبل الـ batch**: الاستعلام داخل دفعة كتابة لا يعمل
  /// على الويب ويرمي استثناءً غامضاً.
  Future<void> deleteSale(
    Sale sale, {
    Map<String, Product> productLookup = const {},
    String creditAccountId = '',
  }) async {
    // (1) القراءات أولاً.
    final linked = await cashbox.where('saleId', isEqualTo: sale.id).get();

    // حركات قديمة سُجّلت قبل وجود حقل saleId — نتعرّف عليها برقم الفاتورة
    // في الملاحظة.
    final legacy = await cashbox
        .where('note', isEqualTo: 'بيع ${sale.invoiceNumber}')
        .get();

    // (2) ثم الكتابة.
    final batch = _db.batch();

    for (final item in sale.items) {
      if (item.productId.isEmpty) continue;
      batch.update(products.doc(item.productId), {
        'quantity': FieldValue.increment(item.quantity),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _mirrorAfterQuantityChange(
        batch,
        productLookup[item.productId],
        item.quantity,
      );
    }

    final seen = <String>{};
    for (final doc in [...linked.docs, ...legacy.docs]) {
      if (seen.add(doc.id)) batch.delete(doc.reference);
    }

    // ═══ ما كان الحذف يتركه خلفه ═══
    //
    // كان يحذف الفاتورة وحركاتها ويعيد البضاعة، **ويترك ذمّة الزبونة
    // وبطاقتها كما هما**. فتُحذف فاتورة كريدي ويبقى الدَّين مطالَباً به
    // إلى الأبد بلا فاتورة تسنده — والزبونة تُطالَب بثمن بضاعة عادت إلى
    // الرفّ. الحذف يجب أن يمحو أثر البيعة كلّه لا بعضه.
    if (sale.paymentMethod == PaymentMethod.credit &&
        sale.remaining > 0.009 &&
        creditAccountId.isNotEmpty) {
      batch.set(creditAccounts.doc(creditAccountId), {
        'totalDebt': FieldValue.increment(-sale.remaining),
        'saleIds': FieldValue.arrayRemove([sale.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (sale.customerId.isNotEmpty) {
      batch.set(customers.doc(sale.customerId), {
        'totalPurchases': FieldValue.increment(-sale.total),
        'purchaseCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    }

    batch.delete(sales.doc(sale.id));
    await batch.commit();
  }

  /// حذف السجلات الأقدم من تاريخ معيّن (دفعات 400).
  Future<int> purgeOlderThan(DateTime cutoff) async {
    var deleted = 0;
    for (final col in [sales, cashbox]) {
      final snap = await col
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      var batch = _db.batch();
      var ops = 0;
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
        ops++;
        deleted++;
        if (ops >= AppConstants.batchLimit) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
    }
    return deleted;
  }

  /// يحدّث مرآة المتجر بعد تغيّر كمية بمقدار `delta`.
  void _mirrorAfterQuantityChange(
    WriteBatch batch,
    Product? product,
    int delta,
  ) {
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

  // ───────────────────────── الزبائن ─────────────────────────

  Stream<List<Customer>> watchCustomers() => customers.snapshots().map((s) {
    final list = s.docs.map(Customer.fromDoc).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  });

  Future<void> saveCustomer(Customer c) => c.id.isEmpty
      ? customers.add(c.toMap())
      : customers.doc(c.id).set(c.toMap(), SetOptions(merge: true));

  Future<void> deleteCustomer(String id) => customers.doc(id).delete();
}
