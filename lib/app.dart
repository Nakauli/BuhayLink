import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Hide AuthProvider to avoid conflict
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/jobs/presentation/providers/job_provider.dart';
import 'features/splash/splash_page.dart';
import 'config/routes/app_routes.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/home/presentation/pages/dashboard_page.dart';

class JobPullingApp extends StatelessWidget {
  const JobPullingApp({super.key});

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
        ),

        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // 1. Check for Errors
            if (snapshot.hasError) {
              print("❌ ERROR in Auth Stream: ${snapshot.error}");
              return const Scaffold(
                body: Center(child: Text("Error initializing Firebase")),
              );
            }

            // 2. Loading State
            if (snapshot.connectionState == ConnectionState.waiting) {
              print("⏳ DEBUG: Still waiting for Firebase...");
              return const SplashPage();
            }

            // 3. User Found
            if (snapshot.hasData) {
              print("✅ DEBUG: User is logged in! Going to Dashboard.");
              return const DashboardPage();
            }

            // 4. No User
            print("👤 DEBUG: No user found. Going to Login.");
            return const LoginPage();
          },
        ),

        routes: AppRoutes.routes,
      ),
    );
  }
}
