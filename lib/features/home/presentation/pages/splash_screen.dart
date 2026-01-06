import 'package:buhay_link/features/home/presentation/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:buhay_link/features/auth/presentation/pages/login_page.dart'; // Adjust if needed
import 'package:firebase_auth/firebase_auth.dart'; // Needed for Auth Check

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Controllers
  late AnimationController _entranceController;
  late AnimationController _gearController;

  // Animations
  late Animation<double> _blFade;
  late Animation<double> _blScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _gearFade;

  @override
  void initState() {
    super.initState();

    // 1. Setup Entrance Animations (Total duration 2 seconds)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // BL Logo: Pop in (Scale + Fade)
    _blFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // FIX: Use Curves.easeOutBack instead of backOut
    _blScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Text: Slide up + Fade
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );

    // Gear: Fade in at the end
    _gearFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. Setup Gear Rotation (Infinite Spinner)
    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4 seconds per full rotation
    )..repeat(); // Loop forever

    // 3. Start Animation
    _entranceController.forward();

    // 4. Navigate after 4 seconds
    Timer(const Duration(seconds: 4), _checkAuthAndNavigate);
  }

  Future<void> _checkAuthAndNavigate() async {
    // Simple check: If user is logged in -> Dashboard, else -> Login
    final user = FirebaseAuth.instance.currentUser;
    Widget nextScreen = (user != null)
        ? const DashboardPage()
        : const LoginPage();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _gearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- LOGO COMPOSITION (Stack) ---
            SizedBox(
              width: 250, // Adjust size based on your assets
              height: 250,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. BL Logo (Base)
                  ScaleTransition(
                    scale: _blScale,
                    child: FadeTransition(
                      opacity: _blFade,
                      child: Image.asset('assets/logo_bl.png', width: 200),
                    ),
                  ),

                  // 2. Spinning Gear (Positioned inside the BL nook)
                  Positioned(
                    right: 60, // Adjust to fit perfectly
                    bottom: 60, // Adjust to fit perfectly
                    child: FadeTransition(
                      opacity: _gearFade,
                      child: RotationTransition(
                        turns: _gearController,
                        child: Image.asset('assets/logo_gear.png', width: 70),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- TEXT LOGO ---
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textFade,
                child: Image.asset('assets/logo_text.png', width: 280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
