import 'package:buhay_link/features/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/jobs/presentation/providers/job_provider.dart';

import 'config/routes/app_routes.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/dashboard_page.dart';

class BuhayLinkApp extends StatelessWidget {
  const BuhayLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => JobProvider()),
      ],
      child: MaterialApp(
        title: 'BuhayLink',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7EFF)),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        // 1. Start with Splash Screen
        home: const SplashScreen(),
        routes: AppRoutes.routes,
      ),
    );
  }
}

// 2. This widget handles the Login vs Dashboard logic
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text("Auth Error")));
        }

        // While checking auth status, show a simple loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const DashboardPage();
        }

        return const LoginPage();
      },
    );
  }
}
