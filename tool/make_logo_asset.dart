// يحوّل شعار المحل إلى أصل قابل للتلوين داخل التطبيق.
//
// المشكلة: الشعار الأصلي خطوط سوداء على خلفية **بيضاء معتمة**. التطبيق
// يلوّنه (علامة مائية بلون النصّ، شعار بلون الهوية في القائمة) بـ srcIn،
// وهذه العملية تصبغ كل بكسل غير شفّاف — فتتحوّل الصورة كلّها إلى مربّع
// مصمت لا شعار.
//
// الحل: نجعل الأبيض شفّافاً ونحوّل قتامة كل بكسل إلى قناة ألفا، فيبقى
// شكل الخطوط وحده. عندها يعمل التلوين كما يعمل مع SVG أحادي اللون.
//
// التشغيل:  dart run tool/make_logo_asset.dart

import 'dart:io';

import 'package:image/image.dart';

/// عتبة اعتبار البكسل «خلفية بيضاء».
const int whiteCutoff = 245;

void main() {
  final source = File('tool/assets/logo_source.png');
  if (!source.existsSync()) {
    stderr.writeln('✗ لا يوجد tool/assets/logo_source.png');
    exit(1);
  }

  final decoded = decodeImage(source.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('✗ تعذّر فكّ الترميز');
    exit(1);
  }

  final resized = decoded.width > 512
      ? copyResize(decoded, width: 512, interpolation: Interpolation.cubic)
      : decoded;

  final out = resized.convert(numChannels: 4);
  var opaque = 0;

  for (final pixel in out) {
    // القتامة = 255 - أفتح قناة. الأبيض ⇒ 0 (شفّاف تماماً)،
    // الأسود ⇒ 255 (معتم تماماً)، والرمادي بينهما فتبقى الحواف ناعمة
    // بلا تسنين.
    final maxChannel = [pixel.r, pixel.g, pixel.b]
        .reduce((a, b) => a > b ? a : b)
        .toInt();
    final alpha = maxChannel >= whiteCutoff ? 0 : 255 - maxChannel;
    if (alpha > 0) opaque++;
    // اللون نفسه يصير أسود خالصاً: التلوين لاحقاً يستبدله كلّه، والإبقاء
    // على رماديّاته يجعل الشعار الملوّن يبدو باهتاً.
    pixel.setRgba(0, 0, 0, alpha);
  }

  final target = File('assets/images/logo_mark.png');
  target.writeAsBytesSync(encodePng(out, level: 9));

  final percent = (100 * opaque / (out.width * out.height)).toStringAsFixed(1);
  stdout.writeln('✓ ${target.path}  ${out.width}×${out.height}'
      '  ${target.lengthSync()} بايت');
  stdout.writeln('  بكسلات غير شفّافة: $percent٪ '
      '(لو قاربت 100٪ فالخلفية لم تُزَل)');
}
