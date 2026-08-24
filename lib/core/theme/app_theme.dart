import 'package:flutter/material.dart';

import 'app_palette.dart';

/// ثيم التطبيق.
///
/// ═══ لماذا هذه البنية ═══
/// الألوان **الدلالية** (خطر/نجاح/تحذير) ثوابت حقيقية: الأحمر خطر في كل
/// مظهر. أما ألوان الهوية والأسطح والنصوص فتتبع اللوحة والمظهر المختارين،
/// ولذلك هي **getters لا ثوابت**.
///
/// ⚠️ العطل الذي تحرسه هذه البنية: النسخة الأولى تركت الوضع الداكن
/// للنظام بينما ألوان النصوص مكتوبة يدوياً فاتحة، فصارت الكتابة بيضاء على
/// بطاقات بيضاء. هنا كل لون نصّ وكل خلفية مذكوران صراحةً لكل مظهر.
class AppTheme {
  AppTheme._();

  // ─────────── الألوان الدلالية: ثابتة في كل الثيمات ───────────
  static const Color danger = Color(0xFFC62828);
  static const Color warning = Color(0xFFEF6C00);
  static const Color success = Color(0xFF2E7D32);

  /// لون البائع في السجل. بنفسجي لأنه اللون الوحيد الذي لا يحمل معنى
  /// محاسبياً في هذا التطبيق: الأحمر دَين، والأخضر ربح، والبرتقالي تنبيه.
  /// اسم من باع ليس أياً من ذلك — هو معلومة تعريف لا حكم على الرقم.
  static const Color seller = Color(0xFF6A1B9A);

  // ─────────── الحالة النشطة ───────────
  static AppPalette _palette = AppPalette.all.first;
  static AppSurface _surface = AppSurface.lightSurface;
  static bool _isDark = false;

  static AppPalette get palette => _palette;
  static bool get isDark => _isDark;

  // ألوان تتبع الثيم المختار.
  static Color get primary => _palette.primary;
  static Color get primaryDark => _palette.primaryDark;
  static Color get accent => _palette.accent;
  static Color get surface => _surface.background;
  static Color get cardColor => _surface.card;
  static Color get textPrimary => _surface.textPrimary;
  static Color get textSecondary => _surface.textSecondary;
  static Color get cardBorder => _surface.border;

  /// يبني الثيم ويثبّت اللوحة النشطة.
  ///
  /// يُنادى أثناء بناء `MaterialApp`، أي **قبل** بناء أي شاشة، فتقرأ كل
  /// الشاشات الـ getters أعلاه وهي محدَّثة.
  static ThemeData build({required String paletteId, required bool dark}) {
    _palette = AppPalette.byId(paletteId);
    _isDark = dark;
    _surface = dark ? AppSurface.darkSurface : AppSurface.lightSurface;

    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: _palette.primary,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: _palette.primary,
      secondary: _palette.accent,
      surface: _surface.card,
      error: danger,
      onSurface: _surface.textPrimary,
    );

    return base.copyWith(
      colorScheme: scheme,
      // شفّاف عمداً: الخلفية الملوّنة والعلامة المائية تُرسمان في
      // `LogoWatermark` تحت الـ Navigator. لو رسم الـ Scaffold خلفيته
      // لغطّى الشعار.
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: _surface.card,
      appBarTheme: AppBarTheme(
        backgroundColor: _palette.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface.card,
        elevation: dark ? 0 : 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _surface.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface.card,
        // ⚠️ ألوان النصوص مذكورة صراحةً لكل مظهر — لا تتركها للافتراضيات.
        labelStyle: TextStyle(color: _surface.textSecondary),
        hintStyle: TextStyle(color: _surface.hint),
        helperStyle: TextStyle(color: _surface.textSecondary),
        floatingLabelStyle: TextStyle(color: _palette.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _surface.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _surface.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _palette.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _palette.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _palette.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _palette.primary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: TextStyle(
          color: _surface.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: _surface.textPrimary,
          fontSize: 15,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: _surface.card),
      popupMenuTheme: PopupMenuThemeData(
        color: _surface.card,
        textStyle: TextStyle(color: _surface.textPrimary),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 15),
      ),
      listTileTheme: ListTileThemeData(
        textColor: _surface.textPrimary,
        iconColor: _surface.textSecondary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: _surface.textPrimary,
        displayColor: _surface.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: _surface.border, space: 1),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: _palette.primary,
        collapsedTextColor: _surface.textPrimary,
        iconColor: _palette.primary,
        collapsedIconColor: _surface.textSecondary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surface.background,
        labelStyle: TextStyle(color: _surface.textPrimary),
      ),
    );
  }
}
