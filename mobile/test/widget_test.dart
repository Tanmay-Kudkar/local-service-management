import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_service_management_mobile/screens/auth_screen.dart';

void main() {
  testWidgets('Auth screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );

    expect(find.text('Local Service App'), findsOneWidget);
  });
}
