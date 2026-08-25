import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../customers/domain/models/customer.dart';
import '../../../sales/data/sales_repository.dart';
import '../../data/pos_repository.dart';
import '../../domain/models/reservation.dart';

final salesRepositoryProvider = Provider<SalesRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return SalesRepository(ref.watch(firestoreProvider), storeId);
});

final posRepositoryProvider = Provider<PosRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return PosRepository(ref.watch(firestoreProvider), storeId);
});

/// من ينفّذ العملية الآن — يُرفق بكل فاتورة وحركة صندوق.
final actorProvider = Provider<Actor>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Actor.unknown;
  return Actor(user.uid, user.name);
});

final heldCartsProvider = StreamProvider<List<HeldCart>>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchHeldCarts();
});

final reservationsProvider = StreamProvider<List<Reservation>>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchReservations();
});

/// الحجوزات الجارية فقط — ما يهمّ البائع في الشاشة اليومية.
final activeReservationsProvider = Provider<List<Reservation>>((ref) {
  final all = ref.watch(reservationsProvider).value ?? const <Reservation>[];
  return all.where((r) => r.status == ReservationStatus.active).toList();
});

/// حساب الكريدي المرتبط بفاتورة، أو '' إن لم يكن لها حساب.
///
/// البحث عكسي عبر `saleIds` لأن الفاتورة نفسها لا تحمل معرّف الحساب —
/// وهو ما جعل حذفها يترك الدَّين قائماً بلا فاتورة تسنده.
String creditAccountIdForSale(List<CreditAccount> accounts, String saleId) {
  for (final account in accounts) {
    if (account.saleIds.contains(saleId)) return account.id;
  }
  return '';
}

final creditAccountsProvider = StreamProvider<List<CreditAccount>>((ref) {
  final repo = ref.watch(posRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchCreditAccounts();
});

/// مجموع ديون الزبائن المتبقّية — يدخل في وعاء الزكاة.
final totalCreditsRemainingProvider = Provider<double>((ref) {
  final accounts =
      ref.watch(creditAccountsProvider).value ?? const <CreditAccount>[];
  return accounts.fold(0.0, (acc, a) => acc + a.remaining);
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(salesRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchCustomers();
});
