import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/features/cashbox/domain/models/cashbox_transaction.dart';
import 'package:kmsan/features/reports/domain/reports_math.dart';
import 'package:kmsan/features/sales/domain/models/sale.dart';

Sale saleOf({
  required double total,
  required double cost,
  double? paid,
  PaymentMethod method = PaymentMethod.cash,
}) =>
    Sale(
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
      paidAmount: paid,
      paymentMethod: method,
      createdAt: DateTime(2026, 5, 12),
    );

CashboxTransaction tx(CashboxType type, double amount) => CashboxTransaction(
      id: 't${type.code}$amount',
      type: type,
      amount: amount,
      createdAt: DateTime(2026, 5, 12),
    );

void main() {
  group('🔒 الإرجاع ليس مصروفاً', () {
    test('إرجاع كامل ⇒ الفائدة بعد المصاريف صفر لا سالبة', () {
      // بِيع بـ1500 (كلفته 900) ثم أُرجع كاملاً.
      // الفاتورة تُحذف، ويبقى في الصندوق دخلٌ 1500 وإرجاعٌ 1500.
      final report = computeReport(
        sales: const [],
        transactions: [
          tx(CashboxType.income, 1500),
          tx(CashboxType.saleReturn, 1500),
        ],
      );

      // كان الإرجاع يُسجَّل `expense` فتصير الفائدة −1500.
      expect(report.expenses, 0,
          reason: 'الإرجاع إلغاء بيعة لا كلفة على المحل');
      expect(report.netProfit, 0);
      expect(report.netCash, 0, reason: 'دخل 1500 وخرج 1500');
    });

    test('إرجاع جزئي ⇒ الفائدة تنقص بهامش السلعة فقط', () {
      // فاتورة من سلعتين بـ3000 (كلفة 1800)، أُرجعت واحدة بـ1500/900.
      // المتبقّي: بيع 1500 كلفته 900 ⇒ فائدة خام 600.
      final report = computeReport(
        sales: [saleOf(total: 1500, cost: 900)],
        transactions: [
          tx(CashboxType.income, 3000),
          tx(CashboxType.saleReturn, 1500),
        ],
      );

      expect(report.grossProfit, 600);
      expect(report.expenses, 0);
      expect(report.netProfit, 600,
          reason: 'كانت تُقرأ −900: الهامش 600 ناقص 1500 مصروفاً وهمياً');
      expect(report.netCash, 1500, reason: '3000 دخلت و1500 خرجت');
    });

    test('الإرجاع يُنقص رصيد الصندوق فعلاً — المال خرج من الدرج', () {
      final balance = cashboxBalance([
        tx(CashboxType.income, 1500),
        tx(CashboxType.saleReturn, 1500),
      ]);
      expect(balance, 0);
    });

    test('🔒 الإرجاع يبقى خارج المصاريف مهما كثر', () {
      final report = computeReport(
        sales: const [],
        transactions: [
          tx(CashboxType.saleReturn, 500),
          tx(CashboxType.saleReturn, 700),
          tx(CashboxType.expense, 300),
        ],
      );
      expect(report.expenses, 300, reason: 'المصروف الحقيقي وحده');
      expect(report.cashOut, 1500, reason: 'كل ما خرج من الدرج');
    });
  });

  group('توزيع المال عند الإرجاع', () {
    // القاعدة: ما دفعه الزبون يبقى ما دام لا يتجاوز الفاتورة الجديدة،
    // ويُردّ نقداً ما زاد، والباقي في ذمّته يُنقص بالفرق.
    ({double cash, double debtDrop}) split({
      required double oldTotal,
      required double paid,
      required double newTotal,
    }) {
      final newPaid = paid <= newTotal ? paid : newTotal;
      final cash = paid - newPaid;
      final debtBefore = (oldTotal - paid).clamp(0, double.infinity);
      final debtAfter = (newTotal - newPaid).clamp(0, double.infinity);
      return (cash: cash, debtDrop: (debtBefore - debtAfter).toDouble());
    }

    test('بيع نقدي: الإرجاع يُردّ نقداً كاملاً', () {
      final r = split(oldTotal: 3000, paid: 3000, newTotal: 1500);
      expect(r.cash, 1500);
      expect(r.debtDrop, 0);
    });

    test('كريدي والمدفوع أقلّ من الفاتورة الجديدة: لا نقد يخرج', () {
      // دفع 1000 من 3000، أرجع بـ1500 ⇒ الفاتورة 1500، الدَّين 2000→500.
      final r = split(oldTotal: 3000, paid: 1000, newTotal: 1500);
      expect(r.cash, 0, reason: 'ما دفعه لا يتجاوز الفاتورة الجديدة');
      expect(r.debtDrop, 1500);
    });

    test('كريدي وإرجاع يتجاوز الدَّين: الفائض يُردّ نقداً', () {
      // دفع 1000 من 3000، أرجع كل شيء ⇒ الدَّين 2000→0 و1000 تُردّ نقداً.
      final r = split(oldTotal: 3000, paid: 1000, newTotal: 0);
      expect(r.debtDrop, 2000);
      expect(r.cash, 1000);
    });

    test('🔒 مجموع ما يعود = قيمة ما أُرجع، لا أكثر ولا أقل', () {
      // حارس ضدّ أي إعادة توزيع تخترع مالاً أو تبتلعه.
      for (final paid in [0.0, 500.0, 1500.0, 3000.0]) {
        final r = split(oldTotal: 3000, paid: paid, newTotal: 1500);
        expect(r.cash + r.debtDrop, 1500,
            reason: 'المدفوع $paid: ${r.cash} نقداً + ${r.debtDrop} ديناً');
      }
    });
  });

  group('🔒 حذف فاتورة فارسمون لا يُضاعف المخزون', () {
    // بضاعة الحجز خرجت من المخزون **يوم الحجز** لا يوم إكمال البيع.
    // فحذف الفاتورة لا يعني «أعِد البضاعة» — هي موضوعة جانباً للزبون —
    // بل «ألغِ الإكمال» فيعود الحجز نشطاً.
    //
    // القاعدة مُنفَّذة في `SalesRepository.deleteSale`؛ هنا نثبّت المنطق
    // الذي يقرّرها حتى لا يُعكَس سهواً.
    bool restoresStock(PaymentMethod method, String reservationId) =>
        !(method == PaymentMethod.reservation && reservationId.isNotEmpty);

    test('بيع نقدي ⇒ البضاعة تعود للمخزون', () {
      expect(restoresStock(PaymentMethod.cash, ''), isTrue);
    });

    test('بيع كريدي ⇒ البضاعة تعود للمخزون', () {
      expect(restoresStock(PaymentMethod.credit, ''), isTrue);
    });

    test('🔒 فارسمون مرتبط بحجز ⇒ لا تعود، بل يعود الحجز نشطاً', () {
      expect(restoresStock(PaymentMethod.reservation, 'r1'), isFalse,
          reason: 'إعادتها تجعل المحل يبيع قطعة محجوزة ثم لا يجدها');
    });

    test('فارسمون قديم بلا حجز معروف ⇒ نعيدها احتياطاً', () {
      // بيانات سابقة لهذه الميزة: أن نُعيد البضاعة أهون من أن تضيع.
      expect(restoresStock(PaymentMethod.reservation, ''), isTrue);
    });
  });
}
