import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../utils/formatters.dart';
import '../../core/i18n/app_strings.dart';

/// المسح بالكاميرا.
///
/// على أندرويد نستعمل **ماسح غوغل الرسمي** (Google Code Scanner) عبر
/// MethodChannel: لا يطلب صلاحية كاميرا، وواجهته (الزوايا الملوّنة وسطر
/// "Scanned by Google") تقرأ من مسافة أبعد وبإضاءة أضعف من أي واجهة نكتبها.
///
/// عند فشله — أو على ويندوز حيث لا يوجد ماسح غوغل — نسقط إلى
/// `mobile_scanner`. وعلى ويندوز لا يدعم mobile_scanner المنصّة أصلاً،
/// فنكتفي برسالة تُذكّر بالقارئ السلكي (وهو المستعمل هناك أصلاً).
class ScannerService {
  const ScannerService();

  static const MethodChannel _channel = MethodChannel('kmsan/code_scanner');

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// هل تتوفّر كاميرا مسح على هذه المنصّة؟
  static bool get isSupported => kIsWeb || _isAndroid || Platform.isIOS;

  /// تنزيل وحدة ماسح غوغل مسبقاً (يُنادى مرة عند إقلاع التطبيق).
  static Future<void> prefetch() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('prefetch');
    } catch (_) {
      // لا يهمّ: التنزيل سيحدث عند أول مسح.
    }
  }

  /// قراءة واحدة. تُرجع `null` إن ألغى المستخدم.
  static Future<String?> scanOnce(BuildContext context) async {
    if (_isAndroid) {
      try {
        final value = await _channel.invokeMethod<String>('scan');
        if (value != null) return cleanBarcode(value);
        return null; // إلغاء المستخدم — ليس خطأً.
      } on PlatformException catch (e) {
        if (e.code == 'BUSY') return null;
        // خدمات غوغل غير متوفّرة على هذا الجهاز ⇒ الاحتياطي.
        debugPrint(trf('[KMSAN] ماسح غوغل غير متاح: {0} {1}', [e.code, e.message]));
      } catch (e) {
        debugPrint(trf('[KMSAN] ماسح غوغل فشل: {0}', [e]));
      }
    }

    if (!context.mounted) return null;
    return _fallbackScan(context, continuous: false);
  }

  /// مسح متواصل: يستدعي `onCode` لكل قراءة حتى يُلغي المستخدم.
  ///
  /// ماسح غوغل يقرأ **مرة واحدة ثم يُغلق** — فنعيد فتحه في حلقة، وإلا
  /// اضطر البائع للضغط على زر المسح لكل قطعة.
  static Future<void> scanContinuous(
    BuildContext context,
    FutureOr<void> Function(String code) onCode,
  ) async {
    if (_isAndroid) {
      while (context.mounted) {
        String? code;
        try {
          code = await _channel.invokeMethod<String>('scan');
        } catch (e) {
          debugPrint(trf('[KMSAN] فشل المسح المتواصل: {0}', [e]));
          break; // ننتقل للاحتياطي أدناه.
        }
        if (code == null) return; // ألغى المستخدم ⇒ انتهى المسح المتواصل.
        await onCode(cleanBarcode(code));
      }
      return;
    }

    if (!context.mounted) return;
    await _fallbackScan(context, continuous: true, onCode: onCode);
  }

  static Future<String?> _fallbackScan(
    BuildContext context, {
    required bool continuous,
    FutureOr<void> Function(String code)? onCode,
  }) async {
    if (!isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('المسح بالكاميرا غير متاح على هذا الجهاز — استعمل القارئ السلكي'),
          ),
          backgroundColor: AppTheme.warning,
        ),
      );
      return null;
    }

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _MobileScannerDialog(
        continuous: continuous,
        onCode: onCode,
      ),
    );
  }
}

class _MobileScannerDialog extends StatefulWidget {
  const _MobileScannerDialog({required this.continuous, this.onCode});

  final bool continuous;
  final FutureOr<void> Function(String code)? onCode;

  @override
  State<_MobileScannerDialog> createState() => _MobileScannerDialogState();
}

class _MobileScannerDialogState extends State<_MobileScannerDialog> {
  late final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    autoZoom: true,
    formats: const [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.itf14,
      BarcodeFormat.qrCode,
    ],
  );

  /// آخر رمز مقروء ووقته — لمنع تكرار نفس القطعة عشرات المرات في الثانية.
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _count = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    final code = cleanBarcode(raw);
    if (code.isEmpty) return;

    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastAt).inMilliseconds < 1500) {
      return;
    }
    _lastCode = code;
    _lastAt = now;

    await HapticFeedback.mediumImpact();

    if (!widget.continuous) {
      if (mounted) Navigator.of(context).pop(code);
      return;
    }
    setState(() => _count++);
    await widget.onCode?.call(code);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 420,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.continuous
                          ? trf('مسح متواصل — قُرئ {0}', [_count])
                          : tr('وجّه الكاميرا إلى الباركود'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tr('الإضاءة'),
                    icon: const Icon(Icons.flashlight_on),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                  IconButton(
                    tooltip: tr('إغلاق'),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        trf('تعذّر فتح الكاميرا: {0}', [error.errorCode.name]),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
}
