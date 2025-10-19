import 'package:flutter/material.dart';

@immutable
class NavigationMenuEntry {
  NavigationMenuEntry({
    required this.label,
    this.route,
    List<NavigationMenuEntry> children = const <NavigationMenuEntry>[],
  })  : children = List.unmodifiable(children),
        assert(route != null || children.isNotEmpty,
            'A menu entry must have either a route or children.');

  final String label;
  final String? route;
  final List<NavigationMenuEntry> children;

  Widget toMenuWidget(BuildContext context) {
    final TextStyle? textStyle = Theme.of(context).textTheme.bodyMedium;
    const EdgeInsets menuPadding = EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    );

    if (children.isEmpty) {
      return MenuItemButton(
        style: MenuItemButton.styleFrom(padding: menuPadding),
        child: Text(label, style: textStyle),
        onPressed: () {
          if (route == null) {
            return;
          }
          MenuController.maybeOf(context)?.close();
          Navigator.of(context).pushNamed(route!);
        },
      );
    }

    return SubmenuButton(
      menuChildren:
          children.map((child) => child.toMenuWidget(context)).toList(),
      child: Padding(
        padding: menuPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: textStyle),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

final List<NavigationMenuEntry> appNavigationEntries =
    List<NavigationMenuEntry>.unmodifiable(<NavigationMenuEntry>[
  NavigationMenuEntry(label: 'Home', route: '/home'),
  NavigationMenuEntry(label: 'Bots', route: '/bots'),
  NavigationMenuEntry(label: 'Tutorial', route: '/tutorial'),
  NavigationMenuEntry(
    label: 'Test',
    children: <NavigationMenuEntry>[
      NavigationMenuEntry(label: 'Test 1', route: '/test1'),
      NavigationMenuEntry(label: 'Test 2', route: '/test2'),
      NavigationMenuEntry(label: 'Test 3', route: '/test3'),
    ],
  ),
  NavigationMenuEntry(label: 'Settings', route: '/settings'),
]);

List<Widget> buildNavigationMenuChildren(
  BuildContext context,
) {
  return appNavigationEntries
      .map((entry) => entry.toMenuWidget(context))
      .toList(growable: false);
}
