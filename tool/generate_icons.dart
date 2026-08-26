// توليد أيقونات التطبيق من `tool/assets/logo_source.png` مصدراً وحيداً.
//
// المصدر خارج `assets/` عمداً: كل ما في `assets/` يُحزَم داخل التطبيق،
// وصورة المصدر (1.1 م.ب) لا يقرأها التطبيق أبداً — يقرأ المولَّد منها.
//
// لماذا سكربت بدل حزمة `flutter_launcher_icons`؟ لأن `package:image` موجود
// أصلاً في التبعيات للضغط، فلا داعي لإضافة حزمة تطوير كاملة لعمل يُنفَّذ
// مرّة كل تغيير شعار.
//
// التشغيل:  dart run tool/generate_icons.dart
//
// ⚠️ الشعار خطوط سوداء على خلفية بيضاء. لو تُرك بشفافية لظهر أسود على أسود
// في مشغّلات الأندرويد الداكنة، فنفرض خلفية بيضاء صراحةً.

import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart';

/// مقاسات أيقونات أندرويد بحسب كثافة الشاشة.
const Map<String, int> androidSizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

/// المقاسات التي يضعها ويندوز داخل ملف ICO واحد. 256 ضرورية لعرض
/// «الأيقونات الكبيرة» في مستكشف الملفات، و16 لشريط المهام.
const List<int> icoSizes = [16, 24, 32, 48, 64, 128, 256];

void main(List<String> args) {
  final sourcePath = args.isNotEmpty ? args.first : 'tool/assets/logo_source.png';
  final source = File(sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('✗ لا يوجد ملف: $sourcePath');
    exit(1);
  }

  final decoded = decodeImage(source.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('✗ تعذّر فكّ ترميز الصورة: $sourcePath');
    exit(1);
  }
  stdout.writeln('المصدر: ${decoded.width}×${decoded.height}');

  final square = _squareOnWhite(decoded);

  // ─────────────── أندرويد ───────────────
  for (final entry in androidSizes.entries) {
    final out = File('android/app/src/main/res/${entry.key}/ic_launcher.png');
    out.parent.createSync(recursive: true);
    final resized = copyResize(
      square,
      width: entry.value,
      height: entry.value,
      interpolation: Interpolation.cubic,
    );
    out.writeAsBytesSync(encodePng(resized, level: 9));
    stdout.writeln('✓ ${out.path}  (${entry.value}×${entry.value})');
  }

  // ─────────────── ويندوز ───────────────
  final ico = File('windows/runner/resources/app_icon.ico');
  ico.parent.createSync(recursive: true);
  ico.writeAsBytesSync(_buildIco(square));
  stdout.writeln('✓ ${ico.path}  (${icoSizes.join(", ")})');

  // ─────────────── iOS ───────────────
  //
  // الأسماء والمقاسات مأخوذة من `Contents.json` الذي يولّده Flutter.
  // ⚠️ أيقونة iOS **لا تقبل الشفافية**: يرفضها App Store وتظهر سوداء
  // على الجهاز. لذلك نكتب المربّع ذا الخلفية البيضاء لا `logo_mark`.
  const iosIcons = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  final iosDir = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
  if (iosDir.existsSync()) {
    for (final entry in iosIcons.entries) {
      final resized = copyResize(
        square,
        width: entry.value,
        height: entry.value,
        interpolation: Interpolation.cubic,
      );
      File('${iosDir.path}/${entry.key}')
          .writeAsBytesSync(encodePng(resized, level: 9));
    }
    stdout.writeln('✓ ${iosDir.path}  (${iosIcons.length} مقاساً)');
  }

  // ─────────────── المتجر الإلكتروني ───────────────
  final favicon = File('storefront/public/favicon.png');
  if (favicon.parent.existsSync()) {
    final resized = copyResize(square,
        width: 256, height: 256, interpolation: Interpolation.cubic);
    favicon.writeAsBytesSync(encodePng(resized, level: 9));
    stdout.writeln('✓ ${favicon.path}  (256×256)');
  }
}

/// يجعل الصورة مربّعة (بحشو متمركز) فوق خلفية بيضاء معتمة.
///
/// الحشو ضروري: لو مُدّت صورة مستطيلة إلى مربّع لانضغطت الدائرة إلى بيضة.
Image _squareOnWhite(Image src) {
  final side = src.width > src.height ? src.width : src.height;
  final canvas = Image(width: side, height: side, numChannels: 4);
  fill(canvas, color: ColorRgba8(255, 255, 255, 255));
  compositeImage(
    canvas,
    src,
    dstX: (side - src.width) ~/ 2,
    dstY: (side - src.height) ~/ 2,
  );
  return canvas;
}

/// يبني ملف ICO يدوياً.
///
/// `package:image` يكتب ICO لكن بمقاس واحد؛ ويندوز يحتاج عدّة مقاسات في
/// الملف نفسه وإلا اختار الأقرب وكبّره فبدت الأيقونة مهترئة في شريط المهام.
/// الصيغة بسيطة: ترويسة 6 بايت + مدخل 16 بايت لكل صورة + صور PNG متتالية.
Uint8List _buildIco(Image square) {
  final images = <Uint8List>[];
  for (final size in icoSizes) {
    final resized = copyResize(
      square,
      width: size,
      height: size,
      interpolation: Interpolation.cubic,
    );
    images.add(Uint8List.fromList(encodePng(resized, level: 9)));
  }

  const headerSize = 6;
  const entrySize = 16;
  var offset = headerSize + entrySize * images.length;

  final out = BytesBuilder();

  // ICONDIR: محجوز(0) + النوع(1 = أيقونة) + العدد
  out.add(_u16(0));
  out.add(_u16(1));
  out.add(_u16(images.length));

  // ICONDIRENTRY لكل صورة
  for (var i = 0; i < images.length; i++) {
    final size = icoSizes[i];
    out.addByte(size >= 256 ? 0 : size); // 0 تعني 256 — البايت لا يسعها
    out.addByte(size >= 256 ? 0 : size);
    out.addByte(0); // عدد ألوان اللوحة (0 = بلا لوحة)
    out.addByte(0); // محجوز
    out.add(_u16(1)); // مستويات الألوان
    out.add(_u16(32)); // بت لكل بكسل
    out.add(_u32(images[i].length));
    out.add(_u32(offset));
    offset += images[i].length;
  }

  for (final bytes in images) {
    out.add(bytes);
  }
  return out.toBytes();
}

List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> _u32(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];
