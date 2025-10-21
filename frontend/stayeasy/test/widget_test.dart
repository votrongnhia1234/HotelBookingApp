// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:stayeasy/main.dart';

void main() {
  testWidgets('StayEasyApp wires MaterialApp with splash route', (tester) async {
    await tester.pumpWidget(const StayEasyApp());
    await tester.pump(); // allow first frame
    await tester.pump(const Duration(seconds: 3)); // flush splash timer

    final materialAppFinder = find.byType(MaterialApp);
    expect(materialAppFinder, findsOneWidget);

    final materialApp = tester.widget<MaterialApp>(materialAppFinder);
    expect(materialApp.initialRoute, '/splash');
  });
}

