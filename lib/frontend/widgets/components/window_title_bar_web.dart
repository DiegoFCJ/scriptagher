import 'package:flutter/material.dart';
import 'package:scriptagher/shared/theme/theme_controller.dart';

import 'mini_droid_brand.dart';
import 'navigation_menu.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeController = ThemeController();
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          MiniDroidBrandMark(size: 24),
          const SizedBox(width: 12),
          Text(
            'Scriptagher',
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 20),
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
        ],
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
