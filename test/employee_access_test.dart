import 'package:flutter_test/flutter_test.dart';
import 'package:kmsan/core/constants/app_constants.dart';
import 'package:kmsan/core/router/app_router.dart';
import 'package:kmsan/features/auth/domain/models/app_user.dart';

AppUser employee(List<String> screens) => AppUser(
      uid: 'e1',
      email: 'worker@shop.dz',
      name: 'كريم',
      role: UserRole.employee,
      storeId: 'store1',
      allowedScreens: screens,
    );

const admin = AppUser(
  uid: 'store1',
  email: 'owner@shop.dz',
  name: 'صاحب المحل',
  role: UserRole.admin,
  storeId: 'store1',
);

void main() {
  group('وجهة الدخول بعد المصادقة', () {
    test('عامل له نقطة البيع يُفتح عليها', () {
      final route = firstAllowedRoute(employee([AppRoutes.pos]).canAccess);
      expect(route, AppRoutes.pos);
    });

    test('عامل بلا نقطة بيع يُفتح على أول قسم يملكه', () {
      final route =
          firstAllowedRoute(employee([AppRoutes.customers]).canAccess);
      expect(route, AppRoutes.customers);
    });

    test('صاحب المحل يُفتح على نقطة البيع', () {
      expect(firstAllowedRoute(admin.canAccess), AppRoutes.pos);
    });

    test('🐞 العطب: عامل بلا أي قسم كان يُرَدّ إلى شاشة الدخول', () {
      // كان `firstAllowedRoute` يُرجع `AppRoutes.login`، فيرتدّ العامل من
      // شاشة الدخول إليها نفسها بعد نجاح مصادقته: تتوقّف الدوّارة ولا
      // يحدث شيء، بلا رسالة ولا سبب.
      final route = firstAllowedRoute(employee(const []).canAccess);

      expect(route, isNot(AppRoutes.login),
          reason: 'إرجاع شاشة الدخول يصنع ارتداداً أبدياً صامتاً');
      expect(route, AppRoutes.noAccess);
    });

    test('🔒 لا يُرجع شاشة الدخول لأي تركيبة صلاحيات', () {
      // حارس شامل: أي مجموعة أقسام — بما فيها الفارغة — يجب أن تنتهي
      // إلى شاشة يستطيع المستخدم رؤيتها، لا إلى الدخول.
      final combos = <List<String>>[
        const [],
        [AppRoutes.pos],
        [AppRoutes.settings],
        [AppRoutes.reports, AppRoutes.capital],
        grantableScreens.keys.toList(),
        const ['/route-does-not-exist'],
      ];
      for (final combo in combos) {
        expect(firstAllowedRoute(employee(combo).canAccess),
            isNot(AppRoutes.login),
            reason: 'التركيبة $combo تنتهي إلى شاشة الدخول');
      }
    });

    test('كل قسم قابل للمنح موجود في قائمة الأولوية', () {
      // 🔒 لو مُنح عامل قسماً غائباً عن قائمة الأولوية لعاد إلى
      // «بلا صلاحيات» رغم أنه يملك قسماً فعلاً.
      for (final screen in grantableScreens.keys) {
        expect(firstAllowedRoute(employee([screen]).canAccess), screen,
            reason: 'القسم $screen ليس في قائمة الأولوية');
      }
    });
  });

  group('صلاحية فتح الأقسام', () {
    test('الأدمن يفتح كل شيء بلا قائمة', () {
      for (final screen in grantableScreens.keys) {
        expect(admin.canAccess(screen), isTrue);
      }
    });

    test('العامل يفتح ما مُنح له فقط', () {
      final worker = employee([AppRoutes.pos, AppRoutes.inventory]);
      expect(worker.canAccess(AppRoutes.pos), isTrue);
      expect(worker.canAccess(AppRoutes.inventory), isTrue);
      expect(worker.canAccess(AppRoutes.reports), isFalse);
      expect(worker.canAccess(AppRoutes.settings), isFalse);
    });
  });
}
