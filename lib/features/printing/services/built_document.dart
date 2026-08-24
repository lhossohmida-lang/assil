import 'dart:typed_data';

import 'package:pdf/pdf.dart';

/// نتيجة بناء مستند للطباعة: البايتات + **المقاس النهائي الفعلي**.
///
/// المقاس مهمّ للوصل تحديداً: نبنيه بارتفاع لانهائي ثم نقرأ الارتفاع الذي
/// حسبته المكتبة، ونرسله للطابعة كمقاس ورق — فلا يخرج ورق زائد.
class BuiltDocument {
  const BuiltDocument(this.bytes, this.format);
  final Uint8List bytes;
  final PdfPageFormat format;

  double get widthMm => format.width / PdfPageFormat.mm;
  double get heightMm => format.height / PdfPageFormat.mm;
}
