import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';

List<Widget> buildNavigationMenuChildren(BuildContext context) {
  return appNavigationEntries
      .map((entry) => _buildMenuEntry(context, entry))
      .toList(growable: false);
}

Widget _buildMenuEntry(BuildContext context, AppNavigationEntry entry) {
  if (entry.children.isEmpty) {
    return _buildLeafMenuItem(context, entry);
  }

  return SubmenuButton(
    menuChildren: entry.children
        .map((child) => _buildMenuEntry(context, child))
        .toList(growable: false),
    child: _SubMenuButtonLabel(label: entry.label),
  );
}

Widget _buildLeafMenuItem(BuildContext context, AppNavigationEntry entry) {
  final TextStyle? textStyle = Theme.of(context).textTheme.bodyMedium;
  const EdgeInsets menuPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  return MenuItemButton(
    style: MenuItemButton.styleFrom(padding: menuPadding),
    child: Text(entry.label, style: textStyle),
    onPressed: () {
      if (entry.route == null) {
        return;
      }
      MenuController.maybeOf(context)?.close();
      Navigator.of(context).pushNamed(entry.route!);
    },
  );
}

class _SubMenuButtonLabel extends StatelessWidget {
  const _SubMenuButtonLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final TextStyle? textStyle = Theme.of(context).textTheme.bodyMedium;
    const EdgeInsets menuPadding = EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    );

    return Padding(
      padding: menuPadding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: textStyle),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
