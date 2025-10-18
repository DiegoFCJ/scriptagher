import 'dart:io' show Platform;

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

/// General fallback used across platforms, but configuration is effective only
/// for desktop targets.
Future<void> configureWindow() async {
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  doWhenWindowReady(() {
    final win = appWindow;
    win.minSize = const Size(800, 600);
    win.size = const Size(1024, 768);
    win.alignment = Alignment.center;
    win.title = 'Scriptagher';
    win.show();
  });
}
