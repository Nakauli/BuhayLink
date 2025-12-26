import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// 👇 This imports the file where your partner set up all the Providers
import 'app.dart'; 

<<<<<<< HEAD

=======
>>>>>>> feature/profile-page-update
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the database connection
<<<<<<< HEAD
  await Firebase.initializeApp(); 
  
  // 👇 CRITICAL CHANGE: Run 'JobPullingApp' instead of 'BuhayLinkApp'
  // This automatically loads the AuthProvider and JobProvider you need.
  runApp(const JobPullingApp()); 
} 
=======
  try {
    await Firebase.initializeApp(); 
  } catch (e) {
    print("Firebase Error: $e");
  }
  
  // 👇 CRITICAL: Run 'JobPullingApp' to load Providers
  runApp(const JobPullingApp()); 
}
>>>>>>> feature/profile-page-update
