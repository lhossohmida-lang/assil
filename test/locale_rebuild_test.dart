import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/core/i18n/app_strings.dart';

/// شاشة تُسجَّل في الراوتر نسخةً `const` — تماماً كشاشات التطبيق.
///
/// `labelText` يمثّل «اسم الخانة» الثابت، و[counter] يمثّل المحتوى الآتي
/// من مزوّد يُعيد البناء وحده.
class _ConstScreen extends StatelessWidget {
  const _ConstScreen();

  @override
  Widget build(BuildContext context) => Text(tr('نقطة البيع'));
}

/// يحاكي `MaterialApp.builder` في `main.dart`.
class _Host extends StatefulWidget {
  const _Host({required this.keyed});

  /// هل نلفّ الشجرة بمفتاح مرتبط باللغة (الإصلاح) أم لا (السلوك القديم)؟
  final bool keyed;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String language = 'ar';

  void switchTo(String code) => setState(() {
        language = code;
        AppLocaleState.code = code;
      });

  @override
  Widget build(BuildContext context) {
    // نفس ترتيب main.dart: تثبيت اللغة ثم بناء الشجرة.
    AppLocaleState.code = language;
    const screen = _ConstScreen();
    return MaterialApp(
      home: Scaffold(
        body: widget.keyed
            ? KeyedSubtree(key: ValueKey(language), child: screen)
            : screen,
      ),
    );
  }
}

void main() {
  tearDown(() => AppLocaleState.code = 'ar');

  group('تبديل اللغة يُعيد بناء الشاشات', () {
    testWidgets('🐞 إعادة إنتاج العطب: بلا مفتاح تبقى العناوين بالعربية',
        (tester) async {
      // هذا الاختبار يوثّق **سبب** العطب لا يحرس سلوكاً مرغوباً:
      // Flutter يتخطّى إعادة بناء widget نسخته متطابقة مع السابقة،
      // و`const _ConstScreen()` نسخة واحدة أبداً.
      await tester.pumpWidget(const _Host(keyed: false));
      expect(find.text('نقطة البيع'), findsOneWidget);

      tester.state<_HostState>(find.byType(_Host)).switchTo('fr');
      await tester.pumpAndSettle();

      expect(find.text('Point de vente'), findsNothing,
          reason: 'هكذا كان العطب: اللغة تبدّلت والعنوان لم يتبدّل');
      expect(find.text('نقطة البيع'), findsOneWidget);
    });

    testWidgets('✅ مع المفتاح المرتبط باللغة تُترجم العناوين فوراً',
        (tester) async {
      await tester.pumpWidget(const _Host(keyed: true));
      expect(find.text('نقطة البيع'), findsOneWidget);

      tester.state<_HostState>(find.byType(_Host)).switchTo('fr');
      await tester.pumpAndSettle();

      expect(find.text('Point de vente'), findsOneWidget);
      expect(find.text('نقطة البيع'), findsNothing);
    });

    testWidgets('والعودة إلى العربية تعمل أيضاً', (tester) async {
      await tester.pumpWidget(const _Host(keyed: true));
      final host = tester.state<_HostState>(find.byType(_Host));

      host.switchTo('fr');
      await tester.pumpAndSettle();
      expect(find.text('Point de vente'), findsOneWidget);

      host.switchTo('ar');
      await tester.pumpAndSettle();
      expect(find.text('نقطة البيع'), findsOneWidget);
    });
  });
}
