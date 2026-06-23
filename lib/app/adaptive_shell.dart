import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../shared/widgets/console_widgets.dart';
import 'theme.dart';

class AdaptiveShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const AdaptiveShell({super.key, required this.child, required this.state});

  static const _tabs = [
    (
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: '仪表盘',
    ),
    (
      route: '/navigation',
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: '导航',
    ),
    (
      route: '/mapping',
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers,
      label: '建图',
    ),
    (
      route: '/logs',
      icon: Icons.article_outlined,
      activeIcon: Icons.article,
      label: '日志',
    ),
    (
      route: '/settings',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: '设置',
    ),
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
      return ConsoleScaffold(
        body: Row(
          children: [
            NavigationRail(
              minWidth: 72,
              groupAlignment: -0.76,
              selectedIndex: selectedIndex,
              labelType: NavigationRailLabelType.selected,
              onDestinationSelected: (i) => context.go(_tabs[i].route),
              leading: Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 24),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.14),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.46),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.hub_outlined,
                    color: AppTheme.primaryColor,
                    size: 21,
                  ),
                ),
              ),
              destinations: _tabs
                  .map(
                    (t) => NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.activeIcon),
                      label: Text(t.label),
                    ),
                  )
                  .toList(),
            ),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: AppTheme.borderColor(context),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return ConsoleScaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor(context)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: (i) => context.go(_tabs[i].route),
                destinations: _tabs
                    .map(
                      (t) => NavigationDestination(
                        icon: Icon(t.icon),
                        selectedIcon: Icon(t.activeIcon),
                        label: t.label,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
