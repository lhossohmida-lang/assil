import '../../../shared/utils/formatters.dart';
import '../../customers/domain/models/customer.dart';
import '../../suppliers/domain/models/supplier.dart';
import 'import_parser.dart';

/// ما الذي نستورده.
enum ImportKind { products, suppliers, credits }

extension ImportKindLabel on ImportKind {
  String get label => switch (this) {
        ImportKind.products => 'منتجات',
        ImportKind.suppliers => 'موردون',
        ImportKind.credits => 'كريديات',
      };

  String get description => switch (this) {
        ImportKind.products =>
          'الأعمدة الإلزامية: الاسم، سعر الشراء، سعر البيع، الكمية.',
        ImportKind.suppliers => 'العمود الإلزامي: الاسم.',
        ImportKind.credits => 'الأعمدة الإلزامية: الاسم، الدين.',
      };
}

// ═══════════════════════════ الموردون ═══════════════════════════

const Map<String, List<String>> supplierAliases = {
  'name': ['الاسم', 'اسم', 'المورد', 'المورّد', 'name', 'supplier'],
  'phone': ['الهاتف', 'هاتف', 'الرقم', 'phone', 'tel', 'mobile'],
  'address': ['العنوان', 'عنوان', 'address'],
  'note': ['ملاحظة', 'الملاحظة', 'note', 'notes'],
  'totalPurchases': [
    'مجموع المشتريات', 'المشتريات', 'total_purchases', 'purchases',
  ],
  'totalPaid': ['المدفوع', 'المسدد', 'المسدَّد', 'total_paid', 'paid'],
};

// ═══════════════════════════ الكريديات ═══════════════════════════

const Map<String, List<String>> creditAliases = {
  'customerName': [
    'الاسم', 'اسم', 'الزبونة', 'الزبون', 'name', 'customer', 'client',
  ],
  'phone': ['الهاتف', 'هاتف', 'الرقم', 'phone', 'tel', 'mobile'],
  'totalDebt': ['الدين', 'الدَّين', 'المبلغ', 'debt', 'amount', 'total'],
  'totalPaid': ['المدفوع', 'المسدد', 'المسدَّد', 'paid', 'total_paid'],
};

/// صفّ مورّد بعد التحقّق.
class SupplierRow {
  const SupplierRow({
    required this.lineNumber,
    required this.status,
    this.supplier,
    this.existingId,
    this.error,
  });

  final int lineNumber;
  final RowStatus status;
  final Supplier? supplier;
  final String? existingId;
  final String? error;

  bool get isValid => status == RowStatus.create || status == RowStatus.update;
}

/// صفّ كريدي بعد التحقّق.
class CreditRow {
  const CreditRow({
    required this.lineNumber,
    required this.status,
    this.account,
    this.existingId,
    this.error,
  });

  final int lineNumber;
  final RowStatus status;
  final CreditAccount? account;
  final String? existingId;
  final String? error;

  bool get isValid => status == RowStatus.create || status == RowStatus.update;
}

class SimplePreview<T> {
  const SimplePreview({
    required this.rows,
    required this.missingColumns,
    required this.createCount,
    required this.updateCount,
    required this.errorCount,
  });

  final List<T> rows;
  final List<String> missingColumns;
  final int createCount;
  final int updateCount;
  final int errorCount;

  bool get isUsable => missingColumns.isEmpty;
}

Map<String, int> _map(List<String> header, Map<String, List<String>> aliases) {
  final mapping = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final cell = normalizeForSearch(header[i]);
    if (cell.isEmpty) continue;
    for (final entry in aliases.entries) {
      if (mapping.containsKey(entry.key)) continue;
      if (entry.value.any((a) => normalizeForSearch(a) == cell)) {
        mapping[entry.key] = i;
      }
    }
  }
  return mapping;
}

