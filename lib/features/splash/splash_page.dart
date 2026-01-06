import 'package:flutter/material.dart';

// CHANGE: Use StatelessWidget (No timers, no initState)
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Replace with your logo/icon
            Icon(Icons.work_rounded, size: 80, color: Color(0xFF2E7EFF)),
            SizedBox(height: 24),
            Text(
              "BuhayLink",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7EFF),
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF2E7EFF)),
          ],
        ),
      ),
    );
  }
}
