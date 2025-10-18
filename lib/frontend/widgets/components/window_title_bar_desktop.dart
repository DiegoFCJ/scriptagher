import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

const bool _useDesktopFrame =
    bool.fromEnvironment('USE_DESKTOP_FRAME', defaultValue: true);

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop || _isTest || !_useDesktopFrame) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final themeController = ThemeController();

    return WindowTitleBarBox(
      child: MoveWindow(
        child: Container(
          color: colorScheme.surface,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Row(
                children: [
                  AnimatedBuilder(
                    animation: themeController,
                    builder: (context, _) {
                      final currentTheme = themeController.currentTheme;
                      return PopupMenuButton<AppTheme>(
                        tooltip: 'Cambia tema',
                        initialValue: currentTheme,
                        icon: Icon(
                          Icons.brightness_6,
                          color: colorScheme.onSurface,
                        ),
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
                        enabled: false,
                        child: Text(
                          'Prima Sezione',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      PopupMenuDivider(),
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
            ],
          ),
        ),
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
