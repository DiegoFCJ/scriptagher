// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:scriptagher/main.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Home page shows navigation categories', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final telemetryService = TelemetryService();
    await telemetryService.initialize();

    await tester.pumpWidget(MyApp(telemetryService: telemetryService));
    await tester.pumpAndSettle();

    expect(find.text('Scaricati'), findsWidgets);
    expect(find.text('Online'), findsWidgets);
    expect(find.text('Locali'), findsWidgets);
  });
}
