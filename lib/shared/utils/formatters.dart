import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_strings.dart';

/// تنسيق المبالغ — **الصيغة الموحّدة الوحيدة في التطبيق**: `X.XX د.ج`.
String money(num? value) =>
    '${(value ?? 0).toDouble().toStringAsFixed(2)} ${AppConstants.currencySymbol}';

/// نفس التنسيق بلا رمز العملة (للجداول الضيّقة وملفات التصدير).
String moneyPlain(num? value) => (value ?? 0).toDouble().toStringAsFixed(2);

final DateFormat _dateFmt = DateFormat('yyyy/MM/dd');
final DateFormat _timeFmt = DateFormat('HH:mm');
final DateFormat _dateTimeFmt = DateFormat('yyyy/MM/dd HH:mm');

String formatDate(DateTime? d) => d == null ? '—' : _dateFmt.format(d);
String formatTime(DateTime? d) => d == null ? '—' : _timeFmt.format(d);
String formatDateTime(DateTime? d) => d == null ? '—' : _dateTimeFmt.format(d);

/// «اليوم» / «أمس» / التاريخ — لعناوين مجموعات الفواتير.
String formatDayLabel(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  final diff = today.difference(target).inDays;
  if (diff == 0) return tr('اليوم');
  if (diff == 1) return tr('أمس');
  return _dateFmt.format(day);
}

/// تحويل آمن إلى double مهما كان مصدر القيمة (Firestore يرجع int أحياناً،
/// وملفات الاستيراد ترجع نصوصاً بفواصل عربية أو عشرية بفاصلة).
double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().trim().replaceAll('٫', '.').replaceAll(',', '.');
  return double.tryParse(s) ?? 0;
}

int toInt(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.round();
  final s = v.toString().trim().replaceAll('٫', '.').replaceAll(',', '.');
  return (double.tryParse(s) ?? 0).round();
}

/// تنظيف مدخل الباركود.
///
/// الماسحات (السلكية خصوصاً) تُلحق `\r` أو `\n` أو محارف تحكّم خفية،
/// فتفشل المطابقة التامة **بصمت** ويظن البائع أن المنتج غير موجود.
String cleanBarcode(String raw) =>
    raw.replaceAll(RegExp(r'\s'), '').replaceAll(RegExp(r'[\u0000-\u001F]'), '');

/// تطبيع نص للبحث: حروف صغيرة + بلا مسافات زائدة + توحيد الألف والياء.
String normalizeForSearch(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'\s+'), ' ');
