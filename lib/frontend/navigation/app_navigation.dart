import 'package:flutter/material.dart';

@immutable
class AppNavigationEntry {
  AppNavigationEntry({
    required this.label,
    required this.icon,
    this.route,
    List<AppNavigationEntry> children = const <AppNavigationEntry>[],
  }) : children = List<AppNavigationEntry>.unmodifiable(children) {
    assert(
      route != null || children.isNotEmpty,
      'A navigation entry must have either a route or children.',
    );
  }

  final String label;
  final IconData icon;
  final String? route;
  final List<AppNavigationEntry> children;

  bool get isLeaf => children.isEmpty;
}

final List<AppNavigationEntry> appNavigationEntries =
    List<AppNavigationEntry>.unmodifiable(<AppNavigationEntry>[
  AppNavigationEntry(
    label: 'Home',
    icon: Icons.home_rounded,
    route: '/home',
  ),
  AppNavigationEntry(
    label: 'Bots',
    icon: Icons.smart_toy_rounded,
    route: '/bots',
  ),
  AppNavigationEntry(
    label: 'Tutorial',
    icon: Icons.school_rounded,
    route: '/tutorial',
  ),
  AppNavigationEntry(
    label: 'Test',
    icon: Icons.science_rounded,
    children: <AppNavigationEntry>[
      AppNavigationEntry(
        label: 'Test 1',
        icon: Icons.filter_1_rounded,
        route: '/test1',
      ),
      AppNavigationEntry(
        label: 'Test 2',
        icon: Icons.filter_2_rounded,
        route: '/test2',
      ),
      AppNavigationEntry(
        label: 'Test 3',
        icon: Icons.filter_3_rounded,
        route: '/test3',
      ),
    ],
  ),
  AppNavigationEntry(
    label: 'Settings',
    icon: Icons.settings_rounded,
    route: '/settings',
  ),
]);

Iterable<AppNavigationEntry> flattenNavigationEntries(
  Iterable<AppNavigationEntry> entries,
) sync* {
  for (final AppNavigationEntry entry in entries) {
    yield entry;
    if (entry.children.isNotEmpty) {
      yield* flattenNavigationEntries(entry.children);
    }
  }
}

AppNavigationEntry? findNavigationEntry(String route) {
  for (final AppNavigationEntry entry
      in flattenNavigationEntries(appNavigationEntries)) {
    if (entry.route == route) {
      return entry;
    }
  }
  return null;
}

bool navigationEntryContainsRoute(AppNavigationEntry entry, String route) {
  if (entry.route == route) {
    return true;
  }
  for (final AppNavigationEntry child in entry.children) {
    if (navigationEntryContainsRoute(child, route)) {
      return true;
    }
  }
  return false;
}
