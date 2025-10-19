import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

import 'navigation_menu.dart';

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
              MenuAnchor(
                alignmentOffset: const Offset(0, 8),
                builder: (context, controller, child) {
                  final isOpen = controller.isOpen;
                  final textStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      );

                  return Tooltip(
                    message: 'Apri la navigazione',
                    child: Material(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => isOpen ? controller.close() : controller.open(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.menu,
                                size: 26,
                                color: colorScheme.onSurface,
                              ),
                              const SizedBox(width: 12),
                              Text('Menu', style: textStyle),
                              const SizedBox(width: 8),
                              Icon(
                                isOpen
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 20,
                                color: colorScheme.onSurface,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                menuChildren: buildNavigationMenuChildren(context),
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
                ],
              ),
            ],
          ),
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
