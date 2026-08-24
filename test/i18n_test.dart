import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/core/i18n/app_strings.dart';
import 'package:kmsan/core/i18n/strings_fr.dart';

void main() {
  tearDown(() => AppLocaleState.code = 'ar');

  group('اللغة العربية هي الأصل', () {
    test('tr يُرجع النصّ كما هو', () {
      AppLocaleState.code = 'ar';
      expect(tr('نقطة البيع'), 'نقطة البيع');
      expect(tr('نصّ لا وجود له في أي قاموس'), 'نصّ لا وجود له في أي قاموس');
    });

    test('trf يستبدل القيم بلا ترجمة', () {
      AppLocaleState.code = 'ar';
      expect(trf('{0} قطعة', [5]), '5 قطعة');
      expect(trf('أُرجع {0} × {1}', ['قميص', 2]), 'أُرجع قميص × 2');
    });
  });

  group('الفرنسية', () {
    setUp(() => AppLocaleState.code = 'fr');

    test('tr يترجم ما في القاموس', () {
      expect(tr('نقطة البيع'), 'Point de vente');
      expect(tr('المخزون'), 'Stock');
      expect(tr('إلغاء'), 'Annuler');
    });

    test('🔒 السقوط الآمن: نصّ بلا ترجمة يظهر بالعربية لا فارغاً', () {
      const unknown = 'نصّ جديد لم يُترجم بعد';
      expect(frenchStrings.containsKey(unknown), isFalse);
      expect(tr(unknown), unknown);
      expect(tr(unknown), isNotEmpty);
    });

    test('trf يترجم القالب ثم يستبدل القيم بترتيبها', () {
      expect(trf('{0} قطعة', [5]), '5 pièce(s)');
      expect(trf('سُحب {0} — {1}', ['1500.00 د.ج', 'كهرباء']),
          '1500.00 د.ج retiré — كهرباء');
    });

    test('ترتيب القيم محفوظ حتى لو اختلف ترتيبها في الفرنسية', () {
      // القالب: «المنتج الحالي: {0} ({1})»
      final out = trf('المنتج الحالي: {0} ({1})', ['قميص', '1800']);
      expect(out.contains('قميص'), isTrue);
      expect(out.contains('1800'), isTrue);
      expect(out.startsWith('Produit actuel'), isTrue);
    });
  });

  group('سلامة القاموس', () {
    test('لا مفتاح فارغ ولا ترجمة فارغة', () {
      for (final entry in frenchStrings.entries) {
        expect(entry.key.trim(), isNotEmpty);
        expect(entry.value.trim(), isNotEmpty,
            reason: 'ترجمة فارغة للمفتاح «${entry.key}»');
      }
    });

    test('🔒 كل قالب فيه {0} تُقابله {0} في الترجمة', () {
      final placeholder = RegExp(r'\{(\d+)\}');
      for (final entry in frenchStrings.entries) {
        final inKey = placeholder
            .allMatches(entry.key)
            .map((m) => m.group(1))
            .toSet();
        final inValue = placeholder
            .allMatches(entry.value)
            .map((m) => m.group(1))
            .toSet();
        expect(
          inValue,
          inKey,
          reason: 'اختلاف في القيم المتغيّرة للمفتاح «${entry.key}»',
        );
      }
    });

    test('لا محارف تحكّم تسرّبت أثناء التحرير الآلي', () {
      for (final entry in frenchStrings.entries) {
        for (final code in entry.value.codeUnits) {
          expect(code, greaterThan(8),
              reason: 'محرف تحكّم في «${entry.key}»');
        }
      }
    });
  });
}
