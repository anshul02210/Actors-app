import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:actors_app/main.dart';

void main() {
  testWidgets('App loads and shows Welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ActorsApp());

    // Verify that the welcome screen renders.
    expect(find.text('LineReady'), findsOneWidget);
  });
}
