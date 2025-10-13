// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:proximity_alert/main.dart';

void main() {
  testWidgets('App loads without camera', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProximityAlertApp());

    // Since we don't have camera access in tests, should show permission denied screen
    expect(find.text('Camera Permission Required'), findsOneWidget);
  });
}
