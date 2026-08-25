import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/models/app_user.dart';
import '../../features/auth/data/auth_repository.dart' show arabicAuthError;
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/no_access_screen.dart';
import '../../features/capital/presentation/screens/capital_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/inventory/presentation/screens/inventory_screen.dart';
import '../../features/cashbox/presentation/screens/expenses_screen.dart';
import '../../features/employees/presentation/screens/employees_screen.dart';
import '../../features/import_products/domain/import_kinds.dart';
import '../../features/import_products/presentation/screens/import_products_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/pos/presentation/screens/credits_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/pos/presentation/screens/reservations_screen.dart';
import '../../features/reports/presentation/screens/ledger_search_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/suppliers/presentation/screens/purchases_screen.dart';
import '../../features/suppliers/presentation/screens/suppliers_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/widgets/pin_gate.dart';
import '../constants/app_constants.dart';
import '../i18n/app_strings.dart';

/// شاشة الانتظار أثناء حلّ الجلسة (قراءة user_store_map ثم مستند المستخدم).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

/// جسر بين Riverpod و go_router: كل تغيّر في الجلسة يُعيد تقييم الـ redirect.
///
/// نستعمل `ref.listen` لا `ref.watch` عمداً — `watch` يُعيد بناء الـ GoRouter
/// كاملاً فيفقد تاريخ التنقّل ويُعيد المستخدم للبداية عند كل تحديث صلاحيات.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.pos,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (session.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      // ⚠️ حالة الخطأ ليست «غير مسجَّل دخوله».
      //
      // كانت تُعامَل كذلك فيُرمى المستخدم إلى شاشة الدخول بلا كلمة، فيظنّ
      // كلمة مروره خاطئة ويعيدها مراراً بينما السبب شبكة أو صلاحية.
      if (session.hasError) {
        return loc == AppRoutes.sessionError ? null : AppRoutes.sessionError;
      }

      final value = session.value;
      if (value == null) {
        return loc == AppRoutes.login ? null : AppRoutes.login;
      }

      final landing = firstAllowedRoute(value.appUser.canAccess);

      // مسجَّل دخوله: لا يبقى في شاشة الدخول ولا في الانتظار ولا في
      // شاشة الخطأ بعد أن زال الخطأ.
      if (loc == AppRoutes.login ||
          loc == '/splash' ||
          loc == AppRoutes.sessionError) {
        return landing;
      }

      // بلا أي صلاحية: يبقى في شاشة التوضيح ولا يُرتَدّ إلى الدخول.
      if (landing == AppRoutes.noAccess) {
        return loc == AppRoutes.noAccess ? null : AppRoutes.noAccess;
      }

      // صار له صلاحية وهو في شاشة «بلا صلاحيات» ⇒ ينتقل تلقائياً.
      if (loc == AppRoutes.noAccess) return landing;

      // منع فتح قسم غير مسموح (بكتابة المسار يدوياً مثلاً).
      if (grantableScreens.containsKey(loc) && !value.appUser.canAccess(loc)) {
        return landing;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.noAccess,
        builder: (_, _) => const NoAccessScreen(),
      ),
      GoRoute(
        path: AppRoutes.sessionError,
        builder: (context, state) {
          final error = ref.read(sessionProvider).error;
          return SessionErrorScreen(
            message: error == null ? tr('خطأ غير معروف') : arabicAuthError(error),
          );
        },
      ),

      // نقطة البيع — **القسم الوحيد بلا رقم سرّي**: البائع يبيع دون أن
      // يعرف الرقم، وكل ما عداها مقفل.
      GoRoute(path: AppRoutes.pos, builder: (_, _) => const PosScreen()),

      // بقيّة الأقسام تُلَفّ آلياً بـ PinGate — لا استثناء ولا نسيان:
      // إضافة قسم جديد إلى الجدول تعني أنه محميّ تلقائياً.
      for (final entry in protectedSections.entries)
        GoRoute(
          path: entry.key,
          builder: (_, _) => PinGate(
            section: entry.value.section,
            title: entry.value.title(),
            child: entry.value.build(),
          ),
        ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text(trf('صفحة غير موجودة: {0}', [state.uri]))),
    ),
  );
});

