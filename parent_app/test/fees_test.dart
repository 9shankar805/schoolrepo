import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:parent_app/providers/api_provider.dart';
import 'package:parent_app/providers/theme_provider.dart';
import 'package:parent_app/screens/fees_screen.dart';

void main() {
  testWidgets('Test FeesScreen rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ApiProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(
          home: FeesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fee Ledger & Payments'), findsOneWidget);
  });
}
