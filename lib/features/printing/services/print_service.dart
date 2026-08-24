import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../data/print_queue_repository.dart';
import '../data/windows_printer_ffi.dart';
import '../domain/models/print_settings.dart';
import '../../inventory/domain/models/product.dart';
import '../../sales/domain/models/sale.dart';
import 'built_document.dart';
import 'order_label_service.dart';
import 'receipt_service.dart';
import 'ticket_service.dart';
import '../../../core/i18n/app_strings.dart';

class PrintOutcome {
  const PrintOutcome(this.ok, this.message, {this.queued = false});
  final bool ok;
  final String message;

  /// أُرسل إلى طابعة الحاسوب بدل الطباعة محلياً.
  final bool queued;
}

/// واجهة الطباعة الموحّدة.
///
/// على الحاسوب: يطبع محلياً على الطابعة المختارة.
/// على الهاتف: يضع أمراً في الطابور ليطبعه الحاسوب — البائع يضغط «طباعة»
/// من هاتفه فتخرج الورقة من طابعة المحل.
class PrintService {
  PrintService({
    required this.settings,
    this.queue,
    this.branding = ReceiptBranding.none,
  });

  final PrintSettings settings;

  /// روابط التواصل — تُطبع كرموز QR على الوصل إن فُعّلت.
  final ReceiptBranding branding;

  /// طابور الطباعة عن بُعد — `null` يعني لا متجر محلول بعد.
  final PrintQueueRepository? queue;

