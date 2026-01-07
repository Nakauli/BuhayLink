import 'package:buhay_link/features/home/presentation/pages/dashboard_page.dart';
import 'package:buhay_link/features/home/presentation/pages/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/google_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;

  final AuthRepository _authRepository = AuthRepository();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  Future<void> _syncGoogleUserToFirestore(User user) async {
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName ?? "User",
        'photoUrl': user.photoURL ?? "",
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

  void _submitForm() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await _authRepository.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await _authRepository.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _fullNameController.text.trim(),
        );
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
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

  void _handleGoogleSignIn() async {
    setState(() => isLoading = true);
    try {
      final userCredential = await _googleAuthService.signInWithGoogle();
      if (userCredential?.user != null) {
        await _syncGoogleUserToFirestore(userCredential!.user!);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
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

        // ✅ SMOOTH GRADIENT (NO HARD CUT)
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F9FF), // soft white-blue (logo clarity)
              Color(0xFFEAF0FF),
              Color(0xFF2E7EFF), // brand blue
              Color(0xFF9542FF), // brand purple
            ],
            stops: [0.0, 0.25, 0.65, 1.0],
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // --- LOGO (CLEAN, EMPHASIZED) ---
                Image.asset('assets/images/logo.png', width: 170),

                const SizedBox(height: 40),

                // --- FLOATING CARD ---
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Tabs
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            _buildTab("Login", true),
                            _buildTab("Register", false),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

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
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Color(0xFF2E7EFF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
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

                      // Main button
                      Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  isLogin ? "Login" : "Create Account",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "or continue with",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),

                      const SizedBox(height: 20),

                      OutlinedButton.icon(
                        onPressed: isLoading ? null : _handleGoogleSignIn,
                        icon: SvgPicture.asset(
                          'assets/images/google_logo.svg',
                          height: 24,
                        ),
                        label: const Text(
                          "Google",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String title, bool isLoginTab) {
    final isActive = isLogin == isLoginTab;
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
            borderRadius: BorderRadius.circular(12),
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
        prefixIcon: Icon(icon, color: Colors.grey[400]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7EFF)),
        ),
      ),
    );
  }
}
