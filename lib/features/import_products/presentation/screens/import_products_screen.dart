import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../customers/domain/models/customer.dart';
import '../../../inventory/domain/models/product.dart';
import '../../../inventory/presentation/providers/inventory_providers.dart';
import '../../../pos/presentation/providers/pos_providers.dart';
import '../../../suppliers/domain/models/supplier.dart';
import '../../../suppliers/presentation/providers/suppliers_providers.dart';
import '../../data/xlsx_codec.dart';
import '../../domain/import_kinds.dart';
import '../../domain/import_parser.dart';
import '../../../../core/i18n/app_strings.dart';

/// نتيجة تنفيذ الاستيراد.
class ImportResult {
  const ImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.errors,
  });

  final int created;
  final int updated;
  final int skipped;
  final int failed;
  final List<String> errors;
}

/// استيراد المنتجات والموردين والكريديات من xlsx أو csv.
class ImportProductsScreen extends ConsumerStatefulWidget {
  const ImportProductsScreen({super.key, this.initialKind = ImportKind.products});

  /// النوع الذي تُفتح عليه الشاشة.
  ///
  /// موجود لأن المستخدم يصل إلى هذه الشاشة من ثلاثة أبواب: المخزون
  /// والموردون والكريديات. أن يصل من «الموردون» ثم يجد النوع مضبوطاً على
  /// «منتجات» هو ما جعل استيراد الموردين يبدو غير موجود أصلاً.
  final ImportKind initialKind;

  @override
  ConsumerState<ImportProductsScreen> createState() =>
      _ImportProductsScreenState();
}

class _ImportProductsScreenState extends ConsumerState<ImportProductsScreen> {
  late ImportKind _kind = widget.initialKind;

  ImportPreview? _products;
  SimplePreview<SupplierRow>? _suppliers;
  SimplePreview<CreditRow>? _credits;

  String _fileName = '';
  DuplicatePolicy _policy = DuplicatePolicy.skip;

  bool _running = false;
  double _progress = 0;
  ImportResult? _result;

  void _clearPreviews() {
    _products = null;
    _suppliers = null;
    _credits = null;
  }

  bool get _hasPreview =>
      _products != null || _suppliers != null || _credits != null;

  bool get _hasUsablePreview => switch (_kind) {
        ImportKind.products => _products?.isUsable ?? false,
        ImportKind.suppliers => _suppliers?.isUsable ?? false,
        ImportKind.credits => _credits?.isUsable ?? false,
      };

  List<String> get _missingColumns => switch (_kind) {
        ImportKind.products => _products?.missingColumns ?? const [],
        ImportKind.suppliers => _suppliers?.missingColumns ?? const [],
        ImportKind.credits => _credits?.missingColumns ?? const [],
      };

  (int create, int update, int error) get _counts => switch (_kind) {
        ImportKind.products => (
            _products?.createCount ?? 0,
            _products?.updateCount ?? 0,
            _products?.errorCount ?? 0,
          ),
        ImportKind.suppliers => (
            _suppliers?.createCount ?? 0,
            _suppliers?.updateCount ?? 0,
            _suppliers?.errorCount ?? 0,
          ),
        ImportKind.credits => (
            _credits?.createCount ?? 0,
            _credits?.updateCount ?? 0,
            _credits?.errorCount ?? 0,
          ),
      };

  // ───────────────────────── اختيار الملف ─────────────────────────

