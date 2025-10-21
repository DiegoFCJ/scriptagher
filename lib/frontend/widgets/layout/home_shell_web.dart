import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../widgets/components/navigation_menu.dart';
import '../../widgets/pages/home_page_view.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/theme/theme_labels.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: _WebNavigationAppBar(),
      body: HomePage(),
    );
  }
}

class _WebNavigationAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _WebNavigationAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final routeName = ModalRoute.of(context)?.settings.name;
    final resolvedRoute =
        routeName == null || routeName == Navigator.defaultRouteName
            ? '/home'
            : routeName;
    final isCompact = MediaQuery.of(context).size.width < 900;
    final themeController = ThemeController();

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 24,
      title: Row(
        children: [
          Text(
            'Scriptagher',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          if (isCompact)
            _NavigationOverflowButton(
              themeController: themeController,
            )
          else
            _NavigationActionRow(
              currentRoute: resolvedRoute,
              themeController: themeController,
            ),
        ],
      ),
    );
  }
}

class _NavigationActionRow extends StatelessWidget {
  const _NavigationActionRow({
    required this.currentRoute,
    required this.themeController,
  });

  final String currentRoute;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...appNavigationEntries.map(
                (entry) => _NavigationActionButton(
                  entry: entry,
                  currentRoute: currentRoute,
                ),
              ),
              _ThemeMenuButton(themeController: themeController),
            ],
          ),
        );
      },
    );
  }
}

class _NavigationActionButton extends StatelessWidget {
  const _NavigationActionButton({
    required this.entry,
    required this.currentRoute,
  });

  final AppNavigationEntry entry;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = entry.containsRoute(currentRoute);
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          color: isActive ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
        );

    if (!entry.hasChildren) {
      return TextButton(
        onPressed: entry.route == null
            ? null
            : () => Navigator.of(context).pushNamed(entry.route!),
        child: Text(entry.label, style: textStyle),
      );
    }

    return MenuAnchor(
      builder: (context, controller, child) {
        return TextButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.label, style: textStyle),
              const SizedBox(width: 4),
              Icon(
                controller.isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      },
      menuChildren: entry.children
          .map((child) => buildNavigationMenuItem(context, child))
          .toList(growable: false),
    );
  }
}

class _NavigationOverflowButton extends StatelessWidget {
  const _NavigationOverflowButton({required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MenuAnchor(
              builder: (context, controller, child) {
                return IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
              menuChildren: [
                ...buildNavigationMenuChildren(context),
                MenuDivider(),
                ..._buildThemeMenuItems(context, themeController),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ThemeMenuButton extends StatelessWidget {
  const _ThemeMenuButton({required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return MenuAnchor(
          builder: (context, controller, child) {
            return IconButton(
              tooltip: 'Cambia tema',
              icon: const Icon(Icons.palette_outlined),
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
            );
          },
          menuChildren: _buildThemeMenuItems(context, themeController),
        );
      },
    );
  }
}

List<Widget> _buildThemeMenuItems(
  BuildContext context,
  ThemeController themeController,
) {
  final currentTheme = themeController.currentTheme;
  final colorScheme = Theme.of(context).colorScheme;

  return AppTheme.values
      .map(
        (theme) => MenuItemButton(
          leadingIcon: Icon(
            theme == currentTheme
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_off_rounded,
            color: theme == currentTheme
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          onPressed: () {
            MenuController.maybeOf(context)?.close();
            themeController.setTheme(theme);
          },
          child: Text(describeAppTheme(theme)),
        ),
      )
      .toList(growable: false);
}
