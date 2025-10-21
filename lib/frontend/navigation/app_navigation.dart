import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class AppNavigationEntry {
  const AppNavigationEntry({
    required this.label,
    this.route,
    this.icon,
    this.selectedIcon,
    this.children = const <AppNavigationEntry>[],
    this.includeInPrimaryNavigation = false,
  }) : assert(
          route != null || children.isNotEmpty,
          'A navigation entry must define a route or children.',
        );

  final String label;
  final String? route;
  final IconData? icon;
  final IconData? selectedIcon;
  final List<AppNavigationEntry> children;
  final bool includeInPrimaryNavigation;

  bool get hasChildren => children.isNotEmpty;

  bool containsRoute(String routeName) {
    if (route == routeName) {
      return true;
    }

    for (final child in children) {
      if (child.containsRoute(routeName)) {
        return true;
      }
    }

    return false;
  }
}

final List<AppNavigationEntry> appNavigationEntries =
    List<AppNavigationEntry>.unmodifiable(<AppNavigationEntry>[
  AppNavigationEntry(
    label: 'Home',
    route: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    includeInPrimaryNavigation: true,
  ),
  AppNavigationEntry(
    label: 'Bots',
    route: '/bots',
    icon: Icons.smart_toy_outlined,
    selectedIcon: Icons.smart_toy,
    includeInPrimaryNavigation: true,
  ),
  AppNavigationEntry(
    label: 'Tutorial',
    route: '/tutorial',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    includeInPrimaryNavigation: true,
  ),
  AppNavigationEntry(
    label: 'Test',
    icon: Icons.science_outlined,
    selectedIcon: Icons.science,
    children: <AppNavigationEntry>[
      AppNavigationEntry(label: 'Test 1', route: '/test1'),
      AppNavigationEntry(label: 'Test 2', route: '/test2'),
      AppNavigationEntry(label: 'Test 3', route: '/test3'),
    ],
    includeInPrimaryNavigation: true,
  ),
  AppNavigationEntry(
    label: 'Settings',
    route: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    includeInPrimaryNavigation: true,
  ),
]);

List<AppNavigationEntry> buildPrimaryNavigationEntries() {
  return appNavigationEntries
      .where((entry) => entry.includeInPrimaryNavigation)
      .toList(growable: false);
}
