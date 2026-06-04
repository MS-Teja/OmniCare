import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare/main.dart';

void main() {
  testWidgets('OmniCare app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const OmniCareApp());
    expect(find.text('Hi there 👋'), findsOneWidget);
  });
}
