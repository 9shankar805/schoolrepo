import 'package:flutter_test/flutter_test.dart';
import 'package:parent_app/main.dart';

void main() {
  testWidgets('ParentsApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ParentsApp());
    expect(find.byType(ParentsApp), findsOneWidget);
    // Advance time past initial render and animations
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ParentsApp), findsOneWidget);
  });
}
