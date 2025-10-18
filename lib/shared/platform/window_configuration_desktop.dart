import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

Future<void> configureWindow() async {
  doWhenWindowReady(() {
    final win = appWindow;
    win.minSize = const Size(800, 600);
    win.size = const Size(1024, 768);
    win.alignment = Alignment.center;
    win.title = 'Scriptagher';
    win.show();
  });
}
