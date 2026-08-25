import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/models/receipt_content.dart';

/// هوية المحل المشتركة بين الأجهزة كما تُطبع على الوصل وملصق الشحن:
/// روابط التواصل وأسماء الحسابات وشعار المحل وعنوان المتجر الإلكتروني.
///
/// منفصلة عن إعدادات الطباعة عمداً: تلك محلّية لكل جهاز (طابعته
/// ومعايرته)، وهذه مشتركة تأتي من Firestore.
class ReceiptBranding {
  const ReceiptBranding({
    this.facebook = '',
    this.facebookName = '',
    this.instagram = '',
    this.instagramName = '',
    this.website = '',
    this.logoBase64 = '',
  });

  final String facebook;

  /// اسم الصفحة كما يكتبه صاحب المحل («الأصيل» أو «@alasil.dz»).
  /// فارغ ⇒ تُكتب كلمة «فيسبوك».
  final String facebookName;

  final String instagram;
  final String instagramName;

  /// عنوان المتجر الإلكتروني.
  final String website;

  /// شعار المحل المخصَّص (PNG مصغَّر، base64). فارغ ⇒ الشعار المضمَّن.
  final String logoBase64;

  static const ReceiptBranding none = ReceiptBranding();
}

/// أيقونات التواصل مرسومة **مسارات SVG** لا خطّ أيقونات.
///
/// خطّ MaterialIcons يُقلَّم في بناء الإصدار (tree-shaking) فيُحذف منه ما
/// لا تستعمله الواجهة، ولا ضمان أن يبقى فيه ما تحتاجه الطابعة. المسار
/// المرسوم هنا يُطبع كما هو على أي طابعة وفي أي بناء.
class _Marks {
  _Marks._();

  static const String facebook = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path fill="#000000" d="M22 12.06C22 6.5 17.52 2 12 2S2 6.5 2 12.06c0 5.02 3.66 9.18 8.44 9.94v-7.03H7.9v-2.91h2.54V9.85c0-2.52 1.5-3.91 3.77-3.91 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.63.78-1.63 1.57v1.89h2.78l-.45 2.91h-2.33V22c4.78-.76 8.44-4.92 8.44-9.94z"/>
</svg>''';

  static const String instagram = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path fill="#000000" d="M12 2.16c3.2 0 3.58.01 4.85.07 1.17.05 1.8.25 2.23.41.56.22.96.48 1.38.9.42.42.68.82.9 1.38.16.42.36 1.06.41 2.23.06 1.27.07 1.65.07 4.85s-.01 3.58-.07 4.85c-.05 1.17-.25 1.8-.41 2.23-.22.56-.48.96-.9 1.38-.42.42-.82.68-1.38.9-.42.16-1.06.36-2.23.41-1.27.06-1.65.07-4.85.07s-3.58-.01-4.85-.07c-1.17-.05-1.8-.25-2.23-.41a3.8 3.8 0 01-1.38-.9 3.8 3.8 0 01-.9-1.38c-.16-.42-.36-1.06-.41-2.23C2.17 15.58 2.16 15.2 2.16 12s.01-3.58.07-4.85c.05-1.17.25-1.8.41-2.23.22-.56.48-.96.9-1.38.42-.42.82-.68 1.38-.9.42-.16 1.06-.36 2.23-.41C8.42 2.17 8.8 2.16 12 2.16zm0 3.68a6.16 6.16 0 100 12.32 6.16 6.16 0 000-12.32zm0 10.16a4 4 0 110-8 4 4 0 010 8zm7.85-10.4a1.44 1.44 0 11-2.88 0 1.44 1.44 0 012.88 0z"/>
</svg>''';

