import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/printing/services/ticket_service.dart';

void main() {
  group('عدد وحدات Code128', () {
    test('8 أرقام (الطول الذي نولّده) = 79 وحدة', () {
      // start-C(11) + 4 رموز بيانات(44) + تحقّق(11) + stop(13) = 79
      expect(code128ModuleCount('12345678'), 79);
    });

    test('13 رقماً أطول بكثير — رقم فردي يُجبر على تبديل المجموعة', () {
      // start-C(11) + 6 أزواج(66) + تبديل مجموعة(11) + رقم مفرد(11)
      //   + تحقّق(11) + stop(13) = 123
      final eight = code128ModuleCount('12345678');
      final thirteen = code128ModuleCount('1234567890123');
      expect(thirteen, 123);
      // ~22 وحدة زائدة بسبب التبديل مقارنةً بـ12 رقماً (زوجي).
      expect(code128ModuleCount('123456789012'), 101);
      expect(thirteen - 101, 22);
      expect(thirteen, greaterThan(eight));
    });

    test('نص فارغ لا يرمي استثناءً', () {
      expect(code128ModuleCount(''), 0);
    });
  });

  group('قياسات الباركود على ملصق 40مم بدقّة 203', () {
    const labelWidth = 39.0; // 40مم ناقص هامش المحتوى
    const dpi = 203;

    test('8 أرقام ⇒ 3 نقاط للوحدة = يُقرأ', () {
      final m = computeBarcodeMetrics(
        data: '12345678',
        availableWidthMm: labelWidth,
        dpi: dpi,
      );
      expect(m.modules, 79);
      expect(m.dotsPerModule, 3);
      expect(m.isReadable, isTrue);
    });

    test('13 رقماً ⇒ نقطتان فقط = على الحافة (سبب فشل القراءة سابقاً)', () {
      final m = computeBarcodeMetrics(
        data: '1234567890123',
        availableWidthMm: labelWidth,
        dpi: dpi,
      );
      expect(m.dotsPerModule, 2);
      expect(m.isReadable, isFalse);
      expect(m.isMarginal, isTrue);
    });

    test('العرض مضاعف صحيح لنقطة الطابعة — لا كسور', () {
      for (final data in ['12345678', '87654321', '1234567890123', 'ABC123']) {
        final m = computeBarcodeMetrics(
          data: data,
          availableWidthMm: labelWidth,
          dpi: dpi,
        );
        final dotsTotal = m.widthMm / m.dotMm;
        // العرض = عدد صحيح من النقاط (بهامش تقريب عائم ضئيل).
        expect(
          (dotsTotal - dotsTotal.round()).abs(),
          lessThan(1e-9),
          reason: 'العرض ليس مضاعفاً صحيحاً للنقطة عند «$data»',
        );
        expect(dotsTotal.round(), m.modules * m.dotsPerModule);
      }
    });

    test('المنطقة الصامتة ≥ 10 وحدات على كل جانب (شرط المعيار)', () {
      for (final data in ['12345678', '1234567890123', '99999999']) {
        final m = computeBarcodeMetrics(
          data: data,
          availableWidthMm: labelWidth,
          dpi: dpi,
        );
        expect(
          m.quietZoneModules,
          greaterThanOrEqualTo(10.0),
          reason: 'المنطقة الصامتة أقلّ من 10 وحدات عند «$data»',
        );
      }
    });

    test('الرمز لا يتجاوز العرض المتاح أبداً', () {
      for (final data in ['12345678', '1234567890123']) {
        final m = computeBarcodeMetrics(
          data: data,
          availableWidthMm: labelWidth,
          dpi: dpi,
        );
        expect(m.widthMm, lessThanOrEqualTo(labelWidth));
      }
    });

    test('ملصق ضيّق جداً: لا نُرجع صفراً — نقطة واحدة على الأقل', () {
      final m = computeBarcodeMetrics(
        data: '1234567890123',
        availableWidthMm: 8,
        dpi: dpi,
      );
      expect(m.dotsPerModule, 1);
      expect(m.isReadable, isFalse);
    });

    test('دقّة أعلى (300dpi) تعطي وحدات أعرض بالنقاط', () {
      final at203 = computeBarcodeMetrics(
        data: '12345678',
        availableWidthMm: labelWidth,
        dpi: 203,
      );
      final at300 = computeBarcodeMetrics(
        data: '12345678',
        availableWidthMm: labelWidth,
        dpi: 300,
      );
      expect(at300.dotsPerModule, greaterThan(at203.dotsPerModule));
      // العرض بالمليمتر يبقى متقارباً — النقاط أصغر لكنها أكثر.
      expect((at300.widthMm - at203.widthMm).abs(), lessThan(3));
    });
  });
}
