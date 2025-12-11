import 'package:flutter_test/flutter_test.dart';
import 'package:buhay_link/main.dart'; // Imports your BuhayLinkApp

void main() {
  testWidgets('Login page displays correctly', (WidgetTester tester) async {
    // 1. Build the app using your actual main widget name
    await tester.pumpWidget(const BuhayLinkApp());

    // 2. Allow animations to settle (important for navigation)
    await tester.pumpAndSettle();

    // 3. Verify that the Real Login Page text is present
    // We look for "BuhayLink" or "Secure Entry" since those are in your new code
    expect(find.text('BuhayLink'), findsOneWidget);
    expect(find.text('Secure Entry'), findsOneWidget);
  });
}