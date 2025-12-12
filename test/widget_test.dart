import 'package:buhay_link/app.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  testWidgets('Login page displays correctly', (WidgetTester tester) async {
    // 1. Build the app using your actual main widget name
    await tester.pumpWidget(const JobPullingApp());

    // 2. Allow animations to settle (important for navigation)
    await tester.pumpAndSettle();

    // 3. Verify that the Real Login Page text is present
    // We look for "BuhayLink" or "Secure Entry" since those are in your new code
    expect(find.text('BuhayLink'), findsOneWidget);
    expect(find.text('Secure Entry'), findsOneWidget);
  });
}