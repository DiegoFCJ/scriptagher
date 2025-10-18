import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import '../components/window_title_bar.dart';
import '../pages/home_page_view.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowBorder(
      color: Colors.transparent,
      child: Column(
        children: const [
          WindowTitleBar(),
          Expanded(
            child: HomePage(),
          ),
        ],
      ),
    );
  }
}
