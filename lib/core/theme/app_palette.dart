import 'package:flutter/material.dart';

/// لوحة ألوان قابلة للاختيار من الإعدادات.
///
/// الألوان **الدلالية** (خطر/نجاح/تحذير) ليست هنا: الأحمر يعني خطراً في كل
/// ثيم، وتغييره مع المظهر يجعل رسائل الخطأ خضراء أحياناً.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.primary,
    required this.primaryDark,
    required this.accent,
  });

  final String id;
  final String nameAr;
  final String nameFr;
  final Color primary;
  final Color primaryDark;
  final Color accent;

  static const List<AppPalette> all = [
    AppPalette(
      id: 'blue',
      nameAr: 'أزرق',
      nameFr: 'Bleu',
      primary: Color(0xFF1565C0),
      primaryDark: Color(0xFF0D47A1),
      accent: Color(0xFF00897B),
    ),
    AppPalette(
      id: 'brown',
      nameAr: 'بنّي',
      nameFr: 'Brun',
      primary: Color(0xFF795548),
      primaryDark: Color(0xFF4E342E),
      accent: Color(0xFF8D6E63),
    ),
    AppPalette(
      id: 'green',
      nameAr: 'أخضر',
      nameFr: 'Vert',
      primary: Color(0xFF2E7D32),
      primaryDark: Color(0xFF1B5E20),
      accent: Color(0xFF00897B),
    ),
    AppPalette(
      id: 'charcoal',
      nameAr: 'فحمي',
      nameFr: 'Anthracite',
      primary: Color(0xFF37474F),
      primaryDark: Color(0xFF263238),
      accent: Color(0xFF546E7A),
    ),
    AppPalette(
      id: 'purple',
      nameAr: 'بنفسجي',
      nameFr: 'Violet',
      primary: Color(0xFF6A1B9A),
      primaryDark: Color(0xFF4A148C),
      accent: Color(0xFF8E24AA),
    ),
  ];

  static AppPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// ألوان السطح والنصوص المشتقّة من المظهر (فاتح/داكن).
///
/// ⚠️ **كل لون نصّ مذكور صراحةً هنا.** العطل الأصلي كان اعتماد الوضع
/// الداكن على الافتراضيات، فتصير النصوص بيضاء على بطاقات بيضاء. الوضع
/// الداكن هنا مبنيّ يدوياً بألوان محسوبة، لا متروكاً للنظام.
class AppSurface {
  const AppSurface({
    required this.background,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.hint,
  });

  final Color background;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color hint;

  static const AppSurface lightSurface = AppSurface(
    background: Color(0xFFF5F7FA),
    card: Colors.white,
    textPrimary: Color(0xFF1A1D21),
    textSecondary: Color(0xFF5C6570),
    border: Color(0xFFE0E4EA),
    hint: Color(0xFF9AA3AE),
  );

  static const AppSurface darkSurface = AppSurface(
    background: Color(0xFF121417),
    card: Color(0xFF1C2026),
    textPrimary: Color(0xFFF1F3F6),
    textSecondary: Color(0xFFA9B2BD),
    border: Color(0xFF2C323A),
    hint: Color(0xFF79828D),
  );
}
