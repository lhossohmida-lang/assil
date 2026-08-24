import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/device_id.dart';
import '../../../shared/utils/formatters.dart';
import '../../inventory/domain/models/product.dart';
import '../../sales/domain/models/sale.dart';
import '../data/print_queue_repository.dart';
import 'order_label_service.dart';
import 'print_service.dart';
import '../../../core/i18n/app_strings.dart';

/// عامل الطباعة عن بُعد — **يعمل على الحاسوب فقط**.
///
/// يستمع لطابور `print_jobs` وينفّذ ما يرسله الهاتف على طابعة المحل.
class PrintWorker {
  PrintWorker({
    required this.db,
    required this.storeId,
    required this.queue,
    required this.printService,
  });

  final FirebaseFirestore db;
  final String storeId;
  final PrintQueueRepository queue;

  /// دالة لا خاصية: الإعدادات قد تتغيّر بين وظيفة وأخرى.
  final PrintService Function() printService;

  StreamSubscription<List<PrintJob>>? _sub;

  /// أوامر يجري تنفيذها الآن — حارس داخلي فوق حارس المعاملة.
  final Set<String> _inFlight = {};

  void start() {
    if (!PrintService.canPrintLocally) return;
    _sub?.cancel();
    _sub = queue.watchPending().listen(
      _onJobs,
      onError: (Object e) => debugPrint(trf('[KMSAN] طابور الطباعة: {0}', [e])),
    );
    debugPrint(trf('[KMSAN] عامل الطباعة يعمل — الجهاز {0}', [deviceId]));
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _onJobs(List<PrintJob> jobs) async {
    for (final job in jobs) {
      // لا نطبع ما أنشأناه نحن: الحاسوب يطبع أوامره محلياً فوراً،
      // ولو التقطها من الطابور أيضاً لخرجت نسختان.
      if (job.originDevice == deviceId) continue;
      if (_inFlight.contains(job.id)) continue;

      // أوامر قديمة: الحاسوب كان مطفأً وقتها والبائع طبع بطريقة أخرى.
      final created = job.createdAt;
      if (created != null &&
          DateTime.now().difference(created) > const Duration(minutes: 30)) {
        await queue.remove(job.id);
        continue;
      }

      _inFlight.add(job.id);
      unawaited(_run(job).whenComplete(() => _inFlight.remove(job.id)));
    }
  }

  Future<void> _run(PrintJob job) async {
    // الحجز الذرّي هو ما يمنع حاسوبين من طباعة نفس الوصل.
    if (!await queue.claim(job.id)) return;

    try {
      final outcome = switch (job.kind) {
        PrintJobKind.receipt => await _printReceipt(job),
        PrintJobKind.ticket => await _printTicket(job),
        PrintJobKind.orderLabel => await _printOrderLabel(job),
      };

      if (outcome.ok) {
        await queue.complete(job.id);
      } else {
        await queue.fail(job.id, outcome.message);
      }
    } catch (e) {
      await queue.fail(job.id, '$e');
    }
  }

  /// قراءة مستند مع إعادة محاولة.
  ///
  /// ⚠️ ضرورية: البيع «متفائل» — نضيف أمر الطباعة ونعرض النجاح فوراً
  /// بينما كتابة الفاتورة ما زالت في الطريق إلى الخادم. بلا إعادة المحاولة
  /// يصل أمر الطباعة قبل الفاتورة فيفشل بـ«الفاتورة غير موجودة».
  Future<DocumentSnapshot<Map<String, dynamic>>?> _readWithRetry(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final snap = await ref.get();
        if (snap.exists) return snap;
      } catch (e) {
        debugPrint(trf('[KMSAN] قراءة مستند الطباعة فشلت: {0}', [e]));
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return null;
  }

  DocumentReference<Map<String, dynamic>> _storeDoc(
    String collection,
    String id,
  ) =>
      db
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(collection)
          .doc(id);

  Future<PrintOutcome> _printReceipt(PrintJob job) async {
    final snap = await _readWithRetry(
      _storeDoc(FirestorePaths.sales, job.refId),
    );
    if (snap == null) {
      return PrintOutcome(false, tr('الفاتورة غير موجودة'));
    }
    return printService().printReceipt(Sale.fromDoc(snap), allowDialog: false);
  }

  Future<PrintOutcome> _printTicket(PrintJob job) async {
    final snap = await _readWithRetry(
      _storeDoc(FirestorePaths.products, job.refId),
    );
    if (snap == null) {
      return PrintOutcome(false, tr('المنتج غير موجود'));
    }
    return printService().printTicket(
      Product.fromDoc(snap),
      copies: job.copies,
      allowDialog: false,
    );
  }

  Future<PrintOutcome> _printOrderLabel(PrintJob job) async {
    final ref = db
        .collection(FirestorePaths.publicOrders)
        .doc(storeId)
        .collection('orders')
        .doc(job.refId);
    final snap = await _readWithRetry(ref);
    if (snap == null) {
      return PrintOutcome(false, tr('الطلب غير موجود'));
    }
    return printService().printOrderLabel(
      orderLabelDataFromMap(snap.data() ?? const {}),
      orderId: job.refId,
      allowDialog: false,
    );
  }
}

/// تحويل مستند طلب خام إلى بيانات ملصق — مشتركة بين العامل وشاشة الطلبات.
OrderLabelData orderLabelDataFromMap(Map<String, dynamic> m) {
  final customer = Map<String, dynamic>.from(
    (m['customer'] ?? const {}) as Map,
  );
  final items = ((m['items'] ?? const []) as List)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .map((i) => OrderLabelItem(
            (i['name'] ?? '') as String,
            toInt(i['quantity']),
            toDouble(i['price']),
          ))
      .toList();

  return OrderLabelData(
    orderNumber: (m['orderNumber'] ?? '') as String,
    customerName: (customer['fullName'] ?? '') as String,
    phone: (customer['phone'] ?? '') as String,
    wilaya: (customer['wilaya'] ?? '') as String,
    address: (customer['address'] ?? '') as String,
    notes: (customer['notes'] ?? '') as String,
    items: items,
    total: toDouble(m['total']),
    deposit: toDouble(m['deposit']),
    deliveryFee: toDouble(m['deliveryFee']),
  );
}
