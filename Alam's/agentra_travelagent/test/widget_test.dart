import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agentra_travel_agent/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AgentraAgentPortal());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
