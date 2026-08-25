import 'print_settings.dart';
import 'receipt_content.dart';

/// محتوى ورقة مطبوعة — القاسم المشترك بين وصل البيع وملصق الشحن.
///
/// لماذا صنف ثالث بدل تعميم أحدهما؟ لأن للورقتين إعدادات **لا** تتشارك:
/// الوصل له عرض بكرة وتغذية بعد القصّ، والملصق له طول وعرض ثابتان. أمّا
/// ما يكتبه صاحب المحل — الاسم والأسطر والشعار والرموز — فواحد، ومحرّر
/// واحد يكفيه.
///
/// بلا هذا الصنف كان المحرّر سيُنسخ مرّتين، فيُصلَح عطب في إحداهما ويبقى
/// في الأخرى.
class PrintContent {
  const PrintContent({
    required this.showStoreName,
    required this.storeNameAlign,
    required this.storeName,
    required this.lines,
    required this.logo,
    required this.qr,
  });

  final bool showStoreName;
  final ReceiptAlign storeNameAlign;
  final String storeName;
  final List<ReceiptLine> lines;
  final ReceiptLogo logo;
  final ReceiptQr qr;

  PrintContent copyWith({
    bool? showStoreName,
    ReceiptAlign? storeNameAlign,
    String? storeName,
    List<ReceiptLine>? lines,
    ReceiptLogo? logo,
    ReceiptQr? qr,
  }) =>
      PrintContent(
        showStoreName: showStoreName ?? this.showStoreName,
        storeNameAlign: storeNameAlign ?? this.storeNameAlign,
        storeName: storeName ?? this.storeName,
        lines: lines ?? this.lines,
        logo: logo ?? this.logo,
        qr: qr ?? this.qr,
      );
}

extension ReceiptContentView on ReceiptSettings {
  PrintContent get content => PrintContent(
        showStoreName: showStoreName,
        storeNameAlign: storeNameAlign,
        storeName: storeName,
        lines: lines,
        logo: logo,
        qr: qr,
      );

  ReceiptSettings withContent(PrintContent c) => copyWith(
        showStoreName: c.showStoreName,
        storeNameAlign: c.storeNameAlign,
        storeName: c.storeName,
        lines: c.lines,
        logo: c.logo,
        qr: c.qr,
      );
}

extension OrderLabelContentView on OrderLabelSettings {
  PrintContent get content => PrintContent(
        showStoreName: showStoreName,
        storeNameAlign: storeNameAlign,
        storeName: storeName,
        lines: lines,
        logo: logo,
        qr: qr,
      );

  OrderLabelSettings withContent(PrintContent c) => copyWith(
        showStoreName: c.showStoreName,
        storeNameAlign: c.storeNameAlign,
        storeName: c.storeName,
        lines: c.lines,
        logo: c.logo,
        qr: c.qr,
      );
}
