import '../../../../shared/utils/formatters.dart';
import 'receipt_content.dart';

/// إعدادات وصل البيع (بكرة 80مم عادةً).
class ReceiptSettings {
  final String printerName;

  /// عرض البكرة بالمليمتر (80 عادةً — منطقة الطباعة الفعلية ~72).
  final double widthMm;
  final double marginMm;

  /// تغذية إضافية بعد القصّ — بعض الطابعات تقصّ فوق آخر سطر.
  final double extraFeedMm;

  final double fontScale;

  /// اسم المحل في رأس الوصل ومحاذاته.
  final bool showStoreName;
  final ReceiptAlign storeNameAlign;

  /// الاسم المطبوع فعلاً. فارغ ⇒ `AppConstants.storeDisplayName`.
  ///
  /// محلّي لكل جهاز كبقيّة إعدادات الطباعة: قد يطبع فرعان وصلين باسمين
  /// مختلفين، ولا يُعقل أن يغيّر أحدهما اسمَ الآخر.
  final String storeName;

  /// أسطر حرّة يكتبها صاحب المحل (فيسبوك، هاتف، شكر...).
  final List<ReceiptLine> lines;

  final ReceiptLogo logo;
  final ReceiptQr qr;

  const ReceiptSettings({
    this.printerName = '',
    this.widthMm = 80,
    this.marginMm = 3,
    this.extraFeedMm = 0,
    this.fontScale = 1.0,
    this.showStoreName = true,
    this.storeNameAlign = ReceiptAlign.center,
    this.storeName = '',
    // سطر شكر افتراضي — يُعدَّل أو يُحذف من الإعدادات.
    // يبقى عربياً هنا لأنه **قيمة افتراضية مخزَّنة** لا نصّ واجهة؛
    // صاحب المحل يعدّله بلغته من الإعدادات.
    this.lines = const [
      ReceiptLine(text: 'شكراً لتسوّقكم معنا', fontSize: 10),
    ],
    this.logo = const ReceiptLogo(),
    this.qr = const ReceiptQr(),
  });

  List<ReceiptLine> get headerLines =>
      lines.where((l) => !l.footer).toList();
  List<ReceiptLine> get footerLines => lines.where((l) => l.footer).toList();

  factory ReceiptSettings.fromMap(Map<String, dynamic> m) => ReceiptSettings(
        printerName: (m['printerName'] ?? '') as String,
        widthMm: m['widthMm'] == null ? 80 : toDouble(m['widthMm']),
        marginMm: m['marginMm'] == null ? 3 : toDouble(m['marginMm']),
        extraFeedMm: toDouble(m['extraFeedMm']),
        fontScale: m['fontScale'] == null ? 1.0 : toDouble(m['fontScale']),
        showStoreName: (m['showStoreName'] ?? true) as bool,
        storeNameAlign: ReceiptAlignLabel.parse(m['storeNameAlign'] as String?),
        storeName: (m['storeName'] ?? '') as String,
        lines: ((m['lines'] ?? const []) as List)
            .map((e) => ReceiptLine.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        logo: ReceiptLogo.fromMap(
            Map<String, dynamic>.from((m['logo'] ?? const {}) as Map)),
        qr: ReceiptQr.fromMap(
            Map<String, dynamic>.from((m['qr'] ?? const {}) as Map)),
      );

  Map<String, dynamic> toMap() => {
        'printerName': printerName,
        'widthMm': widthMm,
        'marginMm': marginMm,
        'extraFeedMm': extraFeedMm,
        'fontScale': fontScale,
        'showStoreName': showStoreName,
        'storeNameAlign': storeNameAlign.code,
        'storeName': storeName,
        'lines': lines.map((l) => l.toMap()).toList(),
        'logo': logo.toMap(),
        'qr': qr.toMap(),
      };

  ReceiptSettings copyWith({
    String? printerName,
    double? widthMm,
    double? marginMm,
    double? extraFeedMm,
    double? fontScale,
    bool? showStoreName,
    ReceiptAlign? storeNameAlign,
    String? storeName,
    List<ReceiptLine>? lines,
    ReceiptLogo? logo,
    ReceiptQr? qr,
  }) =>
      ReceiptSettings(
        printerName: printerName ?? this.printerName,
        widthMm: widthMm ?? this.widthMm,
        marginMm: marginMm ?? this.marginMm,
        extraFeedMm: extraFeedMm ?? this.extraFeedMm,
        fontScale: fontScale ?? this.fontScale,
        showStoreName: showStoreName ?? this.showStoreName,
        storeNameAlign: storeNameAlign ?? this.storeNameAlign,
        storeName: storeName ?? this.storeName,
        lines: lines ?? this.lines,
        logo: logo ?? this.logo,
        qr: qr ?? this.qr,
      );
}

/// إعدادات تيكت الباركود (ملصق 40×20مم عادةً).
class TicketSettings {
  final String printerName;
  final double labelWidthMm;
  final double labelHeightMm;

