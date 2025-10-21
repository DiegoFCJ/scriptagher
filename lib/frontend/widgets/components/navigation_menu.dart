import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';

const EdgeInsets _menuPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 12,
);

Widget buildNavigationMenuItem(
  BuildContext context,
  AppNavigationEntry entry,
) {
  final TextStyle? textStyle = Theme.of(context).textTheme.bodyMedium;

  if (!entry.hasChildren) {
    return MenuItemButton(
      style: MenuItemButton.styleFrom(padding: _menuPadding),
      onPressed: entry.route == null
          ? null
          : () {
              if (entry.route == null) {
                return;
              }
              MenuController.maybeOf(context)?.close();
              Navigator.of(context).pushNamed(entry.route!);
            },
      child: Text(entry.label, style: textStyle),
    );
  }

  return SubmenuButton(
    menuChildren: entry.children
        .map((child) => buildNavigationMenuItem(context, child))
        .toList(growable: false),
    child: Padding(
      padding: _menuPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(entry.label, style: textStyle),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

List<Widget> buildNavigationMenuChildren(BuildContext context) {
  return appNavigationEntries
      .map((entry) => buildNavigationMenuItem(context, entry))
      .toList(growable: false);
}
