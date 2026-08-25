import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/settings_repository.dart';
import '../providers/settings_providers.dart';
import '../../../../core/i18n/app_strings.dart';

/// بوّابة الرقم السرّي.
///
/// تلفّ الأقسام الحسّاسة (الإعدادات، المخزون، التقارير،
/// رأس المال). الفتح **لكل قسم على حدة** ويدوم إلى نهاية الجلسة.
///
/// إن لم يُضبط رقم سرّي بعد فالبوّابة تمرّ (لا شيء لتحميه) مع تنبيه بسيط.
class PinGate extends ConsumerStatefulWidget {
  const PinGate({
    super.key,
    required this.section,
    required this.title,
    required this.child,
  });

  /// اسم القسم — مفتاح الفتح في هذه الجلسة.
  final String section;
  final String title;
  final Widget child;

  @override
  ConsumerState<PinGate> createState() => _PinGateState();
}

class _PinGateState extends ConsumerState<PinGate> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String? pinHash) {
    final entered = _controller.text.trim();
    if (entered.isEmpty) return;
    if (hashPin(entered) == pinHash) {
      ref.read(unlockedSectionsProvider.notifier).unlock(widget.section);
    } else {
      setState(() => _error = tr('الرقم السرّي خاطئ'));
      _controller.clear();
      _focus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storeSettingsProvider);
    final unlocked = ref.watch(unlockedSectionsProvider);

    if (unlocked.contains(widget.section)) return widget.child;

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Center(child: Text(trf('تعذّر قراءة الإعدادات: {0}', [e]))),
      ),
      data: (settings) {
        // لا رقم مضبوط، أو معطَّل، أو هذا القسم غير مختار للقفل ⇒ يمرّ.
        if (!settings.isSectionLocked(widget.section)) return widget.child;

        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline,
                          size: 56, color: AppTheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        trf('قسم محمي — {0}', [widget.title]),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8),
                        decoration: InputDecoration(
                          labelText: tr('الرقم السرّي'),
                          errorText: _error,
                        ),
                        onSubmitted: (_) => _submit(settings.pinHash),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _submit(settings.pinHash),
                          icon: const Icon(Icons.lock_open),
                          label: Text(tr('فتح')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
