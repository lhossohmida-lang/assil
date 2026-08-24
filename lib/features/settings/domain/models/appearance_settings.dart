/// مظهر التطبيق ولغته — **محلية لكل جهاز**.
///
/// لا تُخزَّن في Firestore عمداً: صاحب المحل قد يفضّل العربية على الحاسوب
/// بينما يفضّل عامله الفرنسية على الهاتف، ولكلٍّ شاشته وإضاءته.
class AppearanceSettings {
  const AppearanceSettings({
    this.paletteId = 'blue',
    this.dark = false,
    this.languageCode = 'ar',
    this.showLogoWatermark = true,
    this.watermarkOpacity = 0.05,
  });

  /// معرّف لوحة الألوان (انظر `AppPalette.all`).
  final String paletteId;

  /// الوضع الداكن. مبنيّ يدوياً بألوان صريحة لا متروكاً للنظام.
  final bool dark;

  /// 'ar' أو 'fr'.
  final String languageCode;

  /// شعار المحل كعلامة مائية خلف الشاشات.
  final bool showLogoWatermark;

  /// شفافية العلامة المائية (0 = غير مرئية، 1 = معتمة).
  final double watermarkOpacity;

  bool get isArabic => languageCode == 'ar';

  factory AppearanceSettings.fromMap(Map<String, dynamic> m) =>
      AppearanceSettings(
        paletteId: (m['paletteId'] ?? 'blue') as String,
        dark: (m['dark'] ?? false) as bool,
        languageCode: (m['languageCode'] ?? 'ar') as String,
        showLogoWatermark: (m['showLogoWatermark'] ?? true) as bool,
        watermarkOpacity: (m['watermarkOpacity'] as num?)?.toDouble() ?? 0.05,
      );

  Map<String, dynamic> toMap() => {
        'paletteId': paletteId,
        'dark': dark,
        'languageCode': languageCode,
        'showLogoWatermark': showLogoWatermark,
        'watermarkOpacity': watermarkOpacity,
      };

  AppearanceSettings copyWith({
    String? paletteId,
    bool? dark,
    String? languageCode,
    bool? showLogoWatermark,
    double? watermarkOpacity,
  }) =>
      AppearanceSettings(
        paletteId: paletteId ?? this.paletteId,
        dark: dark ?? this.dark,
        languageCode: languageCode ?? this.languageCode,
        showLogoWatermark: showLogoWatermark ?? this.showLogoWatermark,
        watermarkOpacity: watermarkOpacity ?? this.watermarkOpacity,
      );
}
