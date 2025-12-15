import 'package:buhay_link/features/home/presentation/pages/add_job_page.dart';
import 'package:flutter/material.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';


class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String addJob = '/add-job';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginPage(),
    home: (context) => const HomePage(),
    addJob: (context) => const PostJobPage(),
  };
}