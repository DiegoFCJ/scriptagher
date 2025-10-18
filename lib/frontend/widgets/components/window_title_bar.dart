import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    final barContent = Container(
      color: const Color.fromARGB(34, 34, 34, 221),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Titolo tappabile come “Home”
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/home'),
            child: const Text(
              "Scriptagher",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Menu “panino” con header non cliccabile
          PopupMenuButton<_MenuOption>(
            icon: const Icon(Icons.menu, color: Colors.white),
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
            itemBuilder: (ctx) => [
              // Header non cliccabile
              PopupMenuItem<_MenuOption>(
                enabled: false,
                child: Text(
                  "Prima Sezione",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const PopupMenuDivider(),

              // Voci cliccabili
              const PopupMenuItem<_MenuOption>(
                value: _MenuOption.portfolio,
                child: Text("Portfolio"),
              ),
              const PopupMenuItem<_MenuOption>(
                value: _MenuOption.botsList,
                child: Text("Bots List"),
              ),
            ],
          ),
        ],
      ),
    );

    if (kIsWeb) {
      return barContent;
    }

    return WindowTitleBarBox(
      child: MoveWindow(
        child: barContent,
      ),
    );
  }
}

enum _MenuOption { portfolio, botsList }
