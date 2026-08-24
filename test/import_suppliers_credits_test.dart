import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/customers/domain/models/customer.dart';
import 'package:kmsan/features/import_products/domain/import_kinds.dart';
import 'package:kmsan/features/suppliers/domain/models/supplier.dart';
import 'package:kmsan/shared/utils/formatters.dart';

void main() {
  group('استيراد الموردين', () {
    test('رؤوس عربية وإنجليزية معاً تُطابَق', () {
      final preview = parseSuppliers(
        [
          ['المورّد', 'phone', 'العنوان'],
          ['حاج مبروك', '0555111222', 'بئر خادم'],
        ],
        existingByName: const {},
      );

      expect(preview.isUsable, isTrue);
      expect(preview.missingColumns, isEmpty);
      expect(preview.createCount, 1);

      final supplier = preview.rows.single.supplier!;
      expect(supplier.name, 'حاج مبروك');
      expect(supplier.phone, '0555111222');
      expect(supplier.address, 'بئر خادم');
    });

    test('العمود الإلزامي الوحيد هو الاسم — وغيابه يُوقف الاستيراد', () {
      final preview = parseSuppliers(
        [
          ['الهاتف', 'العنوان'],
          ['0555111222', 'بئر خادم'],
        ],
        existingByName: const {},
      );

      expect(preview.isUsable, isFalse);
      expect(preview.missingColumns, ['الاسم']);
      expect(preview.rows, isEmpty,
          reason: 'لا نستورد صفاً واحداً من ملف ينقصه عمود إلزامي');
    });

    test('مورّد موجود يُحدَّث لا يُكرَّر — والمطابقة تتجاهل التشكيل', () {
      const existing = Supplier(id: 's1', name: 'حاج مبروك');
      final preview = parseSuppliers(
        [
          ['الاسم', 'المدفوع'],
          ['حاج مبروك', '5000'],
        ],
        existingByName: {normalizeForSearch('حاج مبروك'): existing},
      );

      expect(preview.updateCount, 1);
      expect(preview.createCount, 0);
      expect(preview.rows.single.existingId, 's1');
      expect(preview.rows.single.supplier!.totalPaid, 5000);
    });

    test('اسم فارغ مع بيانات أخرى ⇒ خطأ يذكر الصف، وبقيّة الملف تمرّ', () {
      // ملاحظة: صفّ **كل** خلاياه فارغة يُعدّ صفاً فارغاً يُتجاهل بصمت
      // (الاختبار التالي)، أمّا صفّ فيه هاتف بلا اسم فهو خطأ حقيقي:
      // بيانات أُدخلت وضاع مفتاحها.
      final preview = parseSuppliers(
        [
          ['الاسم', 'الهاتف'],
          ['', '0555111222'],
          ['مورّد سليم', '0666'],
        ],
        existingByName: const {},
      );

      expect(preview.errorCount, 1);
      expect(preview.createCount, 1,
          reason: 'صف واحد خاطئ لا يُلغي الملف كلّه');
      expect(preview.rows.first.error, contains('2'));
    });

    test('الصفوف الفارغة تُتجاهل ولا تُعدّ أخطاءً', () {
      final preview = parseSuppliers(
        [
          ['الاسم'],
          ['مورّد'],
          ['', ''],
          ['   '],
        ],
        existingByName: const {},
      );

      expect(preview.createCount, 1);
      expect(preview.errorCount, 0);
    });
  });

  group('استيراد الكريديات', () {
    test('الاسم والدين إلزاميان معاً', () {
      final missingDebt = parseCredits(
        [
          ['الاسم'],
          ['فاطمة'],
        ],
        existingByName: const {},
      );
      expect(missingDebt.missingColumns, ['الدين']);

      final missingBoth = parseCredits(
        [
          ['الهاتف'],
          ['0555'],
        ],
        existingByName: const {},
      );
      expect(missingBoth.missingColumns, ['الاسم', 'الدين']);
    });

    test('صفّ سليم يُقرأ بالدين والمدفوع', () {
      final preview = parseCredits(
        [
          ['الزبون', 'الدين', 'المسدَّد'],
          ['فاطمة', '12000', '4000'],
        ],
        existingByName: const {},
      );

      expect(preview.createCount, 1);
      final account = preview.rows.single.account!;
      expect(account.customerName, 'فاطمة');
      expect(account.totalDebt, 12000);
      expect(account.totalPaid, 4000);
    });

    test('الفاصلة العشرية العربية ٫ تُقرأ كفاصلة', () {
      // ملفات المحلّ تُكتب بلوحة مفاتيح عربية، و«1500٫50» ليست نصّاً
      // خاطئاً بل رقماً بفاصلة عربية.
      final preview = parseCredits(
        [
          ['الاسم', 'الدين'],
          ['خديجة', '1500٫50'],
        ],
        existingByName: const {},
      );

      expect(preview.errorCount, 0);
      expect(preview.rows.single.account!.totalDebt, 1500.5);
    });

    test('🔒 دين ليس رقماً ⇒ خطأ عربي يذكر الصف والقيمة', () {
      // الرسالة الغامضة هنا تعني أن صاحب المحل لن يعرف أي صف يصحّح
      // في ملف فيه مئة زبونة.
      final preview = parseCredits(
        [
          ['الاسم', 'الدين'],
          ['نادية', 'لاحقاً'],
        ],
        existingByName: const {},
      );

      expect(preview.errorCount, 1);
      expect(preview.rows.single.error, contains('2'));
      expect(preview.rows.single.error, contains('لاحقاً'));
    });

    test('🔒 دين سالب مرفوض — لا يُقلب إلى رصيد للزبونة', () {
      final preview = parseCredits(
        [
          ['الاسم', 'الدين'],
          ['سعاد', '-500'],
        ],
        existingByName: const {},
      );

      expect(preview.errorCount, 1);
      expect(preview.createCount, 0);
    });

    test('حساب موجود يُحدَّث بمعرّفه لا يُنشأ ثانيةً', () {
      const existing = CreditAccount(id: 'c1', customerName: 'فاطمة');
      final preview = parseCredits(
        [
          ['الاسم', 'الدين'],
          ['فاطمة', '3000'],
        ],
        existingByName: {normalizeForSearch('فاطمة'): existing},
      );

      expect(preview.updateCount, 1);
      expect(preview.rows.single.existingId, 'c1');
    });
  });
}
