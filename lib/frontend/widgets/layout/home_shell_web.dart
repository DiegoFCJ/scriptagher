import 'package:flutter/material.dart';

import '../components/navigation_sidebar.dart';
import '../pages/home_page_view.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Row(
        children: [
          NavigationSidebar(),
          Expanded(
            child: HomePage(),
          ),
        ],
      ),
    );
  }
}
