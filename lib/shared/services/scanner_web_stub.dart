import 'dart:async';

import 'package:flutter/material.dart';

Future<String?> scanWeb(
  BuildContext context, {
  required bool continuous,
  FutureOr<void> Function(String code)? onCode,
}) async {
  // هذه النسخة لا تُستعمل إلا في البنية غير الويب؛ وجودها يسمح للمترجم
  // بفصل كود html5-qrcode عن Android/iOS/Windows بالكامل.
  return null;
}
