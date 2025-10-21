import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../../widgets/pages/home_page_view.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/theme/theme_labels.dart';

class MobileHomeShell extends StatefulWidget {
  const MobileHomeShell({super.key});

  @override
  State<MobileHomeShell> createState() => _MobileHomeShellState();
}

class _MobileHomeShellState extends State<MobileHomeShell> {
  late final List<AppNavigationEntry> _destinations;
  late int _selectedIndex;
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _destinations = buildPrimaryNavigationEntries();
    _selectedIndex = _destinations.indexWhere((entry) => entry.route == '/home');
    if (_selectedIndex == -1) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scriptagher'),
        actions: [
          IconButton(
            tooltip: 'Cambia tema',
            icon: const Icon(Icons.palette_outlined),
            onPressed: _showThemePicker,
          ),
        ],
      ),
      body: const HomePage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, _destinations.length - 1),
        onDestinationSelected: _handleDestinationSelected,
        destinations: _destinations
            .map(
              (entry) => NavigationDestination(
                icon: Icon(entry.icon ?? Icons.circle_outlined),
                selectedIcon: Icon(entry.selectedIcon ?? entry.icon ?? Icons.circle),
                label: entry.label,
              ),
            )
            .toList(growable: false),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        backgroundColor: colorScheme.surface,
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    if (index < 0 || index >= _destinations.length) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    final entry = _destinations[index];
    if (!entry.hasChildren) {
      final route = entry.route;
      if (route == null) {
        return;
      }
      if (route == '/home') {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      Navigator.of(context).pushNamed(route);
      return;
    }

    _showBranchSheet(entry);
  }

  Future<void> _showBranchSheet(AppNavigationEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Text(
                  entry.label,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              ...entry.children.map(
                (child) => ListTile(
                  leading: Icon(child.icon ?? entry.icon ?? Icons.circle_outlined),
                  title: Text(child.label),
                  onTap: child.route == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed(child.route!);
                        },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showThemePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: AnimatedBuilder(
            animation: _themeController,
            builder: (context, _) {
              final currentTheme = _themeController.currentTheme;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Text(
                      'Tema',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  ...AppTheme.values.map(
                    (theme) => ListTile(
                      leading: Icon(
                        theme == currentTheme
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: theme == currentTheme
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      title: Text(describeAppTheme(theme)),
                      onTap: () {
                        Navigator.of(context).pop();
                        _themeController.setTheme(theme);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
