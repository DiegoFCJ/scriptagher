import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_shell_desktop.dart';
import 'home_shell_mobile.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return const DesktopHomeShell();
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return const MobileHomeShell();
    }
  }
}
