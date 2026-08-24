import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/i18n/app_strings.dart';

/// نافذة اختيار لون بدقّة: دائرة ألوان + شريط الإضاءة + كتابة الرمز.
///
/// مكتوبة يدوياً بلا حزمة خارجية: الحزم الجاهزة تجرّ اعتماديات وواجهات
/// إنجليزية لا تُترجم، والدائرة هنا رياضيات بسيطة (زاوية = درجة اللون،
/// نصف القطر = التشبّع).
Future<Color?> showColorWheelDialog(
  BuildContext context, {
  Color initial = const Color(0xFF1565C0),
}) =>
    showDialog<Color>(
      context: context,
      builder: (_) => _ColorWheelDialog(initial: initial),
    );

class _ColorWheelDialog extends StatefulWidget {
  const _ColorWheelDialog({required this.initial});
  final Color initial;

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController _hexCtrl =
      TextEditingController(text: _hex(_hsv.toColor()));

  Color get _color => _hsv.toColor();

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _setHsv(HSVColor next) {
    setState(() {
      _hsv = next;
      _hexCtrl.text = _hex(next.toColor());
    });
  }

  void _applyHex(String raw) {
    var text = raw.trim().replaceAll('#', '');
    if (text.length == 3) {
      text = text.split('').map((c) => '$c$c').join();
    }
    if (text.length != 6) return;
    final value = int.tryParse(text, radix: 16);
    if (value == null) return;
    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | value)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('اختيار اللون')),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: _Wheel(hsv: _hsv, onChanged: _setHsv),
              ),
              const SizedBox(height: 14),

              // شريط الإضاءة: من الأسود إلى اللون بأقصى إضاءة.
              Row(
                children: [
                  const Icon(Icons.brightness_6, size: 18),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 12,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 10),
                      ),
                      child: Slider(
                        value: _hsv.value,
                        onChanged: (v) => _setHsv(_hsv.withValue(v)),
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder, width: 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _hexCtrl,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[#0-9a-fA-F]'),
                        ),
                        LengthLimitingTextInputFormatter(7),
                      ],
                      decoration: InputDecoration(
                        labelText: tr('رمز اللون'),
                        isDense: true,
                      ),
                      onChanged: _applyHex,
                      onSubmitted: _applyHex,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),
              // ألوان جاهزة شائعة في الألبسة.
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _presets)
                    InkWell(
                      onTap: () => _setHsv(HSVColor.fromColor(c)),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: AppTheme.cardBorder, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('إلغاء')),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(tr('اختيار')),
        ),
      ],
    );
  }

  static const List<Color> _presets = [
    Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF9E9E9E),
    Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF01579B),
    Color(0xFF004D40), Color(0xFF1B5E20), Color(0xFF827717),
    Color(0xFF3E2723), Color(0xFF4E342E), Color(0xFF795548),
    Color(0xFFD7CCC8), Color(0xFFEFEBE9), Color(0xFFF5F5DC),
    Color(0xFFB71C1C), Color(0xFF880E4F), Color(0xFF4A148C),
  ];
}

/// دائرة الألوان: الزاوية = درجة اللون، نصف القطر = التشبّع.
class _Wheel extends StatelessWidget {
  const _Wheel({required this.hsv, required this.onChanged});

  final HSVColor hsv;
  final ValueChanged<HSVColor> onChanged;

  void _handle(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final delta = local - center;

    // زاوية من 0 إلى 360 — تبدأ من اليمين وتدور مع عقارب الساعة.
    var hue = (math.atan2(delta.dy, delta.dx) * 180 / math.pi) % 360;
    if (hue < 0) hue += 360;

    final saturation = (delta.distance / radius).clamp(0.0, 1.0);
    onChanged(hsv.withHue(hue).withSaturation(saturation));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          child: CustomPaint(
            painter: _WheelPainter(hsv),
            size: size,
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.hsv);
  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1) طيف درجات اللون حول المحيط.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          colors: [
            for (var i = 0; i <= 360; i += 30)
              HSVColor.fromAHSV(1, i % 360.0, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );

    // 2) التشبّع: أبيض في المركز يتلاشى نحو الحافة.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );

    // 3) الإضاءة: طبقة سوداء بشفافية مكمّلة.
    if (hsv.value < 1) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withValues(alpha: 1 - hsv.value),
      );
    }

    // 4) مؤشّر الاختيار.
    final angle = hsv.hue * math.pi / 180;
    final pointer = center +
        Offset(math.cos(angle), math.sin(angle)) * (radius * hsv.saturation);
    canvas.drawCircle(
      pointer,
      9,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      pointer,
      9,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.hsv != hsv;
}
