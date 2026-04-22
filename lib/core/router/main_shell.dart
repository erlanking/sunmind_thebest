import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sunmind_thebest/core/widgets/bottom_nav_bar.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/analytics')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavBar(currentIndex: currentIndex),
    );
  }
}
