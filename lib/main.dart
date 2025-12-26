import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// 👇 This imports the file where your partner set up all the Providers
import 'app.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the database connection
  try {
    await Firebase.initializeApp(); 
  } catch (e) {
    print("Firebase Error: $e");
  }
  
  // 👇 CRITICAL: Run 'JobPullingApp' to load Providers
  runApp(const JobPullingApp()); 
}