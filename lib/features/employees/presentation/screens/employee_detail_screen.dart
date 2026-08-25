import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../reports/presentation/widgets/invoice_detail_sheet.dart';
import '../../../sales/domain/models/sale.dart';
import '../providers/employees_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// بطاقة العامل بلسانين: مبيعاته وسحوباته.
class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({super.key, required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // لسان الصلاحيات لصاحب المحل وحده، ولا يُعرض على حسابه هو
    // (الأدمن يرى كل شيء بحكم دوره، فلا معنى لجدول أقسامه).
    final me = ref.watch(currentUserProvider);
    final canEditPermissions = (me?.isAdmin ?? false) && !user.isAdmin;

    return DefaultTabController(
      length: canEditPermissions ? 3 : 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(user.name.isEmpty ? user.email : user.name),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.receipt_long), text: tr('مبيعاته')),
              Tab(icon: Icon(Icons.money_off), text: tr('سحوباته')),
              if (canEditPermissions)
                Tab(icon: Icon(Icons.key), text: tr('الصلاحيات')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SalesTab(user: user),
            _WithdrawalsTab(user: user),
            if (canEditPermissions) _PermissionsTab(user: user),
          ],
        ),
      ),
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesByUserProvider(user.uid));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off,
        message: trf('تعذّر تحميل المبيعات:\n{0}', [e]),
      ),
      data: (sales) {
        if (sales.isEmpty) {
          return EmptyState(
            icon: Icons.receipt_long_outlined,
            message: tr('لا مبيعات لهذا العامل بعد'),
          );
        }

        final groups = groupByDay(sales);
        final total = sales.fold(0.0, (acc, s) => acc + s.total);
        final pieces = sales.fold(0, (acc, s) => acc + s.pieceCount);

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                        label: tr('الفواتير'), value: '${sales.length}'),
                  ),
                  Expanded(
                    child: _Metric(label: tr('القطع'), value: '$pieces'),
                  ),
                  Expanded(
                    child: _Metric(label: tr('الإجمالي'), value: money(total)),
                  ),
                ],
              ),
            ),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    Text(
                      formatDayLabel(group.day),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      trf('{0} فاتورة · {1}', [group.sales.length, money(group.total)]),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              for (final sale in group.sales)
                Card(
                  child: ListTile(
                    dense: true,
                    // العنوان = **أسماء المنتجات** لا رقم الفاتورة.
                    title: Text(
                      sale.productsTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      trf('{0} · {1} قطعة · {2}', [formatTime(sale.createdAt), sale.pieceCount, sale.paymentMethod.label]),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      money(sale.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.success,
                      ),
                    ),
                    onTap: () => showInvoiceSheet(context, sale),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _WithdrawalsTab extends ConsumerWidget {
  const _WithdrawalsTab({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(withdrawalsByUserProvider(user.uid));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.cloud_off,
        message: trf('تعذّر تحميل السحوبات:\n{0}', [e]),
      ),
      data: (withdrawals) {
        final total = withdrawals.fold(0.0, (acc, t) => acc + t.amount);

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: tr('مجموع السحوبات'),
                      value: money(total),
                      color: AppTheme.danger,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: tr('الراتب'),
                      value: '${money(user.salary)} (${user.salaryType.label})',
                    ),
                  ),
                ],
              ),
            ),
            if (withdrawals.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.money_off,
                  message: tr('لا سحوبات مسجّلة لهذا العامل'),
                ),
              )
            else
              for (final tx in withdrawals)
                Card(
                  child: ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFEBEE),
                      child: Icon(Icons.arrow_upward, color: AppTheme.danger),
                    ),
                    title: Text(tx.note.isEmpty ? tr('سحب') : tx.note),
                    subtitle: Text(
                      formatDateTime(tx.createdAt),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      money(tx.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.danger,
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// تعديل أقسام العامل بعد إنشائه.
///
/// ⚠️ لم تكن هذه الشاشة موجودة: الصلاحيات كانت تُكتب **مرّة واحدة** عند
/// الإنشاء بلا أي طريق لتغييرها. فعاملٌ أُنشئ بلا قسم كان يبقى محبوساً
/// إلى الأبد، والعلاج الوحيد حذف حسابه وإنشاؤه من جديد — وفيه ضياع سجلّ
/// سحوباته ومبيعاته المرتبطة بمعرّفه.
///
/// التغيير يسري **فوراً** على جهاز العامل بلا إعادة دخول، لأن الجلسة
/// تبثّ مستند المستخدم (`watchUser`) ولا تقرؤه مرّة.
class _PermissionsTab extends ConsumerStatefulWidget {
  const _PermissionsTab({required this.user});
  final AppUser user;

  @override
  ConsumerState<_PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends ConsumerState<_PermissionsTab> {
  late final Set<String> _allowed = widget.user.allowedScreens.toSet();
  bool _busy = false;

  bool get _dirty {
    final original = widget.user.allowedScreens.toSet();
    return original.length != _allowed.length ||
        !original.containsAll(_allowed);
  }

  Future<void> _save() async {
    final storeId = ref.read(storeIdProvider);
    if (storeId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateEmployee(
        storeId,
        widget.user.uid,
        {'allowedScreens': _allowed.toList()},
      );
      if (mounted) showOk(context, tr('حُفظت الصلاحيات'));
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر الحفظ: {0}', [e]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_allowed.isEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tr('بلا أي قسم لن يستطيع هذا العامل فتح أي شاشة — سيرى رسالة «حسابك بلا صلاحيات» عند دخوله.'),
              style: TextStyle(fontSize: 12, color: AppTheme.warning),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final entry in grantableScreens.entries)
                CheckboxListTile(
                  dense: true,
                  value: _allowed.contains(entry.key),
                  title: Text(entry.value),
                  onChanged: _busy
                      ? null
                      : (checked) => setState(() {
                            if (checked ?? false) {
                              _allowed.add(entry.key);
                            } else {
                              _allowed.remove(entry.key);
                            }
                          }),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_busy || !_dirty) ? null : _save,
              icon: const Icon(Icons.save),
              label: Text(_busy ? tr('جارٍ الحفظ...') : tr('حفظ الصلاحيات')),
            ),
          ),
        ),
      ],
    );
  }
}
