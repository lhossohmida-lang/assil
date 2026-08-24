import 'dart:math';

final Random _rng = Random.secure();

/// توليد باركود عشوائي بطول ثابت (8 أرقام افتراضاً).
///
/// لماذا 8 وليس 13 — انظر `TicketService.moduleCount`:
/// طول فردي مثل 13 يُجبر Code128 على تبديل مجموعة المحارف فيضيف ~22 وحدة،
/// فيضيق عرض الوحدة على ملصق 40مم إلى نقطتين في طابعة 203dpi،
/// والطابعة تقرّب بعض الخطوط لـ2 وبعضها لـ3 فتتفاوت السماكات ولا يُقرأ الرمز.
String randomNumericBarcode([int length = 8]) {
  final buffer = StringBuffer();
  // الرقم الأول ليس صفراً حتى لا يُقصّ في برامج الجداول عند التصدير.
  buffer.write(1 + _rng.nextInt(9));
  for (var i = 1; i < length; i++) {
    buffer.write(_rng.nextInt(10));
  }
  return buffer.toString();
}
