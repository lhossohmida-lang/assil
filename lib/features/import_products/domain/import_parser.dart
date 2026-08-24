import '../../../shared/utils/formatters.dart';
import '../../inventory/domain/models/product.dart';

/// سياسة التعامل مع منتج موجود بنفس الباركود.
enum DuplicatePolicy {
  /// تخطّي الموجود (الافتراضي) — استيراد قائمة جديدة بلا لمس القديم.
  skip,

  /// **جمع الكميات** — استلام بضاعة: الكمية تُضاف والأسعار تُحدَّث.
  addQuantity,

  /// استبدال كل البيانات بما في الملف.
  replace,
}

extension DuplicatePolicyLabel on DuplicatePolicy {
  String get label => switch (this) {
        DuplicatePolicy.skip => 'تخطّي الموجود',
        DuplicatePolicy.addQuantity => 'جمع الكميات',
        DuplicatePolicy.replace => 'استبدال البيانات',
      };

  String get description => switch (this) {
        DuplicatePolicy.skip =>
          'المنتجات الموجودة تُترك كما هي — تُضاف الجديدة فقط.',
        DuplicatePolicy.addQuantity =>
          'استلام بضاعة: الكمية تُضاف إلى الموجودة، والأسعار تُحدَّث.',
        DuplicatePolicy.replace =>
          'كل بيانات المنتج الموجود تُستبدل بما في الملف.',
      };
}

enum RowStatus { create, update, error, empty }

/// صفّ من ملف الاستيراد بعد التحقّق.
class ImportRow {
  const ImportRow({
    required this.lineNumber,
    required this.status,
    this.product,
    this.existingId,
    this.error,
  });

  /// رقم السطر في الملف كما يراه المستخدم (يشمل صفّ الرؤوس).
  final int lineNumber;

  final RowStatus status;
  final Product? product;

  /// معرّف المنتج الموجود بنفس الباركود.
  final String? existingId;

  final String? error;

  bool get isValid => status == RowStatus.create || status == RowStatus.update;
}

/// نتيجة تحليل الملف كاملاً.
class ImportPreview {
  const ImportPreview({
    required this.rows,
    required this.missingColumns,
    required this.recognizedColumns,
  });

  final List<ImportRow> rows;

  /// أعمدة إلزامية لم توجد في صفّ الرؤوس.
  final List<String> missingColumns;

  /// الأعمدة التي فُهمت فعلاً (لعرضها للمستخدم).
  final List<String> recognizedColumns;

  bool get isUsable => missingColumns.isEmpty;

  int get createCount =>
      rows.where((r) => r.status == RowStatus.create).length;
  int get updateCount =>
      rows.where((r) => r.status == RowStatus.update).length;
  int get errorCount => rows.where((r) => r.status == RowStatus.error).length;
  List<ImportRow> get validRows => rows.where((r) => r.isValid).toList();
}

/// أسماء الأعمدة المقبولة — عربية أو إنجليزية، غير حسّاسة للحالة.
const Map<String, List<String>> columnAliases = {
  'name': ['الاسم', 'اسم', 'اسم المنتج', 'المنتج', 'name', 'product', 'product_name'],
  'barcode': ['الباركود', 'باركود', 'الرمز', 'barcode', 'code', 'sku'],
  'purchasePrice': [
    'سعر الشراء', 'الشراء', 'ثمن الشراء', 'purchase_price', 'purchase', 'cost',
  ],
  'sellPrice': [
    'سعر البيع', 'البيع', 'ثمن البيع', 'السعر', 'sell_price', 'price', 'sell',
  ],
  'quantity': ['الكمية', 'كمية', 'العدد', 'quantity', 'qty', 'stock'],
  'minQuantity': [
    'حد التنبيه', 'الحد الادنى', 'الحد الأدنى', 'min_quantity', 'min', 'minimum',
  ],
  'category': ['الفئة', 'فئة', 'التصنيف', 'category', 'type'],
  'supplier': ['المورد', 'المورّد', 'مورد', 'supplier', 'vendor'],
  'description': ['الوصف', 'وصف', 'description', 'notes'],
  'sizes': ['المقاسات', 'مقاسات', 'المقاس', 'sizes', 'size'],
  'colors': ['الألوان', 'الالوان', 'اللون', 'colors', 'color'],
};

