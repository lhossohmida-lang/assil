import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/utils/formatters.dart';
import '../../../../core/i18n/app_strings.dart';

enum UserRole { admin, employee }

enum SalaryType { daily, monthly }

extension SalaryTypeLabel on SalaryType {
  String get label => this == SalaryType.daily ? tr('يومي') : tr('شهري');
}

/// مستخدم التطبيق: صاحب المحل (admin) أو عامل (employee).
///
/// `allowedScreens` قائمة مسارات (`/pos`, `/inventory` ...) تُطابق `AppRoutes`.
/// الأدمن يرى كل شيء بغضّ النظر عن محتواها.
class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;
  final List<String> allowedScreens;
  final double salary;
  final SalaryType salaryType;

  /// مجموع ما سحبه العامل من الصندوق (يُزاد آلياً مع كل سحب مربوط به).
  final double withdrawnAmount;
  final String storeId;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.storeId,
    this.allowedScreens = const [],
    this.salary = 0,
    this.salaryType = SalaryType.monthly,
    this.withdrawnAmount = 0,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  /// هل يُسمح لهذا المستخدم بفتح هذه الشاشة؟ الأدمن دائماً نعم.
  bool canAccess(String route) =>
      isAdmin || allowedScreens.contains(route);

  factory AppUser.fromMap(String uid, Map<String, dynamic> m, String storeId) {
    return AppUser(
      uid: uid,
      email: (m['email'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      role: (m['role'] ?? 'employee') == 'admin'
          ? UserRole.admin
          : UserRole.employee,
      storeId: (m['storeId'] ?? storeId) as String,
      allowedScreens:
          ((m['allowedScreens'] ?? const []) as List).cast<String>(),
      salary: toDouble(m['salary']),
      salaryType:
          (m['salaryType'] ?? 'monthly') == 'daily'
              ? SalaryType.daily
              : SalaryType.monthly,
      withdrawnAmount: toDouble(m['withdrawnAmount']),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'name': name,
        'role': role == UserRole.admin ? 'admin' : 'employee',
        'allowedScreens': allowedScreens,
        'salary': salary,
        'salaryType': salaryType == SalaryType.daily ? 'daily' : 'monthly',
        'withdrawnAmount': withdrawnAmount,
        'storeId': storeId,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
      };

  AppUser copyWith({
    String? name,
    List<String>? allowedScreens,
    double? salary,
    SalaryType? salaryType,
    double? withdrawnAmount,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        name: name ?? this.name,
        role: role,
        storeId: storeId,
        allowedScreens: allowedScreens ?? this.allowedScreens,
        salary: salary ?? this.salary,
        salaryType: salaryType ?? this.salaryType,
        withdrawnAmount: withdrawnAmount ?? this.withdrawnAmount,
        createdAt: createdAt,
      );
}

/// الشاشات التي يمكن منحها لعامل، بأسمائها المترجَمة (لواجهة الصلاحيات).
///
/// ⚠️ **getter لا `final`**. المتغيّر `final` على مستوى الملف يُقيَّم مرّة
/// واحدة عند أول استعمال ولا يُعاد أبداً، فكانت هذه الأسماء تتجمّد عند
/// لغة الإقلاع: يبدّل المستخدم اللغة فتتغيّر الشاشات ويبقى عنوانها كما
/// كان. الـ getter يُعيد بناء الخريطة عند كل قراءة فتتبع اللغة الحالية.
/// (13 مدخلاً — الكلفة لا تُذكر أمام واجهة لا تُقرأ إلا في الإعدادات.)
Map<String, String> get grantableScreens => {
  AppRoutes.pos: tr('نقطة البيع'),
  AppRoutes.inventory: tr('المخزون'),
  AppRoutes.reports: tr('التقارير (لاروسات)'),
  AppRoutes.capital: tr('رأس المال والزكاة'),
  AppRoutes.credits: tr('الكريديات'),
  AppRoutes.reservations: tr('الفارسمون (الحجوزات)'),
  AppRoutes.customers: tr('الزبائن'),
  AppRoutes.suppliers: tr('الموردون'),
  AppRoutes.purchases: tr('المشتريات'),
  AppRoutes.expenses: tr('المصاريف'),
  AppRoutes.orders: tr('الطلبات'),
  AppRoutes.employees: tr('العمال'),
  AppRoutes.settings: tr('الإعدادات'),
};
