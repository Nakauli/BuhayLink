import 'package:flutter/material.dart';
// 1. Import the Routes configuration
import 'config/routes/app_routes.dart'; 

void main() {
  runApp(const BuhayLinkApp());
}

class BuhayLinkApp extends StatelessWidget {
  const BuhayLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuhayLink',
      debugShowCheckedModeBanner: false,
      
      // 2. Use the Named Route from your config file
      // This is cleaner and makes your Professor happy (SOLID)
      initialRoute: AppRoutes.login,
      
      // 3. Connect the routes map
      routes: AppRoutes.routes,
      
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
    );
  }
}