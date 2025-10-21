import 'package:flutter/material.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

import '../../navigation/app_navigation.dart';

class NavigationSidebar extends StatelessWidget {
  const NavigationSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final themeController = ThemeController();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Text(
                'Navigazione',
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: _buildNavigationItems(context),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: AnimatedBuilder(
                animation: themeController,
                builder: (context, _) {
                  final currentTheme = themeController.currentTheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema',
                        style: textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withOpacity(0.5),
                          ),
                        ),
                        child: Material(
                          type: MaterialType.transparency,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButton<AppTheme>(
                              value: currentTheme,
                              isExpanded: true,
                              borderRadius: BorderRadius.circular(14),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              underline: const SizedBox.shrink(),
                              dropdownColor: colorScheme.surface,
                              onChanged: (theme) {
                                if (theme != null) {
                                  themeController.setTheme(theme);
                                }
                              },
                              items: AppTheme.values
                                  .map(
                                    (theme) => DropdownMenuItem<AppTheme>(
                                      value: theme,
                                      child: Text(
                                        _labelForTheme(theme),
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNavigationItems(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return appNavigationEntries
        .map(
          (entry) => _NavigationTile(
            entry: entry,
            currentRoute: currentRoute,
          ),
        )
        .toList(growable: false);
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.entry,
    required this.currentRoute,
    this.depth = 0,
  });

  final AppNavigationEntry entry;
  final String? currentRoute;
  final int depth;

  @override
  Widget build(BuildContext context) {
    if (entry.children.isEmpty) {
      return _NavigationLeafTile(
        entry: entry,
        isSelected: entry.route != null && entry.route == currentRoute,
        depth: depth,
      );
    }

    return _NavigationBranchTile(
      entry: entry,
      currentRoute: currentRoute,
      depth: depth,
    );
  }
}

class _NavigationLeafTile extends StatelessWidget {
  const _NavigationLeafTile({
    required this.entry,
    required this.isSelected,
    required this.depth,
  });

  final AppNavigationEntry entry;
  final bool isSelected;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(left: 12 + depth * 16.0, right: 12, bottom: 4),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: colorScheme.primary.withOpacity(0.08),
          splashColor: colorScheme.primary.withOpacity(0.12),
          onTap: entry.route == null
              ? null
              : () => Navigator.of(context).pushNamed(entry.route!),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              entry.label,
              style: textTheme.bodyLarge?.copyWith(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationBranchTile extends StatelessWidget {
  const _NavigationBranchTile({
    required this.entry,
    required this.currentRoute,
    required this.depth,
  });

  final AppNavigationEntry entry;
  final String? currentRoute;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final childTiles = entry.children
        .map(
          (child) => _NavigationTile(
            entry: child,
            currentRoute: currentRoute,
            depth: depth + 1,
          ),
        )
        .toList(growable: false);

    final hasActiveRoute =
        currentRoute != null && _entryContainsRoute(entry, currentRoute!);
    final initiallyExpanded = hasActiveRoute && entry.children.isNotEmpty;

    return _ExpandableSection(
      label: entry.label,
      depth: depth,
      initiallyExpanded: initiallyExpanded,
      children: childTiles,
      colorScheme: colorScheme,
      textTheme: textTheme,
      isActive: hasActiveRoute,
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({
    required this.label,
    required this.children,
    required this.depth,
    required this.colorScheme,
    required this.textTheme,
    required this.isActive,
    this.initiallyExpanded = false,
  });

  final String label;
  final List<Widget> children;
  final int depth;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final bool isActive;
  final bool initiallyExpanded;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant _ExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded != oldWidget.initiallyExpanded) {
      setState(() {
        _expanded = widget.initiallyExpanded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 12 + widget.depth * 16.0, right: 12),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          initiallyExpanded: _expanded,
          onExpansionChanged: (value) => setState(() => _expanded = value),
          tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          childrenPadding: EdgeInsets.zero,
          iconColor: widget.isActive
              ? widget.colorScheme.primary
              : widget.colorScheme.onSurfaceVariant,
          collapsedIconColor: widget.isActive
              ? widget.colorScheme.primary
              : widget.colorScheme.onSurfaceVariant,
          title: Text(
            widget.label,
            style: widget.textTheme.bodyLarge?.copyWith(
              color: widget.isActive
                  ? widget.colorScheme.primary
                  : widget.colorScheme.onSurface,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          children: widget.children,
        ),
      ),
    );
  }
}

String _labelForTheme(AppTheme theme) {
  switch (theme) {
    case AppTheme.light:
      return 'Tema chiaro';
    case AppTheme.dark:
      return 'Tema scuro';
    case AppTheme.highContrast:
      return 'Alto contrasto';
  }
}

bool _entryContainsRoute(AppNavigationEntry entry, String route) {
  if (entry.route == route) {
    return true;
  }

  for (final child in entry.children) {
    if (_entryContainsRoute(child, route)) {
      return true;
    }
  }

  return false;
}
