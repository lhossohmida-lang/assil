class PaperMeasurement {
  const PaperMeasurement({
    required this.widthMm,
    required this.heightMm,
    required this.dpiX,
    required this.dpiY,
  });

  final double widthMm;
  final double heightMm;
  final int dpiX;
  final int dpiY;

  @override
  String toString() =>
      '${widthMm.toStringAsFixed(1)}×${heightMm.toStringAsFixed(1)}مم '
      '(${dpiX}dpi)';
}

class PaperApplyResult {
  const PaperApplyResult({
    required this.applied,
    required this.message,
    this.before,
    this.after,
  });

  final bool applied;
  final String message;
  final PaperMeasurement? before;
  final PaperMeasurement? after;
}

class WindowsPrinterFfi {
  WindowsPrinterFfi._();

  static bool get isAvailable => false;

  static PaperMeasurement? measure(String printerName) => null;

  static PaperApplyResult applyCustomPaper({
    required String printerName,
    required double widthMm,
    required double heightMm,
  }) {
    return const PaperApplyResult(
      applied: false,
      message: 'ضبط ورق الدرايفر متاح على ويندوز فقط',
    );
  }
}
