import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/core/i18n/app_strings.dart';
import 'package:kmsan/core/constants/app_constants.dart';
import 'package:kmsan/core/router/app_router.dart';
import 'package:kmsan/features/auth/domain/models/app_user.dart';

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

  group('🔒 جداول النصوص لا تتجمّد عند لغة الإقلاع', () {
    // ⚠️ عطب نجا من الإصلاح الأول: `KeyedSubtree` جعل الشاشات تُعاد
    // بناءها، لكن عناوين الأقسام كانت في خرائط `final` على مستوى الملف.
    // و`final` في Dart يُقيَّم **مرّة واحدة عند أول استعمال ولا يُعاد**،
    // فتجمّدت العناوين عند لغة أول تشغيل: تتبدّل الشاشات ويبقى عنوانها.

    test('عناوين الأقسام تتبع اللغة الحالية', () {
      AppLocaleState.code = 'ar';
      final ar = protectedSections[AppRoutes.inventory]!.title();
      expect(ar, 'المخزون');

      AppLocaleState.code = 'fr';
      final fr = protectedSections[AppRoutes.inventory]!.title();
      expect(fr, 'Stock');

      AppLocaleState.code = 'ar';
      expect(protectedSections[AppRoutes.inventory]!.title(), 'المخزون',
          reason: 'العودة إلى العربية يجب أن تعمل أيضاً');
    });

    test('أسماء الأقسام في واجهة الصلاحيات تتبع اللغة', () {
      AppLocaleState.code = 'ar';
      expect(grantableScreens[AppRoutes.inventory], 'المخزون');

      AppLocaleState.code = 'fr';
      expect(grantableScreens[AppRoutes.inventory], 'Stock');

      AppLocaleState.code = 'ar';
      expect(grantableScreens[AppRoutes.inventory], 'المخزون');
    });

    test('🔒 كل عناوين الأقسام تتبدّل فعلاً بين اللغتين', () {
      // حارس شامل: لو تجمّد عنوان واحد لسقط الاختبار باسمه.
      AppLocaleState.code = 'ar';
      final arabic = {
        for (final e in protectedSections.entries) e.key: e.value.title(),
      };

      AppLocaleState.code = 'fr';
      for (final entry in protectedSections.entries) {
        final french = entry.value.title();
        // النصّ الوحيد الذي يجوز تطابقه هو ما لا ترجمة له (اسم علم).
        if (french == arabic[entry.key]) {
          fail('عنوان ${entry.key} لم يتبدّل: ${arabic[entry.key]}');
        }
      }
    });
  });

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