  static bool get _isDesktop {
    if (kIsWeb) return false;
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  static bool get canPrintLocally => _isDesktop;

  // ───────────────────────── وصل البيع ─────────────────────────

  Future<PrintOutcome> printReceipt(Sale sale, {bool allowDialog = true}) async {
    if (!canPrintLocally) {
      return _enqueue(
        kind: PrintJobKind.receipt,
        refId: sale.id,
        title: sale.productsTitle,
      );
    }
    final doc = await ReceiptService.build(
      sale: sale,
      settings: settings.receipt,
      branding: branding,
    );
    return _printLocal(
      printerName: settings.receipt.printerName,
      doc: doc,
      jobName: trf('وصل {0}', [sale.invoiceNumber]),
      allowDialog: allowDialog,
      // الوصل يخرج من بكرة متصلة: لا معنى لضبط فورم ورق فيها،
      // والمقاس الديناميكي المرسل مع الوظيفة يكفي.
      applyDriverPaper: false,
    );
  }

  // ───────────────────────── تيكت الباركود ─────────────────────────

  Future<PrintOutcome> printTicket(
    Product product, {
    int copies = 1,
    bool allowDialog = true,
  }) async {
    if (!canPrintLocally) {
      return _enqueue(
        kind: PrintJobKind.ticket,
        refId: product.id,
        title: product.name,
        copies: copies,
      );
    }
    final doc = await TicketService.build(
      product: product,
      settings: settings.ticket,
      copies: copies,
    );
    return _printLocal(
      printerName: settings.ticket.printerName,
      doc: doc,
      jobName: trf('تيكت {0}', [product.name]),
      allowDialog: allowDialog,
      applyDriverPaper: settings.ticket.applyDriverPaperSize,
      paperWidthMm: settings.ticket.labelWidthMm,
      paperHeightMm: settings.ticket.effectivePitchMm,
    );
  }

  // ───────────────────────── ملصق الشحن ─────────────────────────

  Future<PrintOutcome> printOrderLabel(
    OrderLabelData data, {
    String? orderId,
    bool allowDialog = true,
  }) async {
    if (!canPrintLocally) {
      return _enqueue(
        kind: PrintJobKind.orderLabel,
        refId: orderId ?? data.orderNumber,
        title: trf('طلب {0}', [data.orderNumber]),
      );
    }
    final doc = await OrderLabelService.build(
      data: data,
      settings: settings.orderLabel,
    );
    return _printLocal(
      printerName: settings.orderLabel.printerName,
      doc: doc,
      jobName: trf('ملصق {0}', [data.orderNumber]),
      allowDialog: allowDialog,
      applyDriverPaper: true,
      paperWidthMm: settings.orderLabel.widthMm,
      paperHeightMm: settings.orderLabel.heightMm,
    );
  }

  // ───────────────────────── التنفيذ ─────────────────────────

  Future<PrintOutcome> _enqueue({
    required PrintJobKind kind,
    required String refId,
    required String title,
    int copies = 1,
  }) async {
    final q = queue;
    if (q == null) {
      return PrintOutcome(false, tr('تعذّر إرسال أمر الطباعة'));
    }
    try {
      await q.enqueue(kind: kind, refId: refId, title: title, copies: copies);
      return PrintOutcome(
        true,
        tr('أُرسل إلى طابعة الحاسوب 🖨'),
        queued: true,
      );
    } catch (e) {
      return PrintOutcome(false, trf('تعذّر إرسال أمر الطباعة: {0}', [e]));
    }
  }

  /// طباعة محلية على الطابعة المختارة.
  ///
  /// ⚠️ إن أرجعت `directPrintPdf` القيمة false **لا نُعيد الإرسال عبر نافذة
  /// الطباعة**: قد تكون الورقة خرجت فعلاً وأرجعت المكتبة false لسبب آخر،
  /// فتخرج نسخة ثانية ويحتار البائع أيّهما يعطي الزبونة.
  Future<PrintOutcome> _printLocal({
    required String printerName,
    required BuiltDocument doc,
    required String jobName,
    required bool applyDriverPaper,
    double? paperWidthMm,
    double? paperHeightMm,
    bool allowDialog = true,
  }) async {
    try {
      if (printerName.trim().isEmpty) {
        // أمر قادم من الطابور (الهاتف) ولا طابعة مضبوطة هنا: نفشل برسالة
        // واضحة بدل فتح نافذة طباعة على حاسوب لا أحد أمامه فتتوقّف
        // الوظيفة إلى الأبد.
        if (!allowDialog) {
          return PrintOutcome(
            false,
            tr('لا توجد طابعة مضبوطة على حاسوب المحل — اخترها من الإعدادات'),
          );
        }
        // اختيار يدوي: لم يُرسل شيء بعد، فلا خطر تكرار.
        final ok = await Printing.layoutPdf(
          onLayout: (_) => doc.bytes,
          name: jobName,
          format: doc.format,
          dynamicLayout: false,
        );
        return PrintOutcome(ok, ok ? tr('أُرسل للطباعة') : tr('أُلغيت الطباعة'));
      }

      var usePrinterSettings = false;
      var note = '';

      if (applyDriverPaper &&
          WindowsPrinterFfi.isAvailable &&
          paperWidthMm != null &&
          paperHeightMm != null) {
        final result = WindowsPrinterFfi.applyCustomPaper(
          printerName: printerName,
          widthMm: paperWidthMm,
          heightMm: paperHeightMm,
        );
        // نتبع إعدادات الدرايفر **فقط** إذا تحقّقنا بالقياس أنها صحيحة.
        // إن فشل الضبط نفرض المقاس من الوظيفة نفسها — أفضل من ورق ضائع.
        usePrinterSettings = result.applied;
        if (!result.applied) note = ' (${result.message})';
      }

      final printer = await _resolvePrinter(printerName);
      if (printer == null) {
        return PrintOutcome(
          false,
          trf('لم تُوجد الطابعة «{0}» — اخترها من الإعدادات', [printerName]),
        );
      }

      final ok = await Printing.directPrintPdf(
        printer: printer,
        onLayout: (_) => doc.bytes,
        name: jobName,
        format: doc.format,
        dynamicLayout: false,
        usePrinterSettings: usePrinterSettings,
      );

      if (!ok) {
        return PrintOutcome(
          false,
          trf('الطابعة لم تقبل الوظيفة{0} — تحقّق من الورق والاتصال', [note]),
        );
      }
      return PrintOutcome(true, trf('تمت الطباعة{0}', [note]));
    } catch (e) {
      return PrintOutcome(false, trf('فشلت الطباعة: {0}', [e]));
    }
  }

  static Future<Printer?> _resolvePrinter(String name) async {
    try {
      final printers = await Printing.listPrinters();
      for (final p in printers) {
        if (p.name == name) return p;
      }
      for (final p in printers) {
        if (p.name.trim().toLowerCase() == name.trim().toLowerCase()) return p;
      }
      return null;
    } catch (e) {
      debugPrint(trf('[KMSAN] تعذّر سرد الطابعات: {0}', [e]));
      return null;
    }
  }
}
