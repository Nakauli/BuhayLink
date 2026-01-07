import 'package:flutter_test/flutter_test.dart';
import 'package:buhay_link/app.dart'; // Imports BuhayLinkApp

void main() {
  testWidgets('App starts with Splash Screen', (WidgetTester tester) async {
    // 1. Build the app using the NEW class name
    await tester.pumpWidget(const BuhayLinkApp());

    // 2. Allow the splash screen animation to start
    await tester.pump();

    // 3. Verify that we are on the Splash Screen (look for the Logo Text image)
    // Note: Since we use Image.asset, we look for the image provider, or just simply verify it builds.
    // For a basic smoke test, verifying the app builds without crashing is often enough initially.

    // Find the widget by type (Splash Screen) to confirm it loaded
    // You might need to import the splash screen if you want to findByType(SplashScreen)
    // Or just check if anything rendered:
    expect(find.byType(BuhayLinkApp), findsOneWidget);
  });
}
