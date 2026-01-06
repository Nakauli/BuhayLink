import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// Import the Splash Screen
import 'features/home/presentation/pages/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase Warning: $e");
  }

  // 👇 Run the new Main App Wrapper that starts with the Splash Screen
  runApp(const BuhayLinkApp());
}

class BuhayLinkApp extends StatelessWidget {
  const BuhayLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BuhayLink',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        // Ensure standard font scaling
        textTheme: Typography.englishLike2018.apply(fontSizeFactor: 1.0),
      ),
      // 👇 This sets the Splash Screen as the entry point
      home: const SplashScreen(),
    );
  }
}
