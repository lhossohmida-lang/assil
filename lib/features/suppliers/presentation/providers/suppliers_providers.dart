import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../cashbox/domain/models/cashbox_transaction.dart';
import '../../data/suppliers_repository.dart';
import '../../domain/models/purchase.dart';
import '../../domain/models/supplier.dart';

final suppliersRepositoryProvider = Provider<SuppliersRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return SuppliersRepository(ref.watch(firestoreProvider), storeId);
});

final suppliersListProvider = StreamProvider<List<Supplier>>((ref) {
  final repo = ref.watch(suppliersRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchSuppliers();
});

final purchasesProvider = StreamProvider<List<Purchase>>((ref) {
  final repo = ref.watch(suppliersRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchPurchases();
});

/// مجموع ما عليك للموردين — يظهر في رأس شاشة الموردين.
final totalSupplierDebtProvider = Provider<double>((ref) {
  final list = ref.watch(suppliersListProvider).value ?? const <Supplier>[];
  return list.fold(0.0, (acc, s) => acc + s.remaining);
});

final supplierPurchasesProvider =
    StreamProvider.family<List<Purchase>, String>((ref, supplierId) {
  final repo = ref.watch(suppliersRepositoryProvider);
  if (repo == null || supplierId.isEmpty) return Stream.value(const []);
  return repo.watchPurchasesOf(supplierId);
});

final supplierTransactionsProvider =
    StreamProvider.family<List<CashboxTransaction>, String>((ref, supplierId) {
  final repo = ref.watch(suppliersRepositoryProvider);
  if (repo == null || supplierId.isEmpty) return Stream.value(const []);
  return repo.watchSupplierTransactions(supplierId);
});
