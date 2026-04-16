import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdaptiveShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const AdaptiveShell({
    super.key,
    required this.child,
    required this.state,
  });

  static const _tabs = [
    (route: '/dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: '仪表盘'),
    (route: '/navigation', icon: Icons.map_outlined, activeIcon: Icons.map, label: '导航'),
    (route: '/mapping', icon: Icons.layers_outlined, activeIcon: Icons.layers, label: '建图'),
    (route: '/logs', icon: Icons.article_outlined, activeIcon: Icons.article, label: '日志'),
    (route: '/settings', icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '设置'),
  ];

  int _selectedIndex(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = state.matchedLocation;
    final selectedIndex = _selectedIndex(location);
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.selected,
              onDestinationSelected: (i) =>
                  context.go(_tabs[i].route),
              destinations: _tabs
                  .map((t) => NavigationRailDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.activeIcon),
                        label: Text(t.label),
                      ))
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].route),
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.activeIcon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}
