import 'package:flutter/material.dart';
import '../../data/auth_service.dart';
import 'package:buhay_link/features/home/presentation/pages/dashboard_page.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // --- CONTROLLERS ---
  final TextEditingController _fullNameController = TextEditingController(); // For "Full Name"
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();    // For "Mobile Number"
  final TextEditingController _passwordController = TextEditingController();
  
  // --- STATE ---
  bool isLogin = true; 
  bool isLoading = false;
  final AuthService _authService = AuthService();

  // --- LOGIC ---
  void _submitForm() async {
    setState(() => isLoading = true);

    try {
      if (isLogin) {
        // --- LOGIN: Email & Password ---
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // --- REGISTER: Email, Password, Name (and Phone if you add it to DB later) ---
        // Note: Currently AuthService only accepts username/email/pass. 
        // We pass "Full Name" as the username.
        await _authService.signUp(
          username: _fullNameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Success! Welcome.")),
        );
      }
    } catch (e) {
      // If successful, navigate to Dashboard
      if (mounted) {
        // 1. Show success message
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Success! Welcome.")),
    );

  // 2. NAVIGATE TO DASHBOARD!
  Navigator.pushReplacement(
    context, 
    MaterialPageRoute(builder: (_) => const DashboardPage())
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
              Color(0xFF2E7EFF), // Blue (Top)
              Color(0xFF9542FF), // Purple (Bottom)
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
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 8),
                  ),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text("JobPool", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                const Text("Connect. Work. Earn.", style: TextStyle(fontSize: 14, color: Colors.white70)),
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
                      // 1. TABS
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            _buildTab("Login", true),
                            _buildTab("Register", false),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. FORM FIELDS
                      if (isLogin) ...[
                        // --- LOGIN PAGE ---
                        _buildTextField(_emailController, "Email Address", Icons.email_outlined),
                        const SizedBox(height: 16),
                        _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
                        
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text("Forgot Password?", style: TextStyle(color: Color(0xFF2E7EFF))),
                          ),
                        ),
                      ] else ...[
                        // --- REGISTER PAGE ---
                        _buildTextField(_fullNameController, "Full Name", Icons.person_outline),
                        const SizedBox(height: 16),
                        _buildTextField(_emailController, "Email Address", Icons.email_outlined),
                        const SizedBox(height: 16),
                        _buildTextField(_phoneController, "Mobile Number", Icons.phone_outlined), // Visual only for now
                        const SizedBox(height: 16),
                        _buildTextField(_passwordController, "Password", Icons.lock_outline, isPassword: true),
                      ],
                      
                      const SizedBox(height: 24),

                      // 3. MAIN BUTTON
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                                isLogin ? "Login" : "Create Account", // Matches your screenshot text
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 4. GOOGLE SECTION
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text("or continue with", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        // Replace with Image.asset('assets/google_logo.png') for real logo
                        icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.black),
                        label: const Text("Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
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

  // --- HELPERS ---
  Widget _buildTab(String title, bool isLoginTab) {
    bool isActive = isLogin == isLoginTab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            isLogin = isLoginTab;
            // Clear inputs when switching
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
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