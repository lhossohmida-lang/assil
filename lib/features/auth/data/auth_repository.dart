import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../firebase_options.dart';
import '../domain/models/app_user.dart';

/// يحوّل أخطاء Firebase إلى رسائل عربية مفهومة للبائع.
///
/// «permission-denied» تحديداً: أكثر خطأ يضيّع الوقت — الرسالة تقول صراحةً
/// أن السبب قواعد Firestore لا الشبكة ولا كلمة السر.
String arabicAuthError(Object e) {
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'البريد الإلكتروني غير صحيح';
      case 'user-disabled':
        return 'هذا الحساب معطّل';
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد';
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد أو كلمة المرور خاطئة';
      case 'email-already-in-use':
        return 'هذا البريد مستعمل في حساب آخر';
      case 'weak-password':
        return 'كلمة المرور ضعيفة — 6 أحرف على الأقل';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة — انتظر قليلاً ثم أعد المحاولة';
      case 'operation-not-allowed':
        return 'الدخول بالبريد وكلمة المرور غير مفعّل في مشروع Firebase';
      default:
        return 'خطأ في المصادقة: ${e.code}';
    }
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') {
      return 'قواعد Firestore ترفض العملية — تأكد من نشر آخر نسخة من '
          'firestore.rules (وأن الدوال داخل كتلة match).';
    }
    if (e.code == 'unavailable') {
      return 'لا يوجد اتصال بالخادم — سيُزامَن العمل عند عودة الإنترنت';
    }
    return 'خطأ: ${e.code}';
  }
  return 'خطأ غير متوقع: $e';
}

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  DocumentReference<Map<String, dynamic>> _mapRef(String uid) =>
      _db.collection(FirestorePaths.userStoreMap).doc(uid);

  DocumentReference<Map<String, dynamic>> userRef(String storeId, String uid) =>
      _db
          .collection(FirestorePaths.stores)
          .doc(storeId)
          .collection(FirestorePaths.users)
          .doc(uid);

  /// يحدّد متجر المستخدم، وينشئ متجراً جديداً إن كان أول دخول.
  ///
  /// حساب أُنشئ يدوياً من لوحة Firebase لا خريطة له ⇒ نعتبره صاحب محل،
  /// و`storeId = uid` حتى تسمح القاعدة `uid == storeId` بالكتابة فوراً
  /// (لا نحتاج مستنداً موجوداً مسبقاً في stores/*/users).
  Future<String> resolveStoreId(User user) async {
    final mapSnap = await _mapRef(user.uid).get();
    final data = mapSnap.data();
    if (data != null && (data['storeId'] as String?)?.isNotEmpty == true) {
      return data['storeId'] as String;
    }

    final storeId = user.uid;
    final batch = _db.batch();
    batch.set(userRef(storeId, user.uid), {
      'email': user.email ?? '',
      'name': user.displayName?.isNotEmpty == true
          ? user.displayName
          : (user.email?.split('@').first ?? 'صاحب المحل'),
      'role': 'admin',
      'allowedScreens': grantableScreens.keys.toList(),
      'salary': 0,
      'salaryType': 'monthly',
      'withdrawnAmount': 0,
      'storeId': storeId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(_mapRef(user.uid), {'storeId': storeId, 'role': 'admin'});
    await batch.commit();
    return storeId;
  }

  /// بثّ مستند المستخدم — حتى تسري تغييرات الصلاحيات فوراً على العامل
  /// دون أن يُعيد الدخول.
  Stream<AppUser?> watchUser(String storeId, String uid) =>
      userRef(storeId, uid).snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return null;
        return AppUser.fromMap(uid, data, storeId);
      });

  Stream<List<AppUser>> watchEmployees(String storeId) => _db
      .collection(FirestorePaths.stores)
      .doc(storeId)
      .collection(FirestorePaths.users)
      .snapshots()
      .map((s) => s.docs
          .map((d) => AppUser.fromMap(d.id, d.data(), storeId))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name)));

  /// إنشاء حساب عامل — الطريقة الصحيحة الوحيدة.
  ///
  /// 1. تطبيق Firebase **ثانوي باسم فريد لكل محاولة**: اسم ثابت مثل
  ///    SecondaryApp يورّث جلسة المحاولة السابقة ويسبّب أعطالاً عشوائية
  ///    (يظن أن المستخدم مسجَّل دخوله وهو ليس كذلك).
  /// 2. `createUserWithEmailAndPassword` على المصادقة الثانوية — لأن إنشاء
  ///    مستخدم **يسجّل دخوله تلقائياً**، ولو فعلناها على الجلسة الأساسية
  ///    لخرج الأدمن من حسابه في منتصف العملية.
  /// 3. الأدمن يكتب المستندين **بجلسته هو** في WriteBatch واحد.
  /// 4. لو فشل الحفظ نحذف حساب Auth اليتيم وإلا بقي البريد محجوزاً للأبد.
  /// 5. `secondaryApp.delete()` في finally دائماً.
  Future<void> createEmployee({
    required String storeId,
    required String email,
    required String password,
    required String name,
    required double salary,
    required SalaryType salaryType,
    required List<String> allowedScreens,
  }) async {
    final appName = 'EmployeeSignup_${DateTime.now().microsecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    User? createdUser;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = cred.user;
      final uid = createdUser!.uid;

      // الكتابة بجلسة الأدمن (_db) لا بجلسة العامل الجديد.
      final batch = _db.batch();
      batch.set(userRef(storeId, uid), {
        'email': email.trim(),
        'name': name.trim(),
        'role': 'employee',
        'allowedScreens': allowedScreens,
        'salary': salary,
        'salaryType': salaryType == SalaryType.daily ? 'daily' : 'monthly',
        'withdrawnAmount': 0,
        'storeId': storeId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // القاعدة تسمح للأدمن بإنشاء هذه الخريطة (create فقط، role=employee،
      // ولمتجره هو) — بلا هذا المستند لا يعرف العامل متجره عند الدخول.
      batch.set(
        _db.collection(FirestorePaths.userStoreMap).doc(uid),
        {'storeId': storeId, 'role': 'employee'},
      );
      await batch.commit();
    } catch (e) {
      // حساب Auth بلا مستندات = بريد محجوز لا يمكن إعادة استعماله.
      if (createdUser != null) {
        try {
          await createdUser.delete();
        } catch (_) {
          // لا نُخفي الخطأ الأصلي بخطأ التنظيف.
        }
      }
      rethrow;
    } finally {
      await secondaryApp?.delete();
    }
  }

  /// حذف عامل: المستندان فقط. حساب Auth نفسه لا يمكن حذفه من العميل
  /// (يتطلب Admin SDK)، لكن بلا خريطة ولا مستند مستخدم لا يستطيع الدخول.
  Future<void> deleteEmployee(String storeId, String uid) async {
    final batch = _db.batch();
    batch.delete(userRef(storeId, uid));
    batch.delete(_db.collection(FirestorePaths.userStoreMap).doc(uid));
    await batch.commit();
  }

  Future<void> updateEmployee(
    String storeId,
    String uid,
    Map<String, dynamic> changes,
  ) =>
      userRef(storeId, uid).update(changes);
}
