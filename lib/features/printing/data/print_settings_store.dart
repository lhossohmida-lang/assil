import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/print_settings.dart';

/// تخزين إعدادات الطباعة **محلياً لكل جهاز**.
class PrintSettingsStore {
  static const String _key = 'kmsan.print_settings.v1';

  Future<PrintSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const PrintSettings();
    try {
      return PrintSettings.fromMap(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      // إعدادات تالفة (نسخة أقدم مثلاً) — نعود للافتراضي بدل تعطيل الطباعة.
      return const PrintSettings();
    }
  }

  Future<void> save(PrintSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toMap()));
  }
}
