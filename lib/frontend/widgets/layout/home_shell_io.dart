import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'home_shell_desktop.dart' as desktop_shell;
import 'home_shell_mobile.dart' as mobile_shell;

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    if (_isDesktopPlatform(defaultTargetPlatform)) {
      return const desktop_shell.HomeShell();
    }
    return const mobile_shell.HomeShell();
  }
}

bool _isDesktopPlatform(TargetPlatform platform) {
  switch (platform) {
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.iOS:
      return false;
  }
}