/// أول قسم مسموح للمستخدم — لا نرمي عاملاً بلا صلاحية «نقطة البيع» في شاشة
/// يراها فارغة، بل نفتح له أول ما يملكه.
///
/// 🔒 **ممنوع منعاً باتاً أن يُرجع `AppRoutes.login`.** كان يفعل حين لا
/// يملك المستخدم أي قسم، فيرتدّ العامل من شاشة الدخول إليها نفسها بعد
/// نجاح مصادقته: تتوقّف الدوّارة ولا يحدث شيء، بلا رسالة ولا سبب. من
/// أسوأ الأعطال لأنه صامت تماماً — لا العامل يفهم ولا صاحب المحل.
String firstAllowedRoute(bool Function(String) canAccess) {
  for (final route in _priority) {
    if (canAccess(route)) return route;
  }
  return AppRoutes.noAccess;
}

/// ترتيب أولوية فتح الأقسام (نقطة البيع أولاً).
const List<String> _priority = [
  AppRoutes.pos,
  AppRoutes.inventory,
  AppRoutes.reports,
  AppRoutes.orders,
  AppRoutes.credits,
  AppRoutes.reservations,
  AppRoutes.expenses,
  AppRoutes.suppliers,
  AppRoutes.purchases,
  AppRoutes.capital,
  AppRoutes.employees,
  AppRoutes.customers,
  AppRoutes.settings,
];



/// وصف قسم محميّ.
class ProtectedSection {
  const ProtectedSection(this.section, this.title, this.build);

  /// مفتاح الفتح في هذه الجلسة — أقسام تتشارك المفتاح تُفتح معاً.
  final String section;

  /// عنوان القسم **دالةً لا نصّاً**: تُستدعى وقت بناء الشاشة فتتبع اللغة
  /// الحالية. لو خُزّن نصّاً لتجمّد عند لحظة إنشاء الموجّه (بدء التطبيق)
  /// فبقي بلغة الإقلاع مهما بدّل المستخدم لغته.
  final String Function() title;

  final Widget Function() build;
}

/// كل الأقسام ما عدا نقطة البيع.
///
/// ⚠️ الرقم السرّي يقفل **كل شيء إلا البيع**: العامل يبيع ولا يرى المخزون
/// ولا الأرباح ولا الموردين ولا الإعدادات حتى يُعطيه صاحب المحل الرقم.
/// ⚠️ **getter لا `final`** — انظر [grantableScreens]: خريطة `final`
/// تُقيَّم مرّة واحدة فتتجمّد عناوينها عند لغة الإقلاع.
Map<String, ProtectedSection> get protectedSections => {
  AppRoutes.inventory:
      ProtectedSection('inventory', () => tr('المخزون'), InventoryScreen.new),
  // كل باب استيراد يحمل مفتاح قسمه: من فتح «الموردين» بالرقم السرّي
  // يستورد موردين بلا أن يُطلب منه الرقم ثانيةً.
  AppRoutes.importProducts: ProtectedSection(
      'inventory', () => tr('استيراد منتجات'), ImportProductsScreen.new),
  AppRoutes.importSuppliers: ProtectedSection(
      'suppliers',
      () => tr('استيراد موردين'),
      () => const ImportProductsScreen(initialKind: ImportKind.suppliers)),
  AppRoutes.importCredits: ProtectedSection(
      'credits',
      () => tr('استيراد كريديات'),
      () => const ImportProductsScreen(initialKind: ImportKind.credits)),
  AppRoutes.reports: ProtectedSection('reports', () => tr('التقارير'), ReportsScreen.new),
  AppRoutes.ledgerSearch:
      ProtectedSection('reports', () => tr('بحث في السجل'), LedgerSearchScreen.new),
  AppRoutes.capital:
      ProtectedSection('capital', () => tr('رأس المال والزكاة'), CapitalScreen.new),
  AppRoutes.credits: ProtectedSection('credits', () => tr('الكريديات'), CreditsScreen.new),
  AppRoutes.reservations:
      ProtectedSection('reservations', () => tr('الفارسمون'), ReservationsScreen.new),
  AppRoutes.customers:
      ProtectedSection('customers', () => tr('الزبائن'), CustomersScreen.new),
  AppRoutes.suppliers:
      ProtectedSection('suppliers', () => tr('الموردون'), SuppliersScreen.new),
  AppRoutes.purchases:
      ProtectedSection('suppliers', () => tr('المشتريات'), PurchasesScreen.new),
  AppRoutes.expenses:
      ProtectedSection('expenses', () => tr('المصاريف'), ExpensesScreen.new),
  AppRoutes.employees:
      ProtectedSection('employees', () => tr('العمال'), EmployeesScreen.new),
  AppRoutes.orders: ProtectedSection('orders', () => tr('الطلبات'), OrdersScreen.new),
  AppRoutes.settings:
      ProtectedSection('settings', () => tr('الإعدادات'), SettingsScreen.new),
};
