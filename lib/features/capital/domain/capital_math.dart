import '../../inventory/domain/models/product.dart';

/// نسبة الزكاة على عروض التجارة: ربع العشر.
const double zakatRate = 0.025;

/// ملخّص رأس المال والزكاة.
///
/// ═══ الفرق بين رأس المال ووعاء الزكاة ═══
/// **رأس المال** = ما دُفع فعلاً في البضاعة (بسعر الشراء).
///
/// **وعاء الزكاة** = البضاعة بسعر البيع + كريديات الزبائن (دين لنا)
/// − ما ندين به للموردين.
///
/// ⚠️ **نقد الصندوق خارج الوعاء** بطلب صريح من صاحب المحل. كان داخلاً
/// سابقاً؛ إن أردتَ إعادته فالتغيير سطر واحد في [CapitalSummary.zakatBase]
/// ويُقابله اختبار مثبَّت في `test/capital_math_test.dart`.
class CapitalSummary {
  const CapitalSummary({
    required this.stockCapital,
    required this.stockSellValue,
    required this.typeCount,
    required this.pieceCount,
    required this.cash,
    required this.credits,
    required this.supplierDebt,
  });

  /// رأس المال: المخزون بسعر الشراء.
  final double stockCapital;

  /// قيمة المخزون بسعر البيع.
  final double stockSellValue;

  final int typeCount;
  final int pieceCount;

  /// نقد الصندوق.
  final double cash;

  /// ديون الزبائن المتبقّية (كريديات).
  final double credits;

  /// الفائدة المنتظرة لو بِيع المخزون كلّه بسعره.
  double get expectedProfit => stockSellValue - stockCapital;

  /// ما ندين به للموردين — يُخصم من الوعاء لأنه مال في يدنا وليس لنا.
  final double supplierDebt;

  /// وعاء الزكاة = مخزون بسعر البيع + كريديات لنا − دَين علينا للموردين.
  ///
  /// لا ينزل تحت الصفر: محلّ مديون أكثر مما يملك لا زكاة عليه، ووعاء
  /// سالب كان سيُنتج «زكاة سالبة» وهي بلا معنى.
  double get zakatBase {
    final base = stockSellValue + credits - supplierDebt;
    return base < 0 ? 0 : base;
  }

  double get zakat => zakatBase * zakatRate;

  static const CapitalSummary empty = CapitalSummary(
    stockCapital: 0,
    stockSellValue: 0,
    typeCount: 0,
    pieceCount: 0,
    cash: 0,
    credits: 0,
    supplierDebt: 0,
  );
}

CapitalSummary computeCapital({
  required List<Product> stock,
  required double cash,
  required double credits,
  double supplierDebt = 0,
}) {
  var capital = 0.0;
  var sell = 0.0;
  var pieces = 0;
  for (final p in stock) {
    capital += p.purchasePrice * p.quantity;
    sell += p.sellPrice * p.quantity;
    pieces += p.quantity;
  }

  return CapitalSummary(
    stockCapital: capital,
    stockSellValue: sell,
    typeCount: stock.length,
    pieceCount: pieces,
    cash: cash,
    credits: credits,
    supplierDebt: supplierDebt,
  );
}
