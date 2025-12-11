import 'package:flutter/material.dart';
// Ensure this import points to your actual file
import 'package:buhay_link/features/auth/presentation/pages/login_page.dart';

class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';

  static Map<String, WidgetBuilder> get routes => {
    // 👇 FIX: Changed 'LoginScreen' to 'LoginPage'
    login: (context) => const LoginPage(),
  };
}