import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../data/cashbox_repository.dart';
import '../../../../core/i18n/app_strings.dart';

/// إيداع نقدي في الصندوق.
Future<void> showDepositDialog(BuildContext context, WidgetRef ref) async {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('إيداع في الصندوق')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(
            controller: amountCtrl,
            label: tr('المبلغ'),
            autofocus: true,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(labelText: tr('السبب / ملاحظة')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(tr('إيداع')),
        ),
      ],
    ),
  );

  final amount = toDouble(amountCtrl.text);
  final note = noteCtrl.text.trim();
  amountCtrl.dispose();
  noteCtrl.dispose();

  if (ok != true || amount <= 0 || !context.mounted) return;

  try {
    await ref.read(cashboxRepositoryProvider)!.deposit(
          amount: amount,
          actor: ref.read(actorProvider),
          note: note,
        );
    if (context.mounted) showOk(context, trf('أُودع {0}', [money(amount)]));
  } catch (e) {
    if (context.mounted) showErr(context, '$e');
  }
}

/// سحب أو مصروف — **مربوط بحساب مصروف أو بعامل**.
Future<void> showWithdrawDialog(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(cashboxRepositoryProvider);
  if (repo == null) return;

  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  WithdrawalTarget target = const WithdrawalTarget.none();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('سحب / مصروف')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MoneyField(
              controller: amountCtrl,
              label: tr('المبلغ'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            RecipientPicker(
              repository: repo,
              onChanged: (t) => target = t,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(labelText: tr('السبب / ملاحظة')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(tr('سحب')),
        ),
      ],
    ),
  );

  final amount = toDouble(amountCtrl.text);
  final note = noteCtrl.text.trim();
  amountCtrl.dispose();
  noteCtrl.dispose();

  if (ok != true || amount <= 0 || !context.mounted) return;

  try {
    await repo.withdraw(
      amount: amount,
      actor: ref.read(actorProvider),
      target: target,
      note: note,
    );
    if (context.mounted) {
      showOk(
        context,
        target.isEmpty
            ? trf('سُحب {0}', [money(amount)])
            : trf('سُحب {0} — {1}', [money(amount), target.name]),
      );
    }
  } catch (e) {
    if (context.mounted) showErr(context, '$e');
  }
}

/// اختيار وجهة السحب: حساب مصروف أو عامل.
///
/// ⚠️ **قائمة صريحة تُحمَّل مرة واحدة — وليست Autocomplete.**
/// نسخة Autocomplete كانت تُنشئ مستمعاً جديداً في كل إعادة بناء، وكان
/// المستمع يمسح الاختيار، فتُحفظ السحوبات بلا حساب ولا يظهر لها أثر في
/// أي تقرير ولا في سحوبات العامل.
class RecipientPicker extends StatefulWidget {
  const RecipientPicker({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final CashboxRepository repository;
  final ValueChanged<WithdrawalTarget> onChanged;

  @override
  State<RecipientPicker> createState() => _RecipientPickerState();
}

class _RecipientPickerState extends State<RecipientPicker> {
  List<WithdrawalTarget>? _targets;
  String? _selectedId;
  String? _error;

  @override
  void initState() {
    super.initState();
    // تُحمَّل **مرة واحدة** في initState لا في build.
    _load();
  }

  Future<void> _load() async {
    try {
      final targets = await widget.repository.loadTargets();
      if (mounted) setState(() => _targets = targets);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(trf('تعذّر تحميل الحسابات: {0}', [_error]),
          style: const TextStyle(color: AppTheme.danger));
    }
    final targets = _targets;
    if (targets == null) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: LinearProgressIndicator(),
      );
    }
    if (targets.isEmpty) {
      return Text(
        tr('لا توجد حسابات مصروف ولا عمال — أضِفهم من شاشة المصاريف.'),
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: tr('الوجهة (حساب أو عامل)'),
        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(tr('بلا وجهة'))),
        for (final t in targets)
          DropdownMenuItem(
            value: t.id,
            child: Row(
              children: [
                Icon(
                  t.isEmployee ? Icons.badge : Icons.receipt_long,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: (id) {
        setState(() => _selectedId = id);
        final chosen = targets.where((t) => t.id == id).firstOrNull;
        widget.onChanged(chosen ?? const WithdrawalTarget.none());
      },
    );
  }
}
