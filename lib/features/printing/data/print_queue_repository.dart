import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/services/device_id.dart';

enum PrintJobKind { receipt, ticket, orderLabel }

extension PrintJobKindCode on PrintJobKind {
  String get code => switch (this) {
        PrintJobKind.receipt => 'receipt',
        PrintJobKind.ticket => 'ticket',
        PrintJobKind.orderLabel => 'orderLabel',
      };

  static PrintJobKind parse(String? s) => switch (s) {
        'ticket' => PrintJobKind.ticket,
        'orderLabel' => PrintJobKind.orderLabel,
        _ => PrintJobKind.receipt,
      };
}

class PrintJob {
  const PrintJob({
    required this.id,
    required this.kind,
    required this.refId,
    required this.copies,
    required this.title,
    required this.status,
    required this.originDevice,
    this.createdAt,
  });

  final String id;
  final PrintJobKind kind;

  /// معرّف الفاتورة أو المنتج أو الطلب — **لا نضع PDF في المستند**.
  final String refId;

  final int copies;
  final String title;
  final String status; // pending | printing | error
  final String originDevice;
  final DateTime? createdAt;

  factory PrintJob.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? const {};
    return PrintJob(
      id: doc.id,
      kind: PrintJobKindCode.parse(m['kind'] as String?),
      refId: (m['refId'] ?? '') as String,
      copies: (m['copies'] ?? 1) is int ? (m['copies'] ?? 1) as int : 1,
      title: (m['title'] ?? '') as String,
      status: (m['status'] ?? 'pending') as String,
      originDevice: (m['originDevice'] ?? '') as String,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// طابور الطباعة عن بُعد: الهاتف يضع أمراً، الحاسوب ينفّذه على طابعته.
///
/// ⚠️ **لا PDF في المستند**: الحاسوب يعيد بناء المستند من قاعدة البيانات
/// بإعداداته ومعايرته هو. لو أرسل الهاتف PDF جاهزاً لطُبع بمقاسات الهاتف
/// (الذي لا يعرف شيئاً عن الطابعة) ولضخّمنا كل مستند بمئات الكيلوبايتات.
class PrintQueueRepository {
  PrintQueueRepository(this._db, this.storeId);

  final FirebaseFirestore _db;
  final String storeId;

  CollectionReference<Map<String, dynamic>> get _jobs => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.printJobs);

  Future<void> enqueue({
    required PrintJobKind kind,
    required String refId,
    required String title,
    int copies = 1,
  }) =>
      _jobs.add({
        'kind': kind.code,
        'refId': refId,
        'copies': copies,
        'title': title,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'originDevice': deviceId,
      });

  Stream<List<PrintJob>> watchPending() => _jobs
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(PrintJob.fromDoc).toList());

  /// يحجز الأمر بمعاملة ذرّية: pending ← printing.
  ///
  /// بلا المعاملة، حاسوبان يعملان معاً (أو نفس الحاسوب بعد إعادة اتصال)
  /// يطبعان الوصل مرتين. المعاملة تضمن أن واحداً فقط يفوز.
  Future<bool> claim(String jobId) async {
    try {
      return await _db.runTransaction<bool>((tx) async {
        final ref = _jobs.doc(jobId);
        final snap = await tx.get(ref);
        if (!snap.exists) return false;
        if ((snap.data()?['status'] ?? '') != 'pending') return false;
        tx.update(ref, {
          'status': 'printing',
          'claimedBy': deviceId,
          'claimedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (_) {
      return false;
    }
  }

  /// نجحت الطباعة ⇒ نحذف الأمر (لا فائدة من أرشيف أوامر طباعة).
  Future<void> complete(String jobId) => _jobs.doc(jobId).delete();

  /// فشلت ⇒ نُبقيها مع السبب حتى يراه المستخدم.
  Future<void> fail(String jobId, String reason) => _jobs.doc(jobId).update({
        'status': 'error',
        'error': reason,
        'failedAt': FieldValue.serverTimestamp(),
      });

  Future<void> remove(String jobId) => _jobs.doc(jobId).delete();
}
