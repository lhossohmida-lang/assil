import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/i18n/app_strings.dart';
import '../utils/formatters.dart';

@JS('KmsanHtml5Qr.start')
external JSPromise _startQr(
  JSString elementId,
  JSFunction onSuccess,
  JSFunction onError,
);

@JS('KmsanHtml5Qr.stop')
external JSPromise _stopQr(JSString elementId);

int _nextScannerId = 0;

String _registerScannerView() {
  final id = 'kmsan-html5-qr-${_nextScannerId++}';
  final viewType = '$id-view';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final host = web.HTMLDivElement()
      ..id = id
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#111'
      ..style.overflow = 'hidden';
    return host;
  });

  return '$viewType|$id';
}

Future<String?> scanWeb(
  BuildContext context, {
  required bool continuous,
  FutureOr<void> Function(String code)? onCode,
}) async {
  final registration = _registerScannerView().split('|');
  final viewType = registration[0];
  final elementId = registration[1];
  final result = Completer<String?>();
  var lastCode = '';
  var lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  late final void Function(dynamic) onSuccess;
  late final void Function(dynamic) onError;

  onSuccess = (dynamic raw) async {
    final code = cleanBarcode('$raw');
    if (code.isEmpty) return;

    final now = DateTime.now();
    if (code == lastCode && now.difference(lastAt).inMilliseconds < 1200) {
      return;
    }
    lastCode = code;
    lastAt = now;

    if (!continuous) {
      if (!result.isCompleted) result.complete(code);
      return;
    }
    await onCode?.call(code);
  };

  onError = (dynamic error) {
    // html5-qrcode reports normal "not found" frames continuously. Only
    // surface an error before the first successful read.
    if (!result.isCompleted && '$error'.toLowerCase().contains('permission')) {
      result.completeError(StateError('$error'));
    }
  };

  final dialogFuture = showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _Html5QrDialog(
      viewType: viewType,
      elementId: elementId,
      continuous: continuous,
      onSuccess: onSuccess,
      onError: onError,
      onClose: () {
        if (!result.isCompleted) result.complete(null);
        Navigator.of(dialogContext).pop();
      },
    ),
  );

  try {
    final value = await result.future;
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    return value;
  } catch (error) {
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trf('تعذّر فتح الكاميرا: {0}', [error]))),
      );
    }
    return null;
  } finally {
    await dialogFuture;
  }
}

class _Html5QrDialog extends StatefulWidget {
  const _Html5QrDialog({
    required this.viewType,
    required this.elementId,
    required this.continuous,
    required this.onSuccess,
    required this.onError,
    required this.onClose,
  });

  final String viewType;
  final String elementId;
  final bool continuous;
  final void Function(dynamic) onSuccess;
  final void Function(dynamic) onError;
  final VoidCallback onClose;

  @override
  State<_Html5QrDialog> createState() => _Html5QrDialogState();
}

class _Html5QrDialogState extends State<_Html5QrDialog> {
  bool _starting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final success = ((JSString raw) => widget.onSuccess(raw.toDart)).toJS;
      final error = ((JSString raw) => widget.onError(raw.toDart)).toJS;
      await _startQr(widget.elementId.toJS, success, error).toDart;
      if (mounted) setState(() => _starting = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _stop() async {
    try {
      await _stopQr(widget.elementId.toJS).toDart;
    } catch (_) {
      // إغلاق الكاميرا يُنفّذ أيضاً عند إغلاق الحوار؛ لا نمنع إغلاق الواجهة
      // إذا كان المتصفح قد أوقف البث مسبقاً.
    }
  }

  @override
  void dispose() {
    unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 460,
          height: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.continuous
                            ? tr('مسح متواصل')
                            : tr('وجّه الكاميرا إلى الباركود'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('إغلاق'),
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        HtmlElementView(viewType: widget.viewType),
                        if (_starting)
                          const ColoredBox(
                            color: Colors.black,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        if (_error != null)
                          ColoredBox(
                            color: Colors.black87,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Text(
                                  trf('تعذّر فتح الكاميرا: {0}', [_error]),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
}
