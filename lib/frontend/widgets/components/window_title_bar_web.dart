import 'package:flutter/material.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
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
          const Spacer(),
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
    );
  }
}

enum _MenuOption { tutorial, marketplace, settings, botsList }
