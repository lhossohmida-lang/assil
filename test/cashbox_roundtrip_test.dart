import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/cashbox/domain/models/cashbox_transaction.dart';
import 'package:kmsan/features/reports/domain/reports_math.dart';
import 'package:kmsan/features/sales/domain/models/sale.dart';

/// يحاكي رحلة الحركة الكاملة: كائن ⇒ خريطة ⇒ Firestore ⇒ كائن.
///
/// `createdAt` يُستبعد لأن `toMap` يكتب فيه `FieldValue.serverTimestamp()`
/// وهو رمزٌ يستبدله الخادم بوقته، فلا يوجد خارج Firestore. ما نختبره هنا
/// هو ترميز **النوع** لا الوقت.
CashboxTransaction roundTrip(CashboxTransaction tx) {
  final map = Map<String, dynamic>.from(tx.toMap())..remove('createdAt');
  return CashboxTransaction.fromMap(tx.id, map);
}

void main() {
  group('🔒 ترميز أنواع حركات الصندوق ذهاباً وإياباً', () {
    // ⚠️ هذا الاختبار موجود لأن عطباً حقيقياً نجا من إصلاحه:
    // أُضيف `saleReturn` إلى التعداد والكاتب والتقارير ونُسي في
    // `parseType`، فكانت الحركة تُكتب `saleReturn` وتُقرأ `expense`.
    // والاختبارات القديمة بنت الكائن بالـ enum مباشرةً فتخطّت القارئ
    // ومرّت خضراء بينما التطبيق معطوب.

    test('كل نوع يعود كما ذهب — بلا استثناء', () {
      for (final type in CashboxType.values) {
        final original = CashboxTransaction(
          id: 'x',
          type: type,
          amount: 100,
          note: 'اختبار',
        );
        expect(roundTrip(original).type, type,
            reason: 'النوع ${type.code} لا يعود كما كُتب — انظر parseType');
      }
    });

    test('كل رمز نوع فريد — لا يبتلع نوعٌ آخرَ', () {
      final codes = CashboxType.values.map((t) => t.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('رمز مجهول يسقط إلى «مصروف» — توافق مع البيانات القديمة', () {
      expect(CashboxTransaction.parseType('حركة-من-نسخة-قادمة'),
          CashboxType.expense);
      expect(CashboxTransaction.parseType(null), CashboxType.expense);
    });
  });

  group('🔒 الإرجاع في التقارير — بعد المرور بالترميز', () {
    // الكلفة مشتقّة من السطور، فنبني سطراً واحداً بالقيم المطلوبة.
    Sale saleOf(double total, double cost) => Sale(
          id: 's1',
          items: [
            SaleItem(
              productId: 'p1',
              name: 'قميص',
              quantity: 1,
              unitPrice: total,
              purchasePrice: cost,
            ),
          ],
          subtotal: total,
          total: total,
          createdAt: DateTime(2026, 5, 1),
        );

    test('إرجاع لا يُنقص «الفائدة بعد المصاريف»', () {
      // بيعة 3000 كلفتها 1800، ثم أُرجعت سلعة بـ1500 نقداً.
      // الفاتورة نقصت إلى 1500 وكلفتها إلى 900 ⇒ الفائدة الخام 600.
      // الإرجاع نقدٌ خرج، **لا مصروف** ⇒ الفائدة بعد المصاريف تبقى 600.
      final returnTx = roundTrip(CashboxTransaction(
        id: 'r',
        type: CashboxType.saleReturn,
        amount: 1500,
        note: 'إرجاع قميص × 1 من KM-1',
      ));
      final saleTx = roundTrip(CashboxTransaction(
        id: 'i',
        type: CashboxType.income,
        amount: 3000,
        note: 'بيع KM-1',
      ));

      final report = computeReport(
        sales: [saleOf(1500, 900)],
        transactions: [saleTx, returnTx],
      );

      expect(report.expenses, 0,
          reason: 'الإرجاع ليس مصروفاً — الفاتورة نقصت أصلاً');
      expect(report.grossProfit, 600);
      expect(report.netProfit, 600);
    });

    test('لكنه يُنقص صافي النقد ورصيد الصندوق', () {
      final saleTx = roundTrip(CashboxTransaction(
        id: 'i',
        type: CashboxType.income,
        amount: 3000,
        note: 'بيع',
      ));
      final returnTx = roundTrip(CashboxTransaction(
        id: 'r',
        type: CashboxType.saleReturn,
        amount: 1500,
        note: 'إرجاع',
      ));

      final report =
          computeReport(sales: [saleOf(1500, 900)], transactions: [saleTx, returnTx]);

      expect(report.cashOut, 1500, reason: 'المال خرج من الدرج فعلاً');
      expect(report.netCash, 1500);
      expect(cashboxBalance([saleTx, returnTx]), 1500);
    });

    test('🔒 إرجاع قديم مسجَّل «مصروفاً» يُصحَّح بأثر رجعي', () {
      // بيانات المحل من قبل هذه النسخة نوعها `expense`. نتعرّف عليها
      // بملاحظتها فتُصحَّح تقارير الأشهر الماضية بلا تعديل بياناتها.
      final legacy = CashboxTransaction.fromMap('r', {
        'type': 'expense',
        'amount': 1500,
        'note': 'إرجاع قميص × 1 من KM-2026-004',
      });

      expect(legacy.isSaleReturn, isTrue);
      expect(legacy.isRealExpense, isFalse);

      final report = computeReport(
        sales: [saleOf(1500, 900)],
        transactions: [legacy],
      );
      expect(report.expenses, 0);
      expect(report.netProfit, 600, reason: 'لا −900 كما كان');
      expect(report.cashOut, 1500, reason: 'المال خرج فعلاً');
    });

    test('🔒 مصروف حقيقي يبقى مصروفاً — الكاشف لا يبتلع كل شيء', () {
      final electricity = CashboxTransaction.fromMap('e', {
        'type': 'expense',
        'amount': 2000,
        'note': 'فاتورة الكهرباء',
      });
      expect(electricity.isSaleReturn, isFalse);
      expect(electricity.isRealExpense, isTrue);

      final report = computeReport(
        sales: [saleOf(1500, 900)],
        transactions: [electricity],
      );
      expect(report.expenses, 2000);
      expect(report.netProfit, -1400);
    });
  });
}
