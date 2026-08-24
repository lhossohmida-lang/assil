import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';

/// بايتات شعار المحل المخصَّص، أو `null` إن لم يُختَر شعار.
///
/// يفكّ ترميز base64 **مرّة واحدة** لا في كل إعادة بناء: العلامة المائية
/// تُرسم خلف كل شاشة، وفكّ 100 كيلوبايت مع كل إطار كان سيُلاحَظ.
final storeLogoBytesProvider = Provider<Uint8List?>((ref) {
  final settings = ref.watch(storeSettingsProvider).value;
  final encoded = settings?.logoBase64 ?? '';
  if (encoded.isEmpty) return null;
  try {
    return base64Decode(encoded);
  } catch (_) {
    // بيانات تالفة في المستند: نتجاهلها ونعود للشعار المضمَّن بدل
    // أن ينهار التطبيق كلّه عند أول رسم.
    return null;
  }
});

/// الشعار مرسوماً: صورة صاحب المحل إن اختار واحدة، وإلا الشعار المضمَّن.
///
/// [color] تُطبَّق على الشعار المضمَّن فقط (أحادي اللون). الصورة
/// المختارة تُعرض بألوانها كما هي — تلوينها قسراً كان يُحيلها إلى مربّع
/// مصمت حين تكون ملوّنة.
class AppLogo extends ConsumerWidget {
  const AppLogo({
    super.key,
    this.size,
    this.color,
    this.fit = BoxFit.contain,
  });

  final double? size;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custom = ref.watch(storeLogoBytesProvider);

    if (custom != null) {
      return Image.memory(
        custom,
        width: size,
        height: size,
        fit: fit,
        filterQuality: FilterQuality.medium,
        // صورة تالفة لا تُسقط الشاشة — نعود للشعار المضمَّن.
        errorBuilder: (_, _, _) => _bundled(),
      );
    }
    return _bundled();
  }

  /// الشعار المضمَّن: PNG بخلفية شفّافة وخطوط سوداء، مولَّد بـ
  /// `tool/make_logo_asset.dart`. الشفافية شرط التلوين: `srcIn` تصبغ كل
  /// بكسل معتم، فلو بقيت الخلفية بيضاء لصار الشعار مربّعاً مصمتاً.
  Widget _bundled() => Image.asset(
        'assets/images/logo_mark.png',
        width: size,
        height: size,
        fit: fit,
        color: color ?? AppTheme.primary,
        filterQuality: FilterQuality.medium,
      );
}

/// خلفية التطبيق: لون السطح + شعار المحل باهتاً خلف كل الشاشات.
///
/// ⚠️ يعمل فقط لأن `scaffoldBackgroundColor` شفّاف في الثيم: الـ Scaffold
/// لو رسم خلفيته لغطّى الشعار تماماً. الخلفية الملوّنة تُرسم هنا بدلاً منه.
///
/// `IgnorePointer` ضروري: الشعار طبقة زخرفية يجب ألّا تبتلع أي لمسة.
class LogoWatermark extends StatelessWidget {
  const LogoWatermark({
    super.key,
    required this.child,
    required this.enabled,
    required this.opacity,
  });

  final Widget child;
  final bool enabled;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.surface,
      child: Stack(
        children: [
          if (enabled && opacity > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.62,
                    heightFactor: 0.62,
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: AppLogo(color: AppTheme.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// الشعار بحجمه الطبيعي — لشاشة الدخول والقائمة الجانبية.
///
/// يبقى اسماً مستقلاً عن [AppLogo] لأن شاشة الدخول تُبنى **قبل** وجود
/// متجر أصلاً، فلا شعار مخصَّص هناك بحال — و[AppLogo] تتكفّل بذلك من
/// نفسها إذ يعود مزوّد الإعدادات فارغاً.
class StoreLogo extends StatelessWidget {
  const StoreLogo({super.key, this.size = 72, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => AppLogo(size: size, color: color);
}
