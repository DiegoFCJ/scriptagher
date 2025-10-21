import 'package:scriptagher/shared/theme/theme_controller.dart';

String describeAppTheme(AppTheme theme) {
  switch (theme) {
    case AppTheme.light:
      return 'Tema chiaro';
    case AppTheme.dark:
      return 'Tema scuro';
    case AppTheme.highContrast:
      return 'Alto contrasto';
  }
}
