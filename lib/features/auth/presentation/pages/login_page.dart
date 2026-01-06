import 'package:buhay_link/features/home/presentation/pages/dashboard_page.dart';
import 'package:buhay_link/features/home/presentation/pages/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Ensure this is imported
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for Database Sync
import '../../data/repositories/auth_repository.dart';
import '../../data/google_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // --- CONTROLLERS ---
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // --- STATE ---
  bool isLogin = true;
  bool isLoading = false;

  final AuthRepository _authRepository = AuthRepository();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  // --- NEW: SYNC GOOGLE DATA TO FIRESTORE ---
  Future<void> _syncGoogleUserToFirestore(User user) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snapshot = await userDoc.get();

    // Only create a new document if one doesn't exist
    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? "User", // Use Google Name
        'photoUrl': user.photoURL ?? "", // Use Google Photo
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
        'hasResume': false,
        'rating': 0.0,
        'reviewCount': 0,
        'appliedCount': 0,
        'hiredCompleted': 0,
        'about': 'No bio available.',
        'location': 'Philippines',
        'skills': [],
      });
    }
  }

  // --- LOGIC: EMAIL/PASSWORD ---
  void _submitForm() async {
    setState(() => isLoading = true);

    try {
      if (isLogin) {
        // Login Logic
        await _authRepository.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        // Register Logic
        await _authRepository.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _fullNameController.text.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Success! Welcome.")));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- LOGIC: GOOGLE SIGN IN (UPDATED) ---
  void _handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      final userCredential = await _googleAuthService.signInWithGoogle();

      if (userCredential != null && userCredential.user != null) {
        // --- FIX: Sync Data to Firestore immediately ---
        await _syncGoogleUserToFirestore(userCredential.user!);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Welcome with Google!")));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Google Sign-In cancelled")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2E7EFF), // Top Blue
              Color(0xFF9542FF), // Bottom Purple
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),

                // --- LOGO ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 8,
                    ),
                  ),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return const LinearGradient(
                            colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds);
                        },
                        child: const Icon(
                          Icons.link,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // --- APP NAME ---
                const Text(
                  "BuhayLink",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Connect. Work. Earn.",
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 30),

                // --- WHITE CARD ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      // 1. TABS (Login / Register)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildTab("Login", true),
                            _buildTab("Register", false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. INPUT FIELDS
                      if (isLogin) ...[
                        _buildTextField(
                          _emailController,
                          "Email Address",
                          Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _passwordController,
                          "Password",
                          Icons.lock_outline,
                          isPassword: true,
                        ),

                        const SizedBox(height: 12),

                        // --- FORGOT PASSWORD BUTTON ---
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              // Navigate to Forgot Password Page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(color: Color(0xFF2E7EFF)),
                            ),
                          ),
                        ),
                        // -----------------------------
                      ] else ...[
                        _buildTextField(
                          _fullNameController,
                          "Full Name",
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _emailController,
                          "Email Address",
                          Icons.email_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _phoneController,
                          "Mobile Number",
                          Icons.phone_outlined,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          _passwordController,
                          "Password",
                          Icons.lock_outline,
                          isPassword: true,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // 3. MAIN BUTTON
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  isLogin ? "Login" : "Create Account",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. GOOGLE / DIVIDER
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "or continue with",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- GOOGLE BUTTON ---
                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _handleGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: Colors.white,
                        ),
                        icon: SvgPicture.asset(
                          'assets/images/google_logo.svg',
                          height: 24,
                          width: 24,
                        ),
                        label: const Text(
                          "Google",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildTab(String title, bool isLoginTab) {
    bool isActive = isLogin == isLoginTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            isLogin = isLoginTab;
            _emailController.clear();
            _passwordController.clear();
            _fullNameController.clear();
            _phoneController.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2E7EFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7EFF)),
        ),
      ),
    );
  }
}
