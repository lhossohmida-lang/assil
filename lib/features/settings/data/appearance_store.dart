import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/appearance_settings.dart';

/// تخزين المظهر واللغة محلياً لكل جهاز.
class AppearanceStore {
  static const String _key = 'kmsan.appearance.v1';

  Future<AppearanceSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppearanceSettings();
    try {
      return AppearanceSettings.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      // إعدادات تالفة — نعود للافتراضي بدل تعطيل التطبيق.
      return const AppearanceSettings();
    }
  }

  Future<void> save(AppearanceSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toMap()));
  }
}
