import '../../../../shared/utils/formatters.dart';
import '../../../../core/i18n/app_strings.dart';

/// محاذاة نصّ على الوصل.
enum ReceiptAlign { start, center, end }

extension ReceiptAlignLabel on ReceiptAlign {
  String get label => switch (this) {
        ReceiptAlign.start => tr('يمين'),
        ReceiptAlign.center => tr('وسط'),
        ReceiptAlign.end => tr('يسار'),
      };

  String get code => switch (this) {
        ReceiptAlign.start => 'start',
        ReceiptAlign.center => 'center',
        ReceiptAlign.end => 'end',
      };

  static ReceiptAlign parse(String? s) => switch (s) {
        'start' => ReceiptAlign.start,
        'end' => ReceiptAlign.end,
        _ => ReceiptAlign.center,
      };
}

/// سطر حرّ يكتبه صاحب المحل على الوصل: فيسبوك، هاتف، شكر، أي شيء.
class ReceiptLine {
  const ReceiptLine({
    required this.text,
    this.align = ReceiptAlign.center,
    this.bold = false,
    this.fontSize = 9,
    this.footer = true,
  });

  final String text;
  final ReceiptAlign align;
  final bool bold;
  final double fontSize;

  /// `true` = أسفل الوصل، `false` = أعلاه تحت اسم المحل.
  final bool footer;

  factory ReceiptLine.fromMap(Map<String, dynamic> m) => ReceiptLine(
        text: (m['text'] ?? '') as String,
        align: ReceiptAlignLabel.parse(m['align'] as String?),
        bold: (m['bold'] ?? false) as bool,
        fontSize: m['fontSize'] == null ? 9 : toDouble(m['fontSize']),
        footer: (m['footer'] ?? true) as bool,
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'align': align.code,
        'bold': bold,
        'fontSize': fontSize,
        'footer': footer,
      };

  ReceiptLine copyWith({
    String? text,
    ReceiptAlign? align,
    bool? bold,
    double? fontSize,
    bool? footer,
  }) =>
      ReceiptLine(
        text: text ?? this.text,
        align: align ?? this.align,
        bold: bold ?? this.bold,
        fontSize: fontSize ?? this.fontSize,
        footer: footer ?? this.footer,
      );
}

/// شعار الوصل: مكانه وحجمه ومصدره.
class ReceiptLogo {
  const ReceiptLogo({
    this.enabled = true,
    this.widthMm = 22,
    this.align = ReceiptAlign.center,
    this.footer = false,
    this.imageBase64 = '',
  });

  final bool enabled;

  /// عرض الشعار على الورق.
  final double widthMm;

  final ReceiptAlign align;

  /// `true` = أسفل الوصل، `false` = أعلاه.
  final bool footer;

  /// صورة اختارها المستخدم (PNG/JPG) مخزَّنة base64.
  /// فارغة ⇒ شعار المحل المشترك، وإلا الشعار المضمَّن `logo_mark.png`.
  final String imageBase64;

  bool get usesCustomImage => imageBase64.isNotEmpty;

  factory ReceiptLogo.fromMap(Map<String, dynamic> m) => ReceiptLogo(
        enabled: (m['enabled'] ?? true) as bool,
        widthMm: m['widthMm'] == null ? 22 : toDouble(m['widthMm']),
        align: ReceiptAlignLabel.parse(m['align'] as String?),
        footer: (m['footer'] ?? false) as bool,
        imageBase64: (m['imageBase64'] ?? '') as String,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'widthMm': widthMm,
        'align': align.code,
        'footer': footer,
        'imageBase64': imageBase64,
      };

  ReceiptLogo copyWith({
    bool? enabled,
    double? widthMm,
    ReceiptAlign? align,
    bool? footer,
    String? imageBase64,
  }) =>
      ReceiptLogo(
        enabled: enabled ?? this.enabled,
        widthMm: widthMm ?? this.widthMm,
        align: align ?? this.align,
        footer: footer ?? this.footer,
        imageBase64: imageBase64 ?? this.imageBase64,
      );
}

/// رموز QR لروابط التواصل على الوصل.
class ReceiptQr {
  const ReceiptQr({
    this.showFacebook = false,
    this.showInstagram = false,
    this.sizeMm = 20,
    this.withLabels = true,
  });

  final bool showFacebook;
  final bool showInstagram;
  final double sizeMm;
  final bool withLabels;

  bool get any => showFacebook || showInstagram;

  factory ReceiptQr.fromMap(Map<String, dynamic> m) => ReceiptQr(
        showFacebook: (m['showFacebook'] ?? false) as bool,
        showInstagram: (m['showInstagram'] ?? false) as bool,
        sizeMm: m['sizeMm'] == null ? 20 : toDouble(m['sizeMm']),
        withLabels: (m['withLabels'] ?? true) as bool,
      );

  Map<String, dynamic> toMap() => {
        'showFacebook': showFacebook,
        'showInstagram': showInstagram,
        'sizeMm': sizeMm,
        'withLabels': withLabels,
      };

  ReceiptQr copyWith({
    bool? showFacebook,
    bool? showInstagram,
    double? sizeMm,
    bool? withLabels,
  }) =>
      ReceiptQr(
        showFacebook: showFacebook ?? this.showFacebook,
        showInstagram: showInstagram ?? this.showInstagram,
        sizeMm: sizeMm ?? this.sizeMm,
        withLabels: withLabels ?? this.withLabels,
      );
}
