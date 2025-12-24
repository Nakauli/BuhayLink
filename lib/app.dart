import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart'; //
import 'features/jobs/presentation/providers/job_provider.dart';
import 'features/splash/splash_page.dart';
import 'config/routes/app_routes.dart';

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
        title: 'Job Pulling App',
        debugShowCheckedModeBanner: false,
        home: const SplashPage(),
        routes: AppRoutes.routes,
      ),
    );
  }
}