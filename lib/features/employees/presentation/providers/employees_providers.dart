import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cashbox/domain/models/cashbox_transaction.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../sales/domain/models/sale.dart';

/// فواتير عامل بعينه.
final salesByUserProvider =
    StreamProvider.family<List<Sale>, String>((ref, uid) {
  final repo = ref.watch(salesRepositoryProvider);
  if (repo == null || uid.isEmpty) return Stream.value(const []);
  return repo.watchSalesByUser(uid);
});

/// سحوبات عامل بعينه من الصندوق.
final withdrawalsByUserProvider =
    StreamProvider.family<List<CashboxTransaction>, String>((ref, uid) {
  final repo = ref.watch(cashboxRepositoryProvider);
  if (repo == null || uid.isEmpty) return Stream.value(const []);
  return repo.watchWithdrawalsFor(uid);
});

/// تجميع فواتير العامل بالأيام (الأحدث أولاً).
class DayGroup {
  const DayGroup(this.day, this.sales);
  final DateTime day;
  final List<Sale> sales;

  double get total => sales.fold(0.0, (acc, s) => acc + s.total);
  int get pieces => sales.fold(0, (acc, s) => acc + s.pieceCount);
}

List<DayGroup> groupByDay(List<Sale> sales) {
  final map = <DateTime, List<Sale>>{};
  for (final sale in sales) {
    final at = sale.createdAt;
    if (at == null) continue;
    final day = DateTime(at.year, at.month, at.day);
    map.putIfAbsent(day, () => []).add(sale);
  }
  final groups = map.entries.map((e) => DayGroup(e.key, e.value)).toList();
  groups.sort((a, b) => b.day.compareTo(a.day));
  return groups;
}
