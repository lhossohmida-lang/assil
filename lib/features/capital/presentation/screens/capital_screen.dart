import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../suppliers/presentation/providers/suppliers_providers.dart';
import '../../domain/capital_math.dart';
import '../../../../core/i18n/app_strings.dart';

final capitalSummaryProvider = Provider<CapitalSummary>((ref) => computeCapital(
      stock: ref.watch(inventoryProvider),
      cash: ref.watch(cashboxBalanceProvider),
      credits: ref.watch(totalCreditsRemainingProvider),
      supplierDebt: ref.watch(totalSupplierDebtProvider),
    ));

class CapitalScreen extends ConsumerWidget {
  const CapitalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(capitalSummaryProvider);

    return AppScaffold(
      route: AppRoutes.capital,
      title: tr('رأس المال والزكاة'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _BigCard(
            title: tr('رأس المال'),
            value: money(s.stockCapital),
            icon: Icons.account_balance,
            color: AppTheme.primary,
            lines: [
              (tr('عدد الأنواع'), '${s.typeCount}'),
              (tr('عدد القطع'), '${s.pieceCount}'),
              (tr('قيمته بسعر البيع'), money(s.stockSellValue)),
              (tr('الفائدة المنتظرة'), money(s.expectedProfit)),
            ],
            footnote: tr('المخزون كلّه مقوَّماً بسعر الشراء.'),
          ),

          _ZakatCard(summary: s),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.lines,
    this.footnote,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<(String, String)> lines;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const Divider(height: 20),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        line.$1,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        line.$2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (footnote != null) ...[
                const SizedBox(height: 8),
                Text(
                  footnote!,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }
}

/// بطاقة الزكاة — تُفصّل الوعاء سطراً سطراً حتى يراجعه صاحب المحل بنفسه.
class _ZakatCard extends StatelessWidget {
  const _ZakatCard({required this.summary});
  final CapitalSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return Card(
      color: const Color(0xFFF1F8E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volunteer_activism,
                    color: AppTheme.success, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('الزكاة'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tr('ربع العشر ٢٫٥٪'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                money(s.zakat),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.success,
                ),
              ),
            ),
            const Divider(height: 22),
            Text(
              tr('تفصيل الوعاء (بسعر البيع)'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _line(tr('المخزون'), money(s.stockSellValue)),
            _line(tr('نقود الصندوق'), money(s.cash)),
            _line(
              tr('كريديات الزبائن (المتبقّي)'),
              money(s.credits),
              hint: tr('دين لنا مرجوّ فيُضاف'),
            ),
            _line(
              tr('دَين الموردين'),
              '− ${money(s.supplierDebt)}',
              hint: tr('دين علينا فيُخصم'),
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('مجموع الوعاء'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      money(s.zakatBase),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tr('هذا حساب تقريبي معين على التقدير؛ الحول والنِّصاب وتفاصيل الديون المشكوك فيها تُراجَع مع أهل العلم.'),
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String key, String value, {String? hint}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('+ ', style: TextStyle(color: AppTheme.textSecondary)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(key, style: const TextStyle(fontSize: 13)),
                  if (hint != null)
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
}
