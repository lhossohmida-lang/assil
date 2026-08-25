import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/logo_watermark.dart';
import '../providers/auth_providers.dart';

/// شاشة العامل الذي دخل بنجاح لكن بلا أي قسم مسموح.
///
/// ⚠️ سبب وجودها عطبٌ حقيقي: كان `_firstAllowedRoute` يُرجع مسار **شاشة
/// الدخول** حين لا يملك المستخدم أي صلاحية، فيعيد الموجّه العامل إليها
/// فوراً بعد نجاح مصادقته. النتيجة من وجهة نظره: كتب بريده وكلمته، توقّفت
/// الدوّارة، **ولم يحدث شيء** — بلا رسالة ولا سبب. عطبٌ صامت لا يستطيع
/// أحد تشخيصه، لا العامل ولا صاحب المحل.
///
/// الآن يرى سبباً صريحاً وما يفعله. ولا يحتاج إعادة دخول: مستند المستخدم
/// مبثوث (`watchUser`)، فما إن يمنحه صاحب المحل قسماً حتى تتبدّل الجلسة
/// ويُعيد الموجّه تقييمه فينتقل تلقائياً.
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StoreLogo(size: 84),
                const SizedBox(height: 20),
                Icon(Icons.lock_person_outlined,
                    size: 44, color: AppTheme.warning),
                const SizedBox(height: 12),
                Text(
                  tr('حسابك بلا صلاحيات بعد'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('دخلتَ بنجاح، لكن صاحب المحل لم يمنحك أي قسم. اطلب منه فتح قسم لك من شاشة «العمال» — وستدخل فوراً دون إعادة تسجيل الدخول.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          user.name.trim().isEmpty ? user.email : user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (user.email.isNotEmpty)
                          Text(
                            user.email,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(tr('تسجيل الخروج')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شاشة تعذّر فيها تحميل الجلسة (خطأ شبكة أو صلاحيات Firestore).
///
/// ⚠️ كانت حالة الخطأ تُعامَل كأن المستخدم غير مسجَّل دخوله فيُرمى إلى
/// شاشة الدخول بلا كلمة — فيظنّ أن كلمة مروره خاطئة ويعيدها مراراً بلا
/// جدوى. الخطأ الحقيقي يُعرض هنا نصّاً.
class SessionErrorScreen extends ConsumerWidget {
  const SessionErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off, size: 44, color: AppTheme.danger),
                const SizedBox(height: 12),
                Text(
                  tr('تعذّر تحميل حسابك'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(tr('تسجيل الخروج وإعادة المحاولة')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
