import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/core/theme/app_theme.dart';
import 'package:kmsan/shared/widgets/common_widgets.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('شارة البائع في السجل', () {
    testWidgets('تعرض الاسم بالبنفسجي — نصّاً وأيقونة', (tester) async {
      await tester.pumpWidget(wrap(const SellerBadge(name: 'كريم')));

      expect(find.text('كريم'), findsOneWidget);

      final text = tester.widget<Text>(find.text('كريم'));
      expect(text.style?.color, AppTheme.seller,
          reason: 'اللون المطلوب صراحةً هو البنفسجي');

      final icon = tester.widget<Icon>(find.byIcon(Icons.person));
      expect(icon.color, AppTheme.seller);
    });

    testWidgets('🔒 فاتورة قديمة بلا اسم لا تطبع شارة فارغة', (tester) async {
      // السجلّات المسجَّلة قبل حفظ اسم البائع تُرجع نصّاً فارغاً. طباعة
      // شارة فارغة في كل سطر منها تُشوّه السجل كلّه بلا فائدة.
      await tester.pumpWidget(wrap(const SellerBadge(name: '')));
      expect(find.byIcon(Icons.person), findsNothing);

      await tester.pumpWidget(wrap(const SellerBadge(name: '   ')));
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('اسم طويل يُقصّ ولا يفيض عن السطر', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 120,
          child: SellerBadge(name: 'عبد الرحمن بن محمد الأمين الطويل جداً'),
        ),
      ));
      // لو فاض النصّ لسجّل الإطار خطأ تخطيط وأسقط الاختبار.
      expect(tester.takeException(), isNull);

      final text = tester.widget<Text>(find.textContaining('عبد الرحمن'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    test('البنفسجي لا يصطدم بأي لون دلالي آخر', () {
      // 🔒 الأحمر دَين، الأخضر ربح، البرتقالي تنبيه. لو ساوى لون البائع
      // أحدها لقرأ صاحب المحل حكماً محاسبياً في مجرّد اسم.
      expect(AppTheme.seller, isNot(AppTheme.danger));
      expect(AppTheme.seller, isNot(AppTheme.warning));
      expect(AppTheme.seller, isNot(AppTheme.success));
    });
  });
}
