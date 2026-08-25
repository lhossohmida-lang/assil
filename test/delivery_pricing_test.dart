import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/core/constants/wilayas.dart';

void main() {
  group('ولايات الجزائر', () {
    test('العدد 58 بالضبط', () {
      expect(algeriaWilayas.length, 58);
    });

    test('لا تكرار في الأسماء', () {
      expect(algeriaWilayas.toSet().length, algeriaWilayas.length);
    });

    test('الرقم مشتقّ من الترتيب الرسمي وبخانتين', () {
      expect(wilayaNumber('أدرار'), '01');
      expect(wilayaNumber('الجزائر'), '16');
      expect(wilayaNumber('المنيعة'), '58');
    });

    test('اسم غير معروف يرجع فارغاً لا يرمي', () {
      expect(wilayaNumber('ليون'), '');
      expect(wilayaNumber(''), '');
    });
  });

  group('أسعار التوصيل', () {
    const pricing = DeliveryPricing(
      defaultFee: 600,
      byWilaya: {'الجزائر': 400, 'تمنراست': 1200, 'بومرداس': 0},
    );

    test('الولاية المضبوطة تأخذ سعرها', () {
      expect(pricing.feeFor('الجزائر'), 400);
      expect(pricing.feeFor('تمنراست'), 1200);
    });

    test('غير المضبوطة تأخذ السعر الموحّد', () {
      expect(pricing.feeFor('سطيف'), 600);
      expect(pricing.feeFor('وهران'), 600);
    });

    test('🔒 صفر يعني «توصيل مجاني» لا «غير مضبوط»', () {
      // لو عُدّ الصفر غياباً لعاد سعر بومرداس إلى 600 وحُوسب الزبون
      // على توصيل وعده صاحب المحل بمجانيّته.
      expect(pricing.feeFor('بومرداس'), 0);
    });

    test('المسافات الزائدة لا تكسر المطابقة', () {
      expect(pricing.feeFor('  الجزائر  '), 400);
    });

    test('withWilaya يضيف ولا يمسّ الباقي، clearWilaya يعيد الموحّد', () {
      final added = pricing.withWilaya('سطيف', 750);
      expect(added.feeFor('سطيف'), 750);
      expect(added.feeFor('الجزائر'), 400);

      final cleared = added.clearWilaya('سطيف');
      expect(cleared.feeFor('سطيف'), 600);
      expect(cleared.customCount, pricing.customCount);
    });

    test('سعر سالب يُرفض ولا يُخزَّن', () {
      final same = pricing.withWilaya('سطيف', -100);
      expect(same.feeFor('سطيف'), 600);
    });

    group('السعر الفعّال للطلب', () {
      test('طلب الموقع يصل بصفر ⇒ يُحسب من الولاية', () {
        expect(
          pricing.effectiveFee(wilaya: 'تمنراست', orderFee: 0),
          1200,
        );
      });

      test('🔒 سعر مكتوب في الطلب أولى من الجدول', () {
        // طلب هاتفي اتُّفق فيه على سعر خاص: لا يجوز أن يعيد الجدول
        // كتابته من تحت يد صاحب المحل.
        expect(
          pricing.effectiveFee(wilaya: 'تمنراست', orderFee: 900),
          900,
        );
      });

      test('ولاية بلا سعر ولا جدول ⇒ صفر لا خطأ', () {
        const empty = DeliveryPricing();
        expect(empty.effectiveFee(wilaya: 'سطيف', orderFee: 0), 0);
      });
    });

    test('الجدول يعبر الحفظ والقراءة كما هو', () {
      final restored = DeliveryPricing.fromMap(pricing.toMap());
      expect(restored.defaultFee, pricing.defaultFee);
      expect(restored.byWilaya, pricing.byWilaya);
    });

    test('مستند تالف أو ناقص لا يُسقط الشاشة', () {
      expect(DeliveryPricing.fromMap(null).defaultFee, 0);
      expect(DeliveryPricing.fromMap(const {}).byWilaya, isEmpty);
      // قيمة نصّية بدل رقم تُتجاهل بدل أن ترمي.
      final messy = DeliveryPricing.fromMap(const {
        'defaultFee': 500,
        'byWilaya': {'سطيف': 'مجاني', 'وهران': 700},
      });
      expect(messy.feeFor('سطيف'), 500);
      expect(messy.feeFor('وهران'), 700);
    });
  });
}
