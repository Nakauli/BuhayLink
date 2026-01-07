import 'package:flutter/material.dart';
import 'package:buhay_link/app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ========================================================
  // 🎛️ CONTROL PANEL
  // ========================================================
  final double gearTopPosition = 135.0;
  final double gearRightPosition = 75.0;
  final double gearSize = 60.0;

  // 🎨 BRANDING: Deep Premium Blue Gradient
  final List<Color> gradientColors = [
    const Color(0xFF0D47A1), // Deep Royal Blue (Top)
    const Color(0xFF42A5F5), // Bright Blue (Bottom)
  ];
  // ========================================================

  late AnimationController _entranceController;
  late AnimationController _gearController;
  late AnimationController _effectController;

  late Animation<double> _blFadeIn;
  late Animation<double> _blScaleIn;
  late Animation<double> _textFadeIn;
  late Animation<Offset> _textSlideIn;
  late Animation<double> _gearFadeIn;
  late Animation<double> _gearTurns;
  late Animation<double> _effectIntensity;

  @override
  void initState() {
    super.initState();

    // 1. ENTRANCE (0s - 2s)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _blFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _blScaleIn = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
    _textSlideIn = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );
    _gearFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. GEAR SPIN
    _gearController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _gearTurns = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(parent: _gearController, curve: Curves.easeOutCubic),
    );

    // 3. COLOR TRANSFORMATION CONTROLLER
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _effectIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeInOut),
    );

    // --- SEQUENCE ---
    _entranceController.forward();
    _gearController.forward();

    // When Gear Stops -> Turn Background Blue & Logo White
    _gearController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _effectController.forward();
      }
    });

    // Navigate after effect completes
    _effectController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToAuthGate();
        });
      }
    });
  }

  void _navigateToAuthGate() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGate(),
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
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // LAYER 1: The Blue Gradient Background
          AnimatedBuilder(
            animation: _effectIntensity,
            builder: (context, child) {
              return Opacity(
                opacity: _effectIntensity.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: gradientColors,
                    ),
                  ),
                ),
              );
            },
          ),

          // LAYER 2: The Logo Elements (Transforming to White)
          Center(
            child: AnimatedBuilder(
              animation: _effectIntensity,
              builder: (context, child) {
                // This Filter applies WHITE over everything based on intensity
                return ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(_effectIntensity.value),
                    BlendMode
                        .srcATop, // Keeps transparency, paints visible pixels white
                  ),
                  child: child,
                );
              },
              // The Content to be whitened
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        ScaleTransition(
                          scale: _blScaleIn,
                          child: FadeTransition(
                            opacity: _blFadeIn,
                            child: Image.asset(
                              'assets/images/logo_bl.png',
                              width: 200,
                            ),
                          ),
                        ),
                        Positioned(
                          top: gearTopPosition,
                          right: gearRightPosition,
                          child: FadeTransition(
                            opacity: _gearFadeIn,
                            child: RotationTransition(
                              turns: _gearTurns,
                              child: Image.asset(
                                'assets/images/logo_gear.png',
                                width: gearSize,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SlideTransition(
                    position: _textSlideIn,
                    child: FadeTransition(
                      opacity: _textFadeIn,
                      child: Image.asset(
                        'assets/images/logo_text.png',
                        width: 280,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
