import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/orders_repository.dart';
import '../../domain/models/public_order.dart';

final ordersRepositoryProvider = Provider<OrdersRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return OrdersRepository(ref.watch(firestoreProvider), storeId);
});

final ordersProvider = StreamProvider<List<PublicOrder>>((ref) {
  final repo = ref.watch(ordersRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchAll();
});

/// عدد الطلبات الجديدة — يُعرض كشارة في القائمة الجانبية.
///
/// موضعه هنا لا في ملف الشاشة: القائمة الجانبية تحتاجه، والشاشة تستعمل
/// القائمة، فوضعه في الشاشة يصنع دورة استيراد بين الملفّين.
final pendingOrdersCountProvider = Provider<int>((ref) =>
    (ref.watch(ordersProvider).value ?? const <PublicOrder>[])
        .where((o) => o.status == OrderStatus.pending)
        .length);
