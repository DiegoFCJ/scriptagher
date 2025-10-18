import 'package:flutter/material.dart';

import '../components/window_title_bar.dart';
import '../pages/home_page_view.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: const WindowTitleBar(),
      ),
      body: const HomePage(),
    );
  }
}