  Future<void> _pickFile() async {
    setState(() {
      _result = null;
      _clearPreviews();
    });

    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true, // أندرويد لا يعطي مساراً دائماً
      );
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر فتح مستعرض الملفات: {0}', [e]));
      return;
    }

    final file = picked?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;

    try {
      final rows = file.extension?.toLowerCase() == 'csv'
          ? CsvCodec.readRows(bytes)
          : XlsxCodec.readRows(bytes);

      switch (_kind) {
        case ImportKind.products:
          final existing = <String, Product>{
            for (final p
                in ref.read(allProductsProvider).value ?? const <Product>[])
              if (p.barcode.isNotEmpty) p.barcode: p,
          };
          _products = parseRows(rows, existingByBarcode: existing);

        case ImportKind.suppliers:
          final existing = <String, Supplier>{
            for (final s
                in ref.read(suppliersListProvider).value ?? const <Supplier>[])
              normalizeForSearch(s.name): s,
          };
          _suppliers = parseSuppliers(rows, existingByName: existing);

        case ImportKind.credits:
          final existing = <String, CreditAccount>{
            for (final c in ref.read(creditAccountsProvider).value ??
                const <CreditAccount>[])
              normalizeForSearch(c.customerName): c,
          };
          _credits = parseCredits(rows, existingByName: existing);
      }

      if (mounted) setState(() => _fileName = file.name);
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّرت قراءة الملف: {0}', [e]));
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = XlsxCodec.writeRows(templateFor(_kind));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: tr('حفظ الملف النموذجي'),
        fileName: trf('نموذج_{0}.xlsx', [_kind.label]),
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
      if (!mounted || path == null) return;
      showOk(context, tr('حُفظ الملف النموذجي'));
    } catch (e) {
      if (mounted) showErr(context, trf('تعذّر حفظ الملف: {0}', [e]));
    }
  }

  // ───────────────────────── التنفيذ ─────────────────────────

  Future<void> _run() async {
    final counts = _counts;
    final policyNote = _kind == ImportKind.products
        ? '«${_policy.label}»'
        : tr('(ستُحدَّث بياناتهم)');

    final ok = await confirmDialog(
      context,
      title: tr('تنفيذ الاستيراد'),
      message: trf('سيُضاف {0} سجلاً جديداً{1}.', [counts.$1, counts.$2 > 0 ? '، و${counts.$2} موجوداً $policyNote' : '']),
      confirmLabel: tr('تنفيذ'),
    );
    if (!ok || !mounted) return;

    setState(() {
      _running = true;
      _progress = 0;
      _result = null;
    });

    final result = switch (_kind) {
      ImportKind.products => await _runProducts(),
      ImportKind.suppliers => await _runSuppliers(),
      ImportKind.credits => await _runCredits(),
    };

    if (!mounted) return;
    setState(() {
      _running = false;
      _progress = 1;
      _result = result;
      _clearPreviews();
    });
  }

  Future<ImportResult> _runProducts() async {
    final preview = _products!;
    final repo = ref.read(inventoryRepositoryProvider)!;
    final rows = preview.validRows;

    final existingById = <String, Product>{
      for (final p in ref.read(allProductsProvider).value ?? const <Product>[])
        p.id: p,
    };

    var created = 0, updated = 0, skipped = 0, failed = 0;
    final errors = <String>[];

    final db = ref.read(firestoreProvider);
    var batch = db.batch();
    var ops = 0, done = 0;

    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }

    try {
      for (final row in rows) {
        final imported = row.product!;
        try {
          Product toWrite;
          DocumentReference<Map<String, dynamic>> target;

          if (row.existingId != null) {
            final existing = existingById[row.existingId];
            if (existing == null) {
              // اختفى بين المعاينة والتنفيذ — نتعامل معه كجديد.
              target = repo.products.doc();
              toWrite = imported.copyWith(id: target.id);
              created++;
            } else {
              if (_policy == DuplicatePolicy.skip) {
                skipped++;
                done++;
                continue;
              }
              toWrite = applyPolicy(
                imported: imported,
                existing: existing,
                policy: _policy,
              );
              target = repo.products.doc(existing.id);
              updated++;
            }
          } else {
            target = repo.products.doc();
            var barcode = imported.barcode;
            if (barcode.isEmpty) {
              // الملف بلا باركود ⇒ نولّد رقماً فريداً من 8 خانات.
              barcode = await repo.generateUniqueBarcode();
            }
            toWrite = imported.copyWith(id: target.id, barcode: barcode);
            created++;
          }

          batch.set(target, toWrite.toMap(), SetOptions(merge: true));
          // كل منتج مستورد يمرّ بنفس منطق المرآة، فيظهر في المتجر تلقائياً.
          repo.applyMirror(batch, toWrite);
          ops += 2;
          if (ops >= AppConstants.batchLimit) await flush();
        } catch (e) {
          failed++;
          errors.add(trf('الصف {0}: {1}', [row.lineNumber, e]));
        }
        done++;
        if (mounted && done % 5 == 0) {
          setState(() => _progress = done / rows.length);
        }
      }
      await flush();
    } catch (e) {
      errors.add('$e');
    }

    return ImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      failed: failed,
      errors: errors,
    );
  }

  Future<ImportResult> _runSuppliers() async {
    final rows = _suppliers!.rows.where((r) => r.isValid).toList();
    final repo = ref.read(suppliersRepositoryProvider)!;
    return _runSimple(
      total: rows.length,
      write: (batch) {
        var created = 0, updated = 0;
        for (final row in rows) {
          final target = row.existingId == null
              ? repo.suppliers.doc()
              : repo.suppliers.doc(row.existingId);
          batch(target, row.supplier!.toMap());
          row.existingId == null ? created++ : updated++;
        }
        return (created, updated);
      },
    );
  }

  Future<ImportResult> _runCredits() async {
    final rows = _credits!.rows.where((r) => r.isValid).toList();
    final repo = ref.read(posRepositoryProvider)!;
    return _runSimple(
      total: rows.length,
      write: (batch) {
        var created = 0, updated = 0;
        for (final row in rows) {
          final target = row.existingId == null
              ? repo.creditAccounts.doc()
              : repo.creditAccounts.doc(row.existingId);
          batch(target, row.account!.toMap());
          row.existingId == null ? created++ : updated++;
        }
        return (created, updated);
      },
    );
  }

  /// تنفيذ مشترك للموردين والكريديات: دفعات بحدّ 400 عملية.
  Future<ImportResult> _runSimple({
    required int total,
    required (int, int) Function(
      void Function(DocumentReference<Map<String, dynamic>>,
          Map<String, dynamic>),
    ) write,
  }) async {
    final db = ref.read(firestoreProvider);
    final errors = <String>[];
    final pending = <(DocumentReference<Map<String, dynamic>>,
        Map<String, dynamic>)>[];

    final counts = write((ref0, data) => pending.add((ref0, data)));

    var failed = 0;
    var batch = db.batch();
    var ops = 0;

    try {
      for (var i = 0; i < pending.length; i++) {
        batch.set(pending[i].$1, pending[i].$2, SetOptions(merge: true));
        ops++;
        if (ops >= AppConstants.batchLimit) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
        if (mounted && i % 5 == 0 && total > 0) {
          setState(() => _progress = i / total);
        }
      }
      if (ops > 0) await batch.commit();
    } catch (e) {
      failed = pending.length;
      errors.add('$e');
    }

    return ImportResult(
      created: failed > 0 ? 0 : counts.$1,
      updated: failed > 0 ? 0 : counts.$2,
      skipped: 0,
      failed: failed,
      errors: errors,
    );
  }

  // ───────────────────────── الواجهة ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final validCount = counts.$1 + counts.$2;

    return AppScaffold(
      route: AppRoutes.importProducts,
      title: tr('استيراد'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _KindCard(
            kind: _kind,
            enabled: !_running,
            onChanged: (k) => setState(() {
              _kind = k;
              _clearPreviews();
              _result = null;
              _fileName = '';
            }),
          ),
          _IntroCard(
            kind: _kind,
            fileName: _fileName,
            onPick: _running ? null : _pickFile,
            onTemplate: _running ? null : _downloadTemplate,
          ),

          if (_running) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 8),
                    Text(trf('جارٍ الاستيراد... {0}٪', [(_progress * 100).round()])),
                  ],
                ),
              ),
            ),
          ],

          if (_result != null) _ResultCard(result: _result!),

          if (_hasPreview && !_hasUsablePreview)
            Card(
              color: const Color(0xFFFFF3E0),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Text(
                          tr('أعمدة إلزامية ناقصة'),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(trf('الملف ينقصه: {0}', [_missingColumns.join('، ')])),
                    const SizedBox(height: 8),
                    Text(
                      tr('حمّل الملف النموذجي واستعمل رؤوسه — أو اكتب الرؤوس بالعربية أو الإنجليزية.'),
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          if (_hasUsablePreview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: tr('جديد'),
                    value: '${counts.$1}',
                    icon: Icons.add_circle_outline,
                    color: AppTheme.success,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: tr('سيُحدَّث'),
                    value: '${counts.$2}',
                    icon: Icons.sync,
                    color: AppTheme.warning,
                  ),
                ),
                Expanded(
                  child: StatCard(
                    label: tr('أخطاء'),
                    value: '${counts.$3}',
                    icon: Icons.error_outline,
                    color: AppTheme.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_kind == ImportKind.products)
              _PolicyCard(
                policy: _policy,
                onChanged: (p) => setState(() => _policy = p),
                updateCount: counts.$2,
              ),
            const SizedBox(height: 8),
            _PreviewCard(
              kind: _kind,
              products: _products,
              suppliers: _suppliers,
              credits: _credits,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _running || validCount == 0 ? null : _run,
                icon: const Icon(Icons.play_arrow),
                label: Text(trf('تنفيذ الاستيراد ({0} سجلاً)', [validCount])),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.kind,
    required this.enabled,
    required this.onChanged,
  });

  final ImportKind kind;
  final bool enabled;
  final ValueChanged<ImportKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                tr('ماذا تستورد؟'),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final k in ImportKind.values)
                  ChoiceChip(
                    label: Text(k.label),
                    selected: kind == k,
                    onSelected: enabled ? (_) => onChanged(k) : null,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              kind.description,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.kind,
    required this.fileName,
    required this.onPick,
    required this.onTemplate,
  });

  final ImportKind kind;
  final String fileName;
  final VoidCallback? onPick;
  final VoidCallback? onTemplate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  trf('استيراد {0} من ملف', [kind.label]),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              trf('الصيغ المدعومة: xlsx و csv.{0}', [kind == ImportKind.products ? tr(' الباركود اختياري — إن غاب يُولَّد رقم من 8 خانات.') : '']),
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.folder_open),
                    label: Text(tr('اختيار ملف')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTemplate,
                    icon: const Icon(Icons.download),
                    label: Text(tr('ملف نموذجي')),
                  ),
                ),
              ],
            ),
            if (fileName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                trf('الملف: {0}', [fileName]),
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({
    required this.policy,
    required this.onChanged,
    required this.updateCount,
  });

  final DuplicatePolicy policy;
  final ValueChanged<DuplicatePolicy> onChanged;
  final int updateCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              trf('المنتجات الموجودة ({0})', [updateCount]),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            RadioGroup<DuplicatePolicy>(
              groupValue: policy,
              onChanged: (v) => onChanged(v ?? DuplicatePolicy.skip),
              child: Column(
                children: [
                  for (final option in DuplicatePolicy.values)
                    RadioListTile<DuplicatePolicy>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: option,
                      title: Text(option.label),
                      subtitle: Text(
                        option.description,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// معاينة قبل أي كتابة.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.kind,
    required this.products,
    required this.suppliers,
    required this.credits,
  });

  final ImportKind kind;
  final ImportPreview? products;
  final SimplePreview<SupplierRow>? suppliers;
  final SimplePreview<CreditRow>? credits;

  @override
  Widget build(BuildContext context) {
    final rowsCount = switch (kind) {
      ImportKind.products => products?.rows.length ?? 0,
      ImportKind.suppliers => suppliers?.rows.length ?? 0,
      ImportKind.credits => credits?.rows.length ?? 0,
    };

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              trf('معاينة قبل الكتابة — {0} صفاً', [rowsCount]),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 320,
            child: switch (kind) {
              ImportKind.products => _productsTable(products!),
              ImportKind.suppliers => ListView(
                  children: [
                    for (final r in suppliers!.rows)
                      _SimpleRow(
                        status: r.status,
                        line: r.lineNumber,
                        title: r.supplier?.name ?? '',
                        subtitle: [
                          if ((r.supplier?.phone ?? '').isNotEmpty)
                            r.supplier!.phone,
                          if ((r.supplier?.address ?? '').isNotEmpty)
                            r.supplier!.address,
                        ].join(' · '),
                        error: r.error,
                      ),
                  ],
                ),
              ImportKind.credits => ListView(
                  children: [
                    for (final r in credits!.rows)
                      _SimpleRow(
                        status: r.status,
                        line: r.lineNumber,
                        title: r.account?.customerName ?? '',
                        subtitle: r.account == null
                            ? ''
                            : trf('دين {0} · مسدَّد {1} · متبقٍّ {2}', [money(r.account!.totalDebt), money(r.account!.totalPaid), money(r.account!.remaining)]),
                        error: r.error,
                      ),
                  ],
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _productsTable(ImportPreview preview) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 34,
          dataRowMaxHeight: 48,
          columns: [
            DataColumn(label: Text(tr('الصف'))),
            DataColumn(label: Text(tr('الحالة'))),
            DataColumn(label: Text(tr('الاسم'))),
            DataColumn(label: Text(tr('الباركود'))),
            DataColumn(label: Text(tr('شراء'))),
            DataColumn(label: Text(tr('بيع'))),
            DataColumn(label: Text(tr('كمية'))),
          ],
          rows: [
            for (final row in preview.rows)
              DataRow(
                cells: row.status == RowStatus.error
                    ? [
                        DataCell(Text('${row.lineNumber}')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close,
                                  size: 15, color: AppTheme.danger),
                              Text(tr(' خطأ'),
                                  style: TextStyle(color: AppTheme.danger)),
                            ],
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 360,
                            child: Text(
                              row.error ?? '',
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                      ]
                    : [
                        DataCell(Text('${row.lineNumber}')),
                        DataCell(
                          row.status == RowStatus.create
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 15, color: AppTheme.success),
                                    Text(tr(' جديد'),
                                        style:
                                            TextStyle(color: AppTheme.success)),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sync,
                                        size: 15, color: AppTheme.warning),
                                    Text(tr(' سيُحدَّث'),
                                        style:
                                            TextStyle(color: AppTheme.warning)),
                                  ],
                                ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              row.product!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(Text(
                          row.product!.barcode.isEmpty
                              ? tr('سيُولَّد')
                              : row.product!.barcode,
                        )),
                        DataCell(Text(moneyPlain(row.product!.purchasePrice))),
                        DataCell(Text(moneyPlain(row.product!.sellPrice))),
                        DataCell(Text('${row.product!.quantity}')),
                      ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleRow extends StatelessWidget {
  const _SimpleRow({
    required this.status,
    required this.line,
    required this.title,
    required this.subtitle,
    this.error,
  });

  final RowStatus status;
  final int line;
  final String title;
  final String subtitle;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final isError = status == RowStatus.error;
    return ListTile(
      dense: true,
      leading: Icon(
        isError
            ? Icons.close
            : (status == RowStatus.create ? Icons.check_circle : Icons.sync),
        size: 18,
        color: isError
            ? AppTheme.danger
            : (status == RowStatus.create
                ? AppTheme.success
                : AppTheme.warning),
      ),
      title: Text(isError ? trf('الصف {0}', [line]) : title),
      subtitle: Text(
        isError ? (error ?? '') : subtitle,
        style: TextStyle(
          fontSize: 11.5,
          color: isError ? AppTheme.danger : null,
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: result.failed == 0
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.failed == 0 ? Icons.check_circle : Icons.warning_amber,
                  color:
                      result.failed == 0 ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  tr('انتهى الاستيراد'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              trf('أُضيف {0}، حُدِّث {1}، تُخطِّي {2}، أخطاء {3}', [result.created, result.updated, result.skipped, result.failed]),
              style: const TextStyle(fontSize: 15),
            ),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(trf('تفاصيل الأخطاء ({0})', [result.errors.length])),
                children: [
                  for (final error in result.errors.take(50))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        error,
                        style: TextStyle(fontSize: 12, color: AppTheme.danger),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
