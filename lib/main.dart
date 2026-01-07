import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart'; // Imports BuhayLinkApp

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    print("Firebase Warning: $e");
  }

  runApp(const BuhayLinkApp());
}
