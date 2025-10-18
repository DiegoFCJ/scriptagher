import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import '../components/window_title_bar.dart';
import '../pages/home_page_view.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

const bool _useDesktopFrame =
    bool.fromEnvironment('USE_DESKTOP_FRAME', defaultValue: true);

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: const [
        WindowTitleBar(),
        Expanded(
          child: HomePage(),
        ),
      ],
    );

    if (!_isDesktop || _isTest || !_useDesktopFrame) {
      return content;
    }

    return WindowBorder(
      color: Colors.transparent,
      child: content,
    );
  }
}
