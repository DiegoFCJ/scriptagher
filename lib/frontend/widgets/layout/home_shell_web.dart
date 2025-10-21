import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../components/mini_droid_brand.dart';
import '../components/navigation_menu.dart';
import '../pages/home_page_view.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  void _navigateToEntry(BuildContext context, AppNavigationEntry entry) {
    final String? route = entry.route;
    if (route == null) {
      return;
    }
    if (route == '/home') {
      Navigator.of(context).popUntil((modalRoute) => modalRoute.isFirst);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;
    final bool isRootRoute = !Navigator.of(context).canPop();

    return HomePage(
      appBar: _WebTopNavigationBar(
        currentRoute: currentRoute,
        isRootRoute: isRootRoute,
        onNavigate: (entry) => _navigateToEntry(context, entry),
      ),
    );
  }
}

class _WebTopNavigationBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _WebTopNavigationBar({
    required this.currentRoute,
    required this.isRootRoute,
    required this.onNavigate,
  });

  final String? currentRoute;
  final bool isRootRoute;
  final ValueChanged<AppNavigationEntry> onNavigate;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 4,
      color: colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 960;
            final EdgeInsets padding = EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 32,
              vertical: 12,
            );

            return Padding(
              padding: padding,
              child: Row(
                children: [
                  const MiniDroidBrandMark(size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Scriptagher',
                    style: textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (isCompact)
                    MenuAnchor(
                      alignmentOffset: const Offset(0, 8),
                      builder: (context, controller, child) {
                        return IconButton(
                          tooltip: 'Apri navigazione',
                          icon: Icon(
                            controller.isOpen
                                ? Icons.close_rounded
                                : Icons.menu_rounded,
                          ),
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                        );
                      },
                      menuChildren: buildNavigationMenuChildren(context),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: appNavigationEntries
                          .map(
                            (entry) => _TopNavigationEntry(
                              entry: entry,
                              isActive: _isEntryActive(entry),
                              onNavigate: onNavigate,
                            ),
                          )
                          .toList(growable: false),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isEntryActive(AppNavigationEntry entry) {
    final String? route = currentRoute;
    if (route == null || route.isEmpty) {
      return entry.route == '/home' && isRootRoute;
    }
    if (entry.route != null && entry.route == route) {
      return true;
    }
    if (entry.children.isEmpty) {
      return false;
    }
    return navigationEntryContainsRoute(entry, route);
  }
}

class _TopNavigationEntry extends StatelessWidget {
  const _TopNavigationEntry({
    required this.entry,
    required this.isActive,
    required this.onNavigate,
  });

  final AppNavigationEntry entry;
  final bool isActive;
  final ValueChanged<AppNavigationEntry> onNavigate;

  @override
  Widget build(BuildContext context) {
    if (entry.children.isEmpty) {
      return _NavigationButton(
        label: entry.label,
        isActive: isActive,
        onPressed: () => onNavigate(entry),
      );
    }

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      builder: (context, controller, child) {
        return _NavigationButton(
          label: entry.label,
          isActive: isActive,
          trailingIcon: controller.isOpen
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          onPressed: () => controller.isOpen
              ? controller.close()
              : controller.open(),
        );
      },
      menuChildren: entry.children
          .map(
            (child) => MenuItemButton(
              leadingIcon: Icon(child.icon),
              child: Text(child.label),
              onPressed: () {
                MenuController.maybeOf(context)?.close();
                onNavigate(child);
              },
            ),
          )
          .toList(growable: false),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.label,
    required this.onPressed,
    required this.isActive,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color foregroundColor =
        isActive ? colorScheme.primary : colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.titleSmall?.copyWith(
                color: foregroundColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 6),
              Icon(trailingIcon, size: 18, color: foregroundColor),
            ],
          ],
        ),
      ),
    );
  }
}
