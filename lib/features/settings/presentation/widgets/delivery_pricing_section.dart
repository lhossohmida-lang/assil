import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/wilayas.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../providers/settings_providers.dart';

/// أسعار التوصيل لولايات الجزائر الـ58.
///
/// ═══ لماذا سعر موحّد + استثناءات ═══
/// إجبار صاحب المحل على ملء 58 خانة قبل أن يبيع شيئاً واحداً هو أسرع
/// طريق لأن يترك الشاشة كلّها فارغة. فالسعر الموحّد يعمل من اللحظة
/// الأولى، والولايات تُستثنى واحدة واحدة متى احتاج.
class DeliveryPricingSection extends ConsumerStatefulWidget {
  const DeliveryPricingSection({super.key});

  @override
  ConsumerState<DeliveryPricingSection> createState() =>
      _DeliveryPricingSectionState();
}

class _DeliveryPricingSectionState
    extends ConsumerState<DeliveryPricingSection> {
  final _defaultFee = TextEditingController();
  final _search = TextEditingController();
  bool _initialized = false;
  bool _onlyCustom = false;
  bool _expanded = false;

  @override
  void dispose() {
    _defaultFee.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _save(DeliveryPricing next) async {
    await ref.read(settingsRepositoryProvider)?.setDelivery(next);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeSettingsProvider).value;
    final pricing = settings?.delivery ?? const DeliveryPricing();

    if (settings != null && !_initialized) {
      _defaultFee.text =
          pricing.defaultFee == 0 ? '' : moneyPlain(pricing.defaultFee);
      _initialized = true;
    }

    final query = normalizeForSearch(_search.text);
    final visible = algeriaWilayas.where((w) {
      if (_onlyCustom && !pricing.byWilaya.containsKey(w)) return false;
      if (query.isEmpty) return true;
      return normalizeForSearch(w).contains(query) ||
          wilayaNumber(w).contains(query);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('أسعار التوصيل'),
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                if (pricing.customCount > 0)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      trf('{0} ولاية بسعر خاص', [pricing.customCount]),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ─── السعر الموحّد ───
            TextField(
              controller: _defaultFee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٫]')),
              ],
              onSubmitted: (_) => _saveDefault(pricing),
              decoration: InputDecoration(
                isDense: true,
                labelText: tr('السعر الموحّد لكل الولايات'),
                suffixText: tr('د.ج'),
                helperText: tr('يُستعمل لأي ولاية لم تضبط لها سعراً خاصاً.'),
                helperMaxLines: 2,
                suffixIcon: IconButton(
                  tooltip: tr('حفظ'),
                  icon: const Icon(Icons.check, size: 20),
                  onPressed: () => _saveDefault(pricing),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ─── فتح قائمة الولايات ───
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              label: Text(_expanded
                  ? tr('إخفاء الولايات')
                  : tr('تحديد سعر لولاية بعينها')),
            ),

            if (_expanded) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: tr('ابحث عن ولاية أو رقمها...'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(tr('المضبوطة فقط')),
                    selected: _onlyCustom,
                    onSelected: (v) => setState(() => _onlyCustom = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _onlyCustom
                        ? tr('لا ولاية بسعر خاص بعد.')
                        : tr('لا نتيجة لبحثك.'),
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                )
              else
                // ارتفاع محدود: 58 صفاً داخل شاشة إعدادات تمرّر بنفسها
                // تجعل التمرير معركة بين قائمتين.
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, i) => _WilayaRow(
                      wilaya: visible[i],
                      number: wilayaNumber(visible[i]),
                      fee: pricing.byWilaya[visible[i]],
                      fallback: pricing.defaultFee,
                      onSet: (v) => _save(pricing.withWilaya(visible[i], v)),
                      onClear: () => _save(pricing.clearWilaya(visible[i])),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveDefault(DeliveryPricing pricing) async {
    final value = toDouble(_defaultFee.text);
    await _save(pricing.copyWith(defaultFee: value < 0 ? 0 : value));
    if (mounted) showOk(context, tr('حُفظ سعر التوصيل'));
  }
}

class _WilayaRow extends StatefulWidget {
  const _WilayaRow({
    required this.wilaya,
    required this.number,
    required this.fee,
    required this.fallback,
    required this.onSet,
    required this.onClear,
  });

  final String wilaya;
  final String number;

  /// `null` = لا سعر خاص، تُستعمل [fallback].
  final double? fee;
  final double fallback;
  final ValueChanged<double> onSet;
  final VoidCallback onClear;

  @override
  State<_WilayaRow> createState() => _WilayaRowState();
}

class _WilayaRowState extends State<_WilayaRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.fee == null ? '' : moneyPlain(widget.fee!),
  );

  @override
  void didUpdateWidget(_WilayaRow old) {
    super.didUpdateWidget(old);
    // القائمة تُعيد استعمال الصفوف عند البحث؛ بلا هذا يظهر سعر ولاية
    // أمام اسم ولاية أخرى.
    if (old.wilaya != widget.wilaya) {
      _controller.text = widget.fee == null ? '' : moneyPlain(widget.fee!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onClear();
      return;
    }
    widget.onSet(toDouble(text));
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.fee != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              widget.number,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.wilaya,
              style: TextStyle(
                fontSize: 13,
                fontWeight: custom ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Focus(
              onFocusChange: (has) {
                if (!has) _commit();
              },
              child: TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٫]')),
                ],
                onSubmitted: (_) => _commit(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  hintText: moneyPlain(widget.fallback),
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: tr('إعادة إلى السعر الموحّد'),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.backspace_outlined,
              size: 16,
              color: custom ? AppTheme.danger : AppTheme.textSecondary,
            ),
            onPressed: custom
                ? () {
                    _controller.clear();
                    widget.onClear();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