  /// **الخطوة بين ملصقين** = الملصق + الفجوة. صفر يعني «مثل ارتفاع الملصق».
  ///
  /// ارتفاع الصفحة المرسلة = الخطوة، والمحتوى محصور في ارتفاع الملصق —
  /// وإلا تراكمت الفجوات وانزاحت الطباعة عن الملصق بعد بضع قطع.
  final double pitchMm;

  /// دقّة الطابعة نقطة/بوصة. 203 هو المعتاد في طابعات الملصقات الحرارية.
  /// تُستعمل في حساب عرض الباركود كمضاعف صحيح لنقطة الطابعة.
  final int dpi;

  final double offsetXMm;
  final double offsetYMm;

  final bool showStoreName;
  final bool showPrice;
  final bool showBarcodeText;

  /// إطار رفيع حول الملصق لمعايرة الإزاحة بالعين.
  final bool drawCalibrationFrame;

  final double fontScale;

  /// ضبط مقاس ورق الدرايفر قبل الطباعة (يمنع الملصقات الفارغة).
  final bool applyDriverPaperSize;

  const TicketSettings({
    this.printerName = '',
    this.labelWidthMm = 40,
    this.labelHeightMm = 20,
    this.pitchMm = 0,
    this.dpi = 203,
    this.offsetXMm = 0,
    this.offsetYMm = 0,
    this.showStoreName = true,
    this.showPrice = true,
    this.showBarcodeText = true,
    this.drawCalibrationFrame = false,
    this.fontScale = 1.0,
    this.applyDriverPaperSize = true,
  });

  /// الخطوة الفعلية المستعملة في ارتفاع الصفحة.
  double get effectivePitchMm => pitchMm > 0 ? pitchMm : labelHeightMm;

  /// حجم نقطة الطابعة الواحدة بالمليمتر.
  double get dotMm => 25.4 / dpi;

  factory TicketSettings.fromMap(Map<String, dynamic> m) => TicketSettings(
        printerName: (m['printerName'] ?? '') as String,
        labelWidthMm: m['labelWidthMm'] == null ? 40 : toDouble(m['labelWidthMm']),
        labelHeightMm:
            m['labelHeightMm'] == null ? 20 : toDouble(m['labelHeightMm']),
        pitchMm: toDouble(m['pitchMm']),
        dpi: m['dpi'] == null ? 203 : toInt(m['dpi']),
        offsetXMm: toDouble(m['offsetXMm']),
        offsetYMm: toDouble(m['offsetYMm']),
        showStoreName: (m['showStoreName'] ?? true) as bool,
        showPrice: (m['showPrice'] ?? true) as bool,
        showBarcodeText: (m['showBarcodeText'] ?? true) as bool,
        drawCalibrationFrame: (m['drawCalibrationFrame'] ?? false) as bool,
        fontScale: m['fontScale'] == null ? 1.0 : toDouble(m['fontScale']),
        applyDriverPaperSize: (m['applyDriverPaperSize'] ?? true) as bool,
      );