/// الأعمدة التي لا يعمل الاستيراد بدونها.
const List<String> requiredColumns = [
  'name',
  'purchasePrice',
  'sellPrice',
  'quantity',
];

const Map<String, String> columnArabicNames = {
  'name': 'الاسم',
  'barcode': 'الباركود',
  'purchasePrice': 'سعر الشراء',
  'sellPrice': 'سعر البيع',
  'quantity': 'الكمية',
  'minQuantity': 'حد التنبيه',
  'category': 'الفئة',
  'supplier': 'المورّد',
  'description': 'الوصف',
  'sizes': 'المقاسات',
  'colors': 'الألوان',
};

/// يطابق صفّ الرؤوس بأسماء الحقول.
Map<String, int> mapHeaders(List<String> header) {
  final mapping = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final cell = normalizeForSearch(header[i]);
    if (cell.isEmpty) continue;
    for (final entry in columnAliases.entries) {
      if (mapping.containsKey(entry.key)) continue;
      final matched = entry.value
          .any((alias) => normalizeForSearch(alias) == cell);
      if (matched) mapping[entry.key] = i;
    }
  }
  return mapping;
}

/// يحلّل صفوف الملف إلى معاينة قابلة للعرض قبل أي كتابة.
///
/// `existingByBarcode` مخزون المحل الحالي — به نعرف الجديد من المكرَّر.
ImportPreview parseRows(
  List<List<String>> rows, {
  required Map<String, Product> existingByBarcode,
}) {
  if (rows.isEmpty) {
    return const ImportPreview(
      rows: [],
      missingColumns: requiredColumns,
      recognizedColumns: [],
    );
  }

  final mapping = mapHeaders(rows.first);
  final missing = requiredColumns.where((c) => !mapping.containsKey(c)).toList();
  if (missing.isNotEmpty) {
    return ImportPreview(
      rows: const [],
      missingColumns: missing.map((c) => columnArabicNames[c] ?? c).toList(),
      recognizedColumns:
          mapping.keys.map((c) => columnArabicNames[c] ?? c).toList(),
    );
  }

  final parsed = <ImportRow>[];

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final lineNumber = i + 1;

    String cell(String key) {
      final index = mapping[key];
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    // الصفوف الفارغة تُتجاهل بصمت — ملفات إكسل مليئة بها في الذيل.
    if (row.every((c) => c.trim().isEmpty)) continue;

    final name = cell('name');
    if (name.isEmpty) {
      parsed.add(ImportRow(
        lineNumber: lineNumber,
        status: RowStatus.error,
        error: 'الاسم فارغ في الصف $lineNumber',
      ));
      continue;
    }

    final purchaseRaw = cell('purchasePrice');
    final sellRaw = cell('sellPrice');
    final quantityRaw = cell('quantity');

    final purchase = _number(purchaseRaw);
    if (purchase == null) {
      parsed.add(ImportRow(
        lineNumber: lineNumber,
        status: RowStatus.error,
        error: 'سعر الشراء ليس رقماً في الصف $lineNumber («$purchaseRaw»)',
      ));
      continue;
    }
    final sell = _number(sellRaw);
    if (sell == null) {
      parsed.add(ImportRow(
        lineNumber: lineNumber,
        status: RowStatus.error,
        error: 'سعر البيع ليس رقماً في الصف $lineNumber («$sellRaw»)',
      ));
      continue;
    }
    final quantity = _number(quantityRaw);
    if (quantity == null) {
      parsed.add(ImportRow(
        lineNumber: lineNumber,
        status: RowStatus.error,
        error: 'الكمية ليست رقماً في الصف $lineNumber («$quantityRaw»)',
      ));
      continue;
    }

    if (purchase < 0 || sell < 0 || quantity < 0) {
      parsed.add(ImportRow(
        lineNumber: lineNumber,
        status: RowStatus.error,
        error: 'قيمة سالبة في الصف $lineNumber',
      ));
      continue;
    }

    final barcode = cleanBarcode(cell('barcode'));
    final existing = barcode.isEmpty ? null : existingByBarcode[barcode];

    final minRaw = cell('minQuantity');
    final product = Product(
      id: existing?.id ?? '',
      name: name,
      barcode: barcode,
      purchasePrice: purchase,
      sellPrice: sell,
      quantity: quantity.round(),
      minQuantity: minRaw.isEmpty ? 1 : (_number(minRaw)?.round() ?? 1),
      category: cell('category'),
      supplier: cell('supplier'),
      description: cell('description'),
      sizes: _list(cell('sizes')),
      colors: _list(cell('colors')),
    );

    parsed.add(ImportRow(
      lineNumber: lineNumber,
      status: existing == null ? RowStatus.create : RowStatus.update,
      product: product,
      existingId: existing?.id,
    ));
  }

  return ImportPreview(
    rows: parsed,
    missingColumns: const [],
    recognizedColumns:
        mapping.keys.map((c) => columnArabicNames[c] ?? c).toList(),
  );
}

