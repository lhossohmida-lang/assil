import 'strings_fr.dart';

/// ترجمة نصوص الواجهة.
///
/// ═══ لماذا المفتاح هو النصّ العربي نفسه ═══
/// لا جدول مفاتيح رمزية (`home_title`...) لسببين:
///  1. الكود يبقى مقروءاً: `tr('نقطة البيع')` أوضح من `tr(k.posTitle)`.
///  2. **السقوط الآمن**: أي نصّ بلا ترجمة يظهر بالعربية بدل أن يظهر
///     مفتاحاً غامضاً أو فراغاً. إضافة لغة لا تكسر شيئاً.
///
/// ⚠️ للترجمة فقط ما يُعرض للمستخدم. النصوص التي **تُكتب في قاعدة
/// البيانات** (ملاحظات الحركات، رؤوس ملفات الاستيراد) تبقى عربية دائماً،
/// وإلا فسدت المطابقة مع البيانات القديمة.
class AppLocaleState {
  AppLocaleState._();

  /// اللغة النشطة: 'ar' أو 'fr'. تُضبط في `KmsanApp.build` قبل بناء
  /// أي شاشة، تماماً كما تُضبط لوحة الألوان.
  static String code = 'ar';

  static bool get isFrench => code == 'fr';
}

/// يترجم نصّاً ثابتاً.
String tr(String ar) {
  if (!AppLocaleState.isFrench) return ar;
  return frenchStrings[ar] ?? ar;
}

/// يترجم نصّاً فيه قيم متغيّرة.
///
/// القالب يستعمل `{0}`، `{1}`... مثال:
/// `trf('أُرجع {0} × {1}', [name, qty])`
String trf(String template, List<Object?> args) {
  var out = tr(template);
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', '${args[i]}');
  }
  return out;
}
