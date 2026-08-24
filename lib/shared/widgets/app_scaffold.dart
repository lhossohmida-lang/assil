import 'package:flutter/material.dart';

import 'app_navigation_drawer.dart';

/// هيكل موحّد لكل الشاشات: شريط علوي + القائمة الجانبية نفسها في كل مكان.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.route,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.titleWidget,
  });

  final String route;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: titleWidget ?? Text(title),
        actions: actions,
      ),
      drawer: AppNavigationDrawer(currentRoute: route),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
