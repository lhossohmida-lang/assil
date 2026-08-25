import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'employee_detail_screen.dart';
import '../../../../core/i18n/app_strings.dart';

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(employeesProvider);
    final me = ref.watch(currentUserProvider);

    return AppScaffold(
      route: AppRoutes.employees,
      title: tr('العمال'),
      floatingActionButton: me?.isAdmin ?? false
          ? FloatingActionButton.extended(
              onPressed: () => _addEmployee(context, ref),
              icon: const Icon(Icons.person_add),
              label: Text(tr('عامل جديد')),
            )
          : null,
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          message: trf('تعذّر تحميل العمال:\n{0}', [e]),
        ),
        data: (employees) => ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            for (final user in employees)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user.isAdmin
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.accent.withValues(alpha: 0.15),
                    child: Icon(
                      user.isAdmin ? Icons.shield : Icons.person,
                      color: user.isAdmin ? AppTheme.primary : AppTheme.accent,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name.isEmpty ? user.email : user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (user.isAdmin)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tr('صاحب المحل'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    trf('{0}\nالراتب {1} ({2}) · سحب {3}', [user.email, money(user.salary), user.salaryType.label, money(user.withdrawnAmount)]),
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: (me?.isAdmin ?? false) && !user.isAdmin
                      ? IconButton(
                          tooltip: tr('حذف'),
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.danger),
                          onPressed: () => _deleteEmployee(context, ref, user),
                        )
                      : null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EmployeeDetailScreen(user: user),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEmployee(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final ok = await confirmDialog(
      context,
      title: tr('حذف العامل'),
      message: trf('سيُمنع «{0}» من الدخول نهائياً.\n\nفواتيره السابقة تبقى في السجل باسمه.', [user.name]),
      confirmLabel: tr('حذف'),
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .deleteEmployee(user.storeId, user.uid);
      if (context.mounted) showOk(context, tr('حُذف العامل'));
    } catch (e) {
      if (context.mounted) showErr(context, arabicAuthError(e));
    }
  }

  Future<void> _addEmployee(BuildContext context, WidgetRef ref) async {
    final storeId = ref.read(storeIdProvider);
    if (storeId == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => _AddEmployeeDialog(storeId: storeId),
    );
  }
}

class _AddEmployeeDialog extends ConsumerStatefulWidget {
  const _AddEmployeeDialog({required this.storeId});
  final String storeId;

  @override
  ConsumerState<_AddEmployeeDialog> createState() =>
      _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<_AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _salary = TextEditingController(text: '0');

  SalaryType _salaryType = SalaryType.monthly;
  final Set<String> _allowed = {AppRoutes.pos};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _salary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // 🔒 عامل بلا قسم واحد لا يستطيع فعل شيء: يدخل فيجد شاشة تقول له
    // «حسابك بلا صلاحيات». نمنع إنشاءه أصلاً بدل أن نكتشف العطب لاحقاً.
    if (_allowed.isEmpty) {
      setState(() => _error = tr('اختر قسماً واحداً على الأقل — العامل بلا أقسام لا يستطيع فتح أي شاشة.'));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).createEmployee(
            storeId: widget.storeId,
            email: _email.text,
            password: _password.text,
            name: _name.text,
            salary: toDouble(_salary.text),
            salaryType: _salaryType,
            allowedScreens: _allowed.toList(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        showOk(context, tr('أُنشئ حساب العامل'));
      }
    } catch (e) {
      if (mounted) setState(() => _error = arabicAuthError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('عامل جديد')),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: InputDecoration(labelText: tr('الاسم *')),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? tr('الاسم مطلوب') : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      InputDecoration(labelText: tr('البريد الإلكتروني *')),
                  validator: (v) => (v ?? '').trim().contains('@')
                      ? null
                      : tr('بريد إلكتروني غير صحيح'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _password,
                  decoration:
                      InputDecoration(labelText: tr('كلمة المرور *')),
                  validator: (v) => (v ?? '').length >= 6
                      ? null
                      : tr('كلمة المرور 6 أحرف على الأقل'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: MoneyField(
                        controller: _salary,
                        label: tr('الراتب'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<SalaryType>(
                        initialValue: _salaryType,
                        decoration:
                            InputDecoration(labelText: tr('نوع الراتب')),
                        items: [
                          for (final t in SalaryType.values)
                            DropdownMenuItem(value: t, child: Text(t.label)),
                        ],
                        onChanged: (v) => setState(
                          () => _salaryType = v ?? SalaryType.monthly,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  tr('الأقسام المسموح بها'),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final entry in grantableScreens.entries)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _allowed.contains(entry.key),
                    title: Text(entry.value),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _allowed.add(entry.key);
                      } else {
                        _allowed.remove(entry.key);
                      }
                    }),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(tr('إنشاء')),
        ),
      ],
    );
  }
}