/// يدمج صفّ الاستيراد مع المنتج الموجود حسب السياسة المختارة.
Product applyPolicy({
  required Product imported,
  required Product existing,
  required DuplicatePolicy policy,
}) {
  switch (policy) {
    case DuplicatePolicy.skip:
      return existing;

    case DuplicatePolicy.addQuantity:
      // استلام بضاعة: الكمية تتراكم، والأسعار تأخذ آخر قيمة من الملف.
      return existing.copyWith(
        quantity: existing.quantity + imported.quantity,
        purchasePrice: imported.purchasePrice,
        sellPrice: imported.sellPrice,
        name: imported.name.isEmpty ? existing.name : imported.name,
        category:
            imported.category.isEmpty ? existing.category : imported.category,
        supplier:
            imported.supplier.isEmpty ? existing.supplier : imported.supplier,
      );

    case DuplicatePolicy.replace:
      // البيانات كلها من الملف، مع الاحتفاظ بما لا يوجد فيه أصلاً
      // (الصور والحجز وحالة النشر) حتى لا يُفسد الاستيراد المتجر.
      return imported.copyWith(
        id: existing.id,
        images: existing.images,
        imagePublicIds: existing.imagePublicIds,
        imageUrl: existing.imageUrl,
        reserved: existing.reserved,
        publishedToStore: existing.publishedToStore,
        createdAt: existing.createdAt,
      );
  }
}

double? _number(String raw) {
  if (raw.trim().isEmpty) return null;
  // أرقام عربية-هندية، فاصلة عشرية عربية، فواصل آلاف، مسافات.
  var cleaned = raw.trim();
  const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  for (var d = 0; d < 10; d++) {
    cleaned = cleaned.replaceAll(arabicDigits[d], '$d');
  }
  cleaned = cleaned
      .replaceAll('٫', '.')
      .replaceAll('٬', '')
      .replaceAll(' ', '')
      .replaceAll(' ', '');

  // فاصلة واحدة تُعامل كفاصلة عشرية (الشائع محلياً)، وأكثر = فواصل آلاف.
  if (','.allMatches(cleaned).length == 1 && !cleaned.contains('.')) {
    cleaned = cleaned.replaceAll(',', '.');
  } else {
    cleaned = cleaned.replaceAll(',', '');
  }

  return double.tryParse(cleaned);
}

List<String> _list(String raw) => raw
    .split(RegExp(r'[,;،؛]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// صفوف الملف النموذجي.
List<List<String>> templateRows() => [
      [
        'الاسم',
        'الباركود',
        'سعر الشراء',
        'سعر البيع',
        'الكمية',
        'حد التنبيه',
        'الفئة',
        'المورّد',
        'الوصف',
        'المقاسات',
        'الألوان',
      ],
      [
        'قميص قطن أبيض',
        '12345678',
        '1100',
        '1800',
        '10',
        '2',
        'قمصان',
        'مورّد الجملة',
        'قطن 100٪',
        '40,42,44',
        'أبيض,أسود',
      ],
      [
        'بنطال جينز',
        '', // اتركه فارغاً ليُولَّد باركود تلقائياً
        '2200',
        '3500',
        '5',
        '1',
        'بناطيل',
        '',
        '',
        '38,40',
        'أزرق',
      ],
    ];
