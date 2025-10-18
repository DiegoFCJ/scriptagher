import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

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

    return WindowTitleBarBox(
      child: MoveWindow(
        child: Container(
          color: const Color.fromARGB(34, 34, 34, 221),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/home'),
                child: const Text(
                  'Scriptagher',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<_MenuOption>(
                icon: const Icon(Icons.menu, color: Colors.white),
                onSelected: (opt) {
                  switch (opt) {
                    case _MenuOption.tutorial:
                      Navigator.pushNamed(context, '/tutorial');
                      break;
                    case _MenuOption.marketplace:
                      Navigator.pushNamed(context, '/marketplace');
                      break;
                    case _MenuOption.settings:
                      Navigator.pushNamed(context, '/settings');
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
                      'Naviga',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem<_MenuOption>(
                    value: _MenuOption.tutorial,
                    child: Text('Tutorial'),
                  ),
                  PopupMenuItem<_MenuOption>(
                    value: _MenuOption.marketplace,
                    child: Text('Marketplace'),
                  ),
                  PopupMenuItem<_MenuOption>(
                    value: _MenuOption.settings,
                    child: Text('Impostazioni'),
                  ),
                  PopupMenuItem<_MenuOption>(
                    value: _MenuOption.botsList,
                    child: Text('Bots List'),
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

enum _MenuOption { tutorial, marketplace, settings, botsList }