  Map<String, dynamic> toMap() => {
        'printerName': printerName,
        'labelWidthMm': labelWidthMm,
        'labelHeightMm': labelHeightMm,
        'pitchMm': pitchMm,
        'dpi': dpi,
        'offsetXMm': offsetXMm,
        'offsetYMm': offsetYMm,
        'showStoreName': showStoreName,
        'showPrice': showPrice,
        'showBarcodeText': showBarcodeText,
        'drawCalibrationFrame': drawCalibrationFrame,
        'fontScale': fontScale,
        'applyDriverPaperSize': applyDriverPaperSize,
      };

  TicketSettings copyWith({
    String? printerName,
    double? labelWidthMm,
    double? labelHeightMm,
    double? pitchMm,
    int? dpi,
    double? offsetXMm,
    double? offsetYMm,
    bool? showStoreName,
    bool? showPrice,
    bool? showBarcodeText,
    bool? drawCalibrationFrame,
    double? fontScale,
    bool? applyDriverPaperSize,
  }) =>
      TicketSettings(
        printerName: printerName ?? this.printerName,
        labelWidthMm: labelWidthMm ?? this.labelWidthMm,
        labelHeightMm: labelHeightMm ?? this.labelHeightMm,
        pitchMm: pitchMm ?? this.pitchMm,
        dpi: dpi ?? this.dpi,
        offsetXMm: offsetXMm ?? this.offsetXMm,
        offsetYMm: offsetYMm ?? this.offsetYMm,
        showStoreName: showStoreName ?? this.showStoreName,
        showPrice: showPrice ?? this.showPrice,
        showBarcodeText: showBarcodeText ?? this.showBarcodeText,
        drawCalibrationFrame: drawCalibrationFrame ?? this.drawCalibrationFrame,
        fontScale: fontScale ?? this.fontScale,
        applyDriverPaperSize: applyDriverPaperSize ?? this.applyDriverPaperSize,
      );
}

/// إعدادات ملصق الشحن لطلبات المتجر الإلكتروني.
/// إعدادات ملصق الشحن.
///
/// يتشارك مع الوصل أصناف المحتوى نفسها ([ReceiptLine]، [ReceiptLogo]،
/// [ReceiptQr]) عمداً: صاحب المحل يضبطهما بالطريقة ذاتها، والقارئ لا
/// يتعلّم نموذجين لشيء واحد.
class OrderLabelSettings {
  final String printerName;
  final double widthMm;
  final double heightMm;
  final double marginMm;
  final double fontScale;

  /// اسم المحل في رأس الملصق ومحاذاته.
  final bool showStoreName;
  final ReceiptAlign storeNameAlign;

  /// الاسم المطبوع. فارغ ⇒ `AppConstants.storeDisplayName`.
  final String storeName;

  /// أسطر حرّة (هاتف، «الدفع عند الاستلام»، شروط الإرجاع...).
  final List<ReceiptLine> lines;

  final ReceiptLogo logo;
  final ReceiptQr qr;

  const OrderLabelSettings({
    this.printerName = '',
    this.widthMm = 100,
    this.heightMm = 150,
    this.marginMm = 4,
    this.fontScale = 1.0,
    this.showStoreName = true,
    this.storeNameAlign = ReceiptAlign.center,
    this.storeName = '',
    this.lines = const [],
    this.logo = const ReceiptLogo(enabled: false, widthMm: 18),
    this.qr = const ReceiptQr(sizeMm: 16),
  });

  List<ReceiptLine> get headerLines => lines.where((l) => !l.footer).toList();
  List<ReceiptLine> get footerLines => lines.where((l) => l.footer).toList();

