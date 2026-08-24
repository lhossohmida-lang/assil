import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../domain/models/app_user.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

/// جلسة كاملة: حساب Firebase + مستند المستخدم في متجره.
class Session {
  final User firebaseUser;
  final AppUser appUser;
  const Session(this.firebaseUser, this.appUser);

  String get storeId => appUser.storeId;
  String get uid => firebaseUser.uid;
}

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// الجلسة الحيّة: تتبدّل مع الدخول/الخروج، **وتتحدّث فوراً** عند تغيير
/// صلاحيات العامل من شاشة العمال (لأننا نستمع لمستند المستخدم لا نقرؤه مرة).
final sessionProvider = StreamProvider<Session?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges().asyncExpand<Session?>((user) async* {
    if (user == null) {
      yield null;
      return;
    }
    final storeId = await repo.resolveStoreId(user);
    yield* repo.watchUser(storeId, user.uid).map(
          (appUser) => appUser == null ? null : Session(user, appUser),
        );
  });
});

/// مُعرّف المتجر الحالي — تحتاجه كل مجموعات Firestore تقريباً.
final storeIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).value?.storeId,
);

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(sessionProvider).value?.appUser,
);

/// قائمة عمال المتجر (بما فيهم الأدمن).
final employeesProvider = StreamProvider<List<AppUser>>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return Stream.value(const []);
  return ref.watch(authRepositoryProvider).watchEmployees(storeId);
});
