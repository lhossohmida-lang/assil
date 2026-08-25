import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/i18n/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/printing/data/print_settings_store.dart';
import 'features/printing/presentation/providers/printing_providers.dart';
import 'features/printing/services/pdf_fonts.dart';
import 'features/printing/services/print_service.dart';
import 'features/printing/services/print_worker.dart';
import 'features/settings/data/appearance_store.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'firebase_options.dart';
import 'shared/services/scanner_service.dart';
import 'shared/widgets/logo_watermark.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تخزين محلي بلا حدّ حجم: المحل يعمل ساعات بلا إنترنت أحياناً،
  // والبيع يجب ألّا يتوقّف. Firestore يُزامن وحده عند عودة الاتصال.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // الإعدادات المحلية تُقرأ **قبل** الواجهة: أول طباعة كانت تخرج بإعدادات
  // افتراضية، والتطبيق كان يومض بالثيم الافتراضي قبل ثيم المستخدم.
  final printSettings = await PrintSettingsStore().load();
  final appearance = await AppearanceStore().load();

  // تحميل خط Amiri مسبقاً حتى تكون أول طباعة سريعة كالبقية.
  unawaited(PdfFonts.warmUp());
  unawaited(ScannerService.prefetch());

  runApp(
    ProviderScope(
      overrides: [
        initialPrintSettingsProvider.overrideWithValue(printSettings),
        initialAppearanceProvider.overrideWithValue(appearance),
      ],
      child: const KmsanApp(),
    ),
  );
}

class KmsanApp extends ConsumerWidget {
  const KmsanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appearance = ref.watch(appearanceProvider);

    // يثبّت اللغة النشطة قبل بناء أي شاشة — تماماً كاللوحة.
    // `tr()` دالة عامة تقرأ هذا الحقل، فلا تحتاج كل شاشة إلى context.
    AppLocaleState.code = appearance.languageCode;

    // يبني الثيم **ويثبّت اللوحة النشطة** قبل بناء أي شاشة.
    final theme = AppTheme.build(
      paletteId: appearance.paletteId,
      dark: appearance.dark,
    );

    final isArabic = appearance.isArabic;

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // مظهر واحد صريح: `theme` و`darkTheme` نفس الشيء و`themeMode.light`،
      // فلا يتدخّل النظام في اختيار المستخدم. الوضع الداكن يُختار من
      // الإعدادات ويُبنى بألوان صريحة داخل AppTheme.build.
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.light,

      locale: Locale(appearance.languageCode),
      supportedLocales: const [Locale('ar'), Locale('fr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,

      builder: (context, child) => Directionality(
        // العربية من اليمين، الفرنسية من اليسار.
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: LogoWatermark(
          enabled: appearance.showLogoWatermark,
          opacity: appearance.watermarkOpacity,
          // 🔒 المفتاح المرتبط باللغة ليس تجميلاً — بدونه لا تُترجم
          // عناوين الشاشات إطلاقاً عند تبديل اللغة.
          //
          // السبب: شاشات الراوتر مسجَّلة نسخاً `const` (`const PosScreen()`)،
          // وFlutter يتخطّى إعادة بناء أي widget نسخته **متطابقة** مع
          // السابقة. فكانت الأجزاء المرتبطة بالمزوّدات وحدها تُعاد
          // (المحتوى يتغيّر) بينما تبقى عناوين الحقول بالعربية — لأن
          // `tr()` قُيّمت مرّة واحدة عند أول بناء ولم تُقيَّم ثانيةً.
          //
          // تغيير المفتاح يهدم الشجرة ويبنيها من جديد، فتُقيَّم `tr()`
          // كلّها باللغة الجديدة. المسار المفتوح محفوظ في go_router خارج
          // الشجرة فلا يضيع؛ ما يضيع نصّ نصف مكتوب في حقل، وهو مقبول
          // في لحظة تبديل لغة.
          child: KeyedSubtree(
            key: ValueKey(appearance.languageCode),
            child: _PrintWorkerHost(child: child ?? const SizedBox()),
          ),
        ),
      ),
    );
  }
}

/// يشغّل عامل الطباعة عن بُعد مرة واحدة لكل متجر — **على الحاسوب فقط**.
///
/// موضعه في جذر التطبيق لا في شاشة معيّنة: أوامر الهاتف يجب أن تُطبع
/// أياً كانت الشاشة المفتوحة على الحاسوب.
class _PrintWorkerHost extends ConsumerStatefulWidget {
  const _PrintWorkerHost({required this.child});
  final Widget child;

  @override
  ConsumerState<_PrintWorkerHost> createState() => _PrintWorkerHostState();
}

class _PrintWorkerHostState extends ConsumerState<_PrintWorkerHost> {
  PrintWorker? _worker;
  String? _workerStoreId;

  @override
  void dispose() {
    _worker?.stop();
    super.dispose();
  }

  void _sync(String? storeId) {
    if (!PrintService.canPrintLocally) return;
    if (storeId == _workerStoreId) return;

    _worker?.stop();
    _worker = null;
    _workerStoreId = storeId;
    if (storeId == null) return;

    final queue = ref.read(printQueueRepositoryProvider);
    if (queue == null) return;

    _worker = PrintWorker(
      db: ref.read(firestoreProvider),
      storeId: storeId,
      queue: queue,
      // دالة لا قيمة: الإعدادات قد تتغيّر بين وظيفة وأخرى.
      printService: () => ref.read(printServiceProvider),
    )..start();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(storeIdProvider, (_, next) => _sync(next));
    // أول بناء: الجلسة قد تكون جاهزة قبل تسجيل المستمع.
    _sync(ref.read(storeIdProvider));
    return widget.child;
  }
}

/// طباعة تشخيصية تختفي في الإصدار النهائي.
void logDebug(Object? message) {
  if (kDebugMode) debugPrint('[KMSAN] $message');
}
