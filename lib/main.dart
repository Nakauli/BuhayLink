import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// 👇 This imports your main app structure (Login/Dashboard logic)
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase Warning: $e");
  }

  // 👇 CRITICAL: Run 'JobPullingApp' to start the normal app flow (Login Screen)
  runApp(const JobPullingApp());
}