/// تحليل ملف الموردين.
SimplePreview<SupplierRow> parseSuppliers(
  List<List<String>> rows, {
  required Map<String, Supplier> existingByName,
}) {
  if (rows.isEmpty) {
    return const SimplePreview(
      rows: [],
      missingColumns: ['الاسم'],
      createCount: 0,
      updateCount: 0,
      errorCount: 0,
    );
  }

  final mapping = _map(rows.first, supplierAliases);
  if (!mapping.containsKey('name')) {
    return const SimplePreview(
      rows: [],
      missingColumns: ['الاسم'],
      createCount: 0,
      updateCount: 0,
      errorCount: 0,
    );
  }

  final parsed = <SupplierRow>[];
  var created = 0, updated = 0, errors = 0;

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final line = i + 1;

    String cell(String key) {
      final index = mapping[key];
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    final name = cell('name');
    if (name.isEmpty) {
      parsed.add(SupplierRow(
        lineNumber: line,
        status: RowStatus.error,
        error: 'اسم المورّد فارغ في الصف $line',
      ));
      errors++;
      continue;
    }

    final existing = existingByName[normalizeForSearch(name)];
    parsed.add(SupplierRow(
      lineNumber: line,
      status: existing == null ? RowStatus.create : RowStatus.update,
      existingId: existing?.id,
      supplier: Supplier(
        id: existing?.id ?? '',
        name: name,
        phone: cell('phone'),
        address: cell('address'),
        note: cell('note'),
        totalPurchases: toDouble(cell('totalPurchases')),
        totalPaid: toDouble(cell('totalPaid')),
      ),
    ));
    existing == null ? created++ : updated++;
  }

  return SimplePreview(
    rows: parsed,
    missingColumns: const [],
    createCount: created,
    updateCount: updated,
    errorCount: errors,
  );
}

/// تحليل ملف الكريديات.
SimplePreview<CreditRow> parseCredits(
  List<List<String>> rows, {
  required Map<String, CreditAccount> existingByName,
}) {
  if (rows.isEmpty) {
    return const SimplePreview(
      rows: [],
      missingColumns: ['الاسم', 'الدين'],
      createCount: 0,
      updateCount: 0,
      errorCount: 0,
    );
  }

  final mapping = _map(rows.first, creditAliases);
  final missing = <String>[
    if (!mapping.containsKey('customerName')) 'الاسم',
    if (!mapping.containsKey('totalDebt')) 'الدين',
  ];
  if (missing.isNotEmpty) {
    return SimplePreview(
      rows: const [],
      missingColumns: missing,
      createCount: 0,
      updateCount: 0,
      errorCount: 0,
    );
  }

  final parsed = <CreditRow>[];
  var created = 0, updated = 0, errors = 0;

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    if (row.every((c) => c.trim().isEmpty)) continue;
    final line = i + 1;

    String cell(String key) {
      final index = mapping[key];
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    final name = cell('customerName');
    if (name.isEmpty) {
      parsed.add(CreditRow(
        lineNumber: line,
        status: RowStatus.error,
        error: 'اسم الزبونة فارغ في الصف $line',
      ));
      errors++;
      continue;
    }

    final debtRaw = cell('totalDebt');
    final debt = double.tryParse(
      debtRaw.replaceAll('٫', '.').replaceAll(',', '.').replaceAll(' ', ''),
    );
    if (debt == null) {
      parsed.add(CreditRow(
        lineNumber: line,
        status: RowStatus.error,
        error: 'الدين ليس رقماً في الصف $line («$debtRaw»)',
      ));
      errors++;
      continue;
    }
    if (debt < 0) {
      parsed.add(CreditRow(
        lineNumber: line,
        status: RowStatus.error,
        error: 'دين سالب في الصف $line',
      ));
      errors++;
      continue;
    }

    final existing = existingByName[normalizeForSearch(name)];
    parsed.add(CreditRow(
      lineNumber: line,
      status: existing == null ? RowStatus.create : RowStatus.update,
      existingId: existing?.id,
      account: CreditAccount(
        id: existing?.id ?? '',
        customerName: name,
        phone: cell('phone'),
        totalDebt: debt,
        totalPaid: toDouble(cell('totalPaid')),
      ),
    ));
    existing == null ? created++ : updated++;
  }

  return SimplePreview(
    rows: parsed,
    missingColumns: const [],
    createCount: created,
    updateCount: updated,
    errorCount: errors,
  );
}

/// صفوف الملف النموذجي لكل نوع.
List<List<String>> templateFor(ImportKind kind) => switch (kind) {
      ImportKind.products => templateRows(),
      ImportKind.suppliers => [
          ['الاسم', 'الهاتف', 'العنوان', 'ملاحظة', 'مجموع المشتريات', 'المدفوع'],
          ['مورّد الجملة', '0555123456', 'الجزائر الوسطى', 'قمصان', '0', '0'],
          ['مصنع الأقمشة', '0661998877', 'وهران', '', '0', '0'],
        ],
      ImportKind.credits => [
          ['الاسم', 'الهاتف', 'الدين', 'المدفوع'],
          ['أم أحمد', '0555112233', '4500', '1000'],
          ['خالتي فطيمة', '0770445566', '2000', '0'],
        ],
    };
