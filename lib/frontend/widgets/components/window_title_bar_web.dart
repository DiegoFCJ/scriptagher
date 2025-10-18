import 'package:flutter/material.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeController = ThemeController();

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/home'),
            child: Text(
              'Scriptagher',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              final currentTheme = themeController.currentTheme;
              return PopupMenuButton<AppTheme>(
                tooltip: 'Cambia tema',
                initialValue: currentTheme,
                icon: Icon(Icons.brightness_6, color: colorScheme.onSurface),
                onSelected: (theme) => themeController.setTheme(theme),
                itemBuilder: (ctx) => AppTheme.values
                    .map(
                      (theme) => CheckedPopupMenuItem<AppTheme>(
                        value: theme,
                        checked: theme == currentTheme,
                        child: Text(_labelForTheme(theme)),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_MenuOption>(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
            onSelected: (opt) {
              switch (opt) {
                case _MenuOption.portfolio:
                  Navigator.pushNamed(context, '/portfolio');
                  break;
                case _MenuOption.botsList:
                  Navigator.pushNamed(context, '/bots');
                  break;
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.portfolio,
                child: Text('Portfolio'),
              ),
              PopupMenuItem<_MenuOption>(
                value: _MenuOption.botsList,
                child: Text('Bots List'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MenuOption { portfolio, botsList }

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