  factory OrderLabelSettings.fromMap(Map<String, dynamic> m) =>
      OrderLabelSettings(
        printerName: (m['printerName'] ?? '') as String,
        widthMm: m['widthMm'] == null ? 100 : toDouble(m['widthMm']),
        heightMm: m['heightMm'] == null ? 150 : toDouble(m['heightMm']),
        marginMm: m['marginMm'] == null ? 4 : toDouble(m['marginMm']),
        fontScale: m['fontScale'] == null ? 1.0 : toDouble(m['fontScale']),
        showStoreName: (m['showStoreName'] ?? true) as bool,
        storeNameAlign: ReceiptAlignLabel.parse(m['storeNameAlign'] as String?),
        storeName: (m['storeName'] ?? '') as String,
        lines: ((m['lines'] ?? const []) as List)
            .map((e) => ReceiptLine.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        logo: m['logo'] == null
            ? const ReceiptLogo(enabled: false, widthMm: 18)
            : ReceiptLogo.fromMap(Map<String, dynamic>.from(m['logo'] as Map)),
        qr: m['qr'] == null
            ? const ReceiptQr(sizeMm: 16)
            : ReceiptQr.fromMap(Map<String, dynamic>.from(m['qr'] as Map)),
      );

  Map<String, dynamic> toMap() => {
        'printerName': printerName,
        'widthMm': widthMm,
        'heightMm': heightMm,
        'marginMm': marginMm,
        'fontScale': fontScale,
        'showStoreName': showStoreName,
        'storeNameAlign': storeNameAlign.code,
        'storeName': storeName,
        'lines': lines.map((l) => l.toMap()).toList(),
        'logo': logo.toMap(),
        'qr': qr.toMap(),
      };

  OrderLabelSettings copyWith({
    String? printerName,
    double? widthMm,
    double? heightMm,
    double? marginMm,
    double? fontScale,
    bool? showStoreName,
    ReceiptAlign? storeNameAlign,
    String? storeName,
    List<ReceiptLine>? lines,
    ReceiptLogo? logo,
    ReceiptQr? qr,
  }) =>
      OrderLabelSettings(
        printerName: printerName ?? this.printerName,
        widthMm: widthMm ?? this.widthMm,
        heightMm: heightMm ?? this.heightMm,
        marginMm: marginMm ?? this.marginMm,
        fontScale: fontScale ?? this.fontScale,
        showStoreName: showStoreName ?? this.showStoreName,
        storeNameAlign: storeNameAlign ?? this.storeNameAlign,
        storeName: storeName ?? this.storeName,
        lines: lines ?? this.lines,
        logo: logo ?? this.logo,
        qr: qr ?? this.qr,
      );
}

/// كل إعدادات الطباعة لهذا الجهاز.
///
/// ⚠️ محلية عمداً (SharedPreferences لا Firestore): لكل حاسوب طابعته
/// ومعايرته. لو خزّنّاها في Firestore لأفسد كل جهاز معايرة الآخر.
class PrintSettings {
  final ReceiptSettings receipt;
  final TicketSettings ticket;
  final OrderLabelSettings orderLabel;

  const PrintSettings({
    this.receipt = const ReceiptSettings(),
    this.ticket = const TicketSettings(),
    this.orderLabel = const OrderLabelSettings(),
  });

  factory PrintSettings.fromMap(Map<String, dynamic> m) => PrintSettings(
        receipt: ReceiptSettings.fromMap(
            Map<String, dynamic>.from((m['receipt'] ?? const {}) as Map)),
        ticket: TicketSettings.fromMap(
            Map<String, dynamic>.from((m['ticket'] ?? const {}) as Map)),
        orderLabel: OrderLabelSettings.fromMap(
            Map<String, dynamic>.from((m['orderLabel'] ?? const {}) as Map)),
      );

  Map<String, dynamic> toMap() => {
        'receipt': receipt.toMap(),
        'ticket': ticket.toMap(),
        'orderLabel': orderLabel.toMap(),
      };

  PrintSettings copyWith({
    ReceiptSettings? receipt,
    TicketSettings? ticket,
    OrderLabelSettings? orderLabel,
  }) =>
      PrintSettings(
        receipt: receipt ?? this.receipt,
        ticket: ticket ?? this.ticket,
        orderLabel: orderLabel ?? this.orderLabel,
      );
}
