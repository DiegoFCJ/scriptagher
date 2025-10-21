import 'package:flutter/material.dart';

import '../../navigation/app_navigation.dart';
import '../pages/home_page_view.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  List<AppNavigationEntry> get _entries => appNavigationEntries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent && _selectedIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedIndex = 0);
        }
      });
    }
  }

  void _handleDestinationSelected(int index) {
    final AppNavigationEntry entry = _entries[index];
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }

    if (entry.children.isNotEmpty) {
      _showSubNavigation(entry);
      return;
    }

    _navigateToEntry(entry);
  }

  void _navigateToEntry(AppNavigationEntry entry) {
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

  Future<void> _showSubNavigation(AppNavigationEntry entry) async {
    final String? route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        final TextTheme textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shrinkWrap: true,
            itemCount: entry.children.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final AppNavigationEntry child = entry.children[index];
              return ListTile(
                leading: Icon(child.icon, color: colorScheme.primary),
                title: Text(
                  child.label,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(child.route),
              );
            },
          ),
        );
      },
    );

    if (!mounted || route == null || route.isEmpty) {
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final NavigationBar navigationBar = NavigationBar(
      height: 68,
      selectedIndex: _selectedIndex,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: _handleDestinationSelected,
      destinations: _entries
          .map(
            (entry) => NavigationDestination(
              icon: Icon(entry.icon),
              label: entry.label,
            ),
          )
          .toList(growable: false),
    );

    return HomePage(
      appBar: AppBar(
        title: const Text('Scriptagher'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: navigationBar,
      ),
    );
  }
}