  /// كرة أرضية — للمتجر الإلكتروني.
  static const String website = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<path fill="#000000" d="M12 2a10 10 0 100 20 10 10 0 000-20zm6.9 6h-2.95a15.7 15.7 0 00-1.38-3.56A8.03 8.03 0 0118.9 8zM12 4.04c.83 1.2 1.48 2.53 1.91 3.96h-3.82c.43-1.43 1.08-2.76 1.91-3.96zM4.26 14a7.9 7.9 0 010-4h3.38a16.6 16.6 0 000 4H4.26zm.84 2h2.95c.3 1.26.76 2.46 1.38 3.56A8.03 8.03 0 015.1 16zm2.95-8H5.1a8.03 8.03 0 014.33-3.56A15.7 15.7 0 008.05 8zM12 19.96c-.83-1.2-1.48-2.53-1.91-3.96h3.82A13.9 13.9 0 0112 19.96zM14.34 14H9.66a14.6 14.6 0 010-4h4.68a14.6 14.6 0 010 4zm.23 5.56c.62-1.1 1.08-2.3 1.38-3.56h2.95a8.03 8.03 0 01-4.33 3.56zM16.36 14a16.6 16.6 0 000-4h3.38a7.9 7.9 0 010 4h-3.38z"/>
</svg>''';
}

/// رمز QR واحد مع أيقونته واسمه تحته.
pw.Widget brandingQr({
  required String svg,
  required String label,
  required String data,
  required double sizeMm,
  required bool withLabel,
  required double fontScale,
}) {
  final size = sizeMm * PdfPageFormat.mm;
  final iconSize = 3.2 * PdfPageFormat.mm * fontScale;

  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.SizedBox(
        width: size,
        height: size,
        child: pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: data,
          drawText: false,
          padding: pw.EdgeInsets.zero,
          margin: pw.EdgeInsets.zero,
        ),
      ),
      if (withLabel)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SvgImage(svg: svg, width: iconSize, height: iconSize),
              pw.SizedBox(width: 1.2 * PdfPageFormat.mm),
              // العرض محدود بعرض الرمز نفسه: اسم طويل يُقصّ بدل أن يدفع
              // الرموز المجاورة خارج الورقة.
              pw.ConstrainedBox(
                constraints: pw.BoxConstraints(maxWidth: size),
                child: pw.Text(
                  label,
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  style: pw.TextStyle(fontSize: 7 * fontScale),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// صفّ رموز QR المشترك بين الوصل وملصق الشحن.
///
/// موحَّد عمداً: صاحب المحل يضبط الرموز مرّة ويتوقّع أن تخرج بالشكل نفسه
/// على الورقتين.
pw.Widget brandingQrRow({
  required ReceiptQr qr,
  required ReceiptBranding branding,
  required double fontScale,
  double topPadding = 4,
}) {
  final codes = <pw.Widget>[
    if (qr.showFacebook && branding.facebook.isNotEmpty)
      brandingQr(
        svg: _Marks.facebook,
        label: branding.facebookName.isNotEmpty
            ? branding.facebookName
            : 'Facebook',
        data: branding.facebook,
        sizeMm: qr.sizeMm,
        withLabel: qr.withLabels,
        fontScale: fontScale,
      ),
    if (qr.showInstagram && branding.instagram.isNotEmpty)
      brandingQr(
        svg: _Marks.instagram,
        label: branding.instagramName.isNotEmpty
            ? branding.instagramName
            : 'Instagram',
        data: branding.instagram,
        sizeMm: qr.sizeMm,
        withLabel: qr.withLabels,
        fontScale: fontScale,
      ),
    if (qr.showWebsite && branding.website.isNotEmpty)
      brandingQr(
        svg: _Marks.website,
        label: prettyDomain(branding.website),
        data: branding.website,
        sizeMm: qr.sizeMm,
        withLabel: qr.withLabels,
        fontScale: fontScale,
      ),
  ];
  if (codes.isEmpty) return pw.SizedBox();

  return pw.Padding(
    padding: pw.EdgeInsets.only(top: topPadding),
    child: pw.Row(
      mainAxisAlignment: codes.length == 1
          ? pw.MainAxisAlignment.center
          : pw.MainAxisAlignment.spaceEvenly,
      children: codes,
    ),
  );
}

/// يختصر العنوان إلى نطاقه: `https://assil.vercel.app/produits/` ⇒
/// `assil.vercel.app`.
///
/// العنوان الكامل لا يتّسع تحت رمز 20مم، والزبون لا يكتبه يدوياً أصلاً —
/// يمسح الرمز. النطاق وحده يكفيه ليعرف أين سيذهب.
String prettyDomain(String url) {
  var out = url.trim();
  for (final prefix in ['https://', 'http://', 'www.']) {
    if (out.toLowerCase().startsWith(prefix)) {
      out = out.substring(prefix.length);
    }
  }
  final slash = out.indexOf('/');
  if (slash > 0) out = out.substring(0, slash);
  return out;
}
