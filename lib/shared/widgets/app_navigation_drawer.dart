import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/orders/presentation/providers/orders_providers.dart';
import '../../core/i18n/app_strings.dart';

class _DrawerEntry {
  const _DrawerEntry(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}

/// القائمة الجانبية الموحّدة — الشاشة الوحيدة التي تعرف ترتيب الأقسام.
class AppNavigationDrawer extends ConsumerWidget {
  const AppNavigationDrawer({super.key, required this.currentRoute});

  final String currentRoute;

  static final List<_DrawerEntry> _entries = [
    _DrawerEntry(AppRoutes.pos, tr('نقطة البيع'), Icons.point_of_sale),
    _DrawerEntry(AppRoutes.inventory, tr('المخزون'), Icons.inventory_2),
    _DrawerEntry(AppRoutes.reports, tr('التقارير (لاروسات)'), Icons.bar_chart),
    _DrawerEntry(AppRoutes.capital, tr('رأس المال والزكاة'), Icons.account_balance),
    _DrawerEntry(AppRoutes.credits, tr('الكريديات'), Icons.credit_score),
    _DrawerEntry(AppRoutes.reservations, tr('الفارسمون'), Icons.bookmark_added),
    // مدخل الزبائن معلّق بطلب صاحب المحل — أزل التعليق لتفعيله.
    // _DrawerEntry(AppRoutes.customers, 'الزبائن', Icons.people),
    _DrawerEntry(AppRoutes.suppliers, tr('الموردون'), Icons.local_shipping),
    _DrawerEntry(AppRoutes.purchases, tr('المشتريات'), Icons.shopping_cart_checkout),
    _DrawerEntry(AppRoutes.expenses, tr('المصاريف'), Icons.receipt_long),
    _DrawerEntry(AppRoutes.employees, tr('العمال'), Icons.badge),
    _DrawerEntry(AppRoutes.settings, tr('الإعدادات'), Icons.settings),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pendingOrders = ref.watch(pendingOrdersCountProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            _Header(name: user?.name ?? '', email: user?.email ?? ''),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final e in _entries)
                    if (user?.canAccess(e.route) ?? false)
                      _Tile(
                        entry: e,
                        selected: currentRoute == e.route,
                        badgeCount: 0,
                      ),
                  if (user?.canAccess(AppRoutes.orders) ?? false)
                    _Tile(
                      entry: _DrawerEntry(
                          AppRoutes.orders, tr('الطلبات'), Icons.shopping_bag),
                      selected: currentRoute == AppRoutes.orders,
                      badgeCount: pendingOrders,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.danger),
              title: Text(tr('تسجيل الخروج'),
                  style: TextStyle(color: AppTheme.danger)),
              onTap: () async {
                final navigator = Navigator.of(context);
                await ref.read(authRepositoryProvider).signOut();
                if (navigator.canPop()) navigator.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppConstants.storeDisplayName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            email,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.entry,
    required this.selected,
    required this.badgeCount,
  });

  final _DrawerEntry entry;
  final bool selected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(entry.icon,
          color: selected ? AppTheme.primary : AppTheme.textSecondary),
      title: Text(
        entry.label,
        style: TextStyle(
          color: selected ? AppTheme.primary : AppTheme.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.danger,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
      selected: selected,
      selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
      onTap: () {
        Navigator.of(context).pop();
        if (!selected) context.go(entry.route);
      },
    );
  }
}
