import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/appearance_store.dart';
import '../../data/settings_repository.dart';
import '../../domain/models/appearance_settings.dart';
import '../../domain/models/store_settings.dart';
import '../../../../core/i18n/app_strings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository?>((ref) {
  final storeId = ref.watch(storeIdProvider);
  if (storeId == null) return null;
  return SettingsRepository(ref.watch(firestoreProvider), storeId);
});

final storeSettingsProvider = StreamProvider<StoreSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  if (repo == null) return Stream.value(const StoreSettings());
  return repo.watch();
});

/// نسبة خصم VIP جاهزة للاستعمال في نقطة البيع بلا انتظار.
final vipDiscountPercentProvider = Provider<double>(
  (ref) => ref.watch(storeSettingsProvider).value?.vipDiscountPercent ?? 10,
);

/// الأقسام المفتوحة بالرقم السرّي **في هذه الجلسة فقط**.
///
/// الفتح لكل قسم على حدة عمداً: فتح المخزون لا يفتح التقارير — لأن البائع
/// قد يحتاج المخزون أمام الزبونة بينما الأرباح تبقى مقفلة.
class UnlockedSections extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void unlock(String section) => state = {...state, section};

  void lockAll() => state = <String>{};
}

final unlockedSectionsProvider =
    NotifierProvider<UnlockedSections, Set<String>>(UnlockedSections.new);


// ───────────────────────── المظهر واللغة ─────────────────────────

/// المظهر المقروء من القرص **قبل** إقلاع الواجهة، ويُحقن من `main()`.
///
/// لماذا لا يُقرأ كسولاً: التطبيق كان يومض بالثيم الافتراضي جزءاً من
/// الثانية ثم يقفز إلى ثيم المستخدم.
final initialAppearanceProvider = Provider<AppearanceSettings>(
  (ref) => throw UnimplementedError(
    tr('initialAppearanceProvider يجب حقنه في ProviderScope من main()'),
  ),
);

class AppearanceNotifier extends Notifier<AppearanceSettings> {
  final AppearanceStore _store = AppearanceStore();

  @override
  AppearanceSettings build() => ref.watch(initialAppearanceProvider);

  Future<void> save(AppearanceSettings next) async {
    state = next;
    await _store.save(next);
  }

  Future<void> setPalette(String id) => save(state.copyWith(paletteId: id));
  Future<void> setDark(bool dark) => save(state.copyWith(dark: dark));
  Future<void> setLanguage(String code) =>
      save(state.copyWith(languageCode: code));
  Future<void> setWatermark(bool show) =>
      save(state.copyWith(showLogoWatermark: show));
  Future<void> setWatermarkOpacity(double v) =>
      save(state.copyWith(watermarkOpacity: v.clamp(0.0, 0.4)));
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceSettings>(
  AppearanceNotifier.new,
);
