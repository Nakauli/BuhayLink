import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/presentation/pages/login_page.dart'; // Import Login Page for logout redirection


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- STATE ---
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  // NEW: Track which tab is active (0=Overview, 1=Reviews, 2=Activity, 3=Settings)
  int _activeTabIndex = 0; 

  // --- ACTIONS ---
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _profileImage = File(pickedFile.path));
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Remove all previous routes and go to Login
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserData() async {
    if (currentUser == null) throw Exception("No user logged in");
    return await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          final userData = snapshot.data?.data();
          final String username = userData?['username'] ?? "User";
          final String email = userData?['email'] ?? currentUser?.email ?? "No Email";

          return SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // 1. HEADER
                    Container(
                      height: 240, width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Profile", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.edit, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. MAIN CARD
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 110, 16, 0),
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30), bottom: Radius.circular(30)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          // User Info
                          Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 16, color: Colors.green), SizedBox(width: 4), Text("Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))]),
                          ),
                          const SizedBox(height: 24),

                          // Stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatBox("12", "Jobs Done", Icons.work_outline, Colors.blue),
                              _buildStatBox("4.5", "Rating", Icons.star_border, Colors.amber),
                              _buildStatBox("0", "Reviews", Icons.rate_review_outlined, Colors.purple),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // --- INTERACTIVE TABS ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTabItem("Overview", 0),
                              _buildTabItem("Reviews", 1),
                              _buildTabItem("Activity", 2),
                              _buildTabItem("Settings", 3),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Animated Indicator Logic could go here, for now simpler logic:
                          const Divider(height: 1, color: Colors.grey),
                          const SizedBox(height: 24),

                          // --- DYNAMIC CONTENT AREA ---
                          _buildTabContent(),
                        ],
                      ),
                    ),

                    // 3. AVATAR
                    Positioned(
                      top: 60,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.white, width: 4), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]),
                          child: Container(
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[200], image: _profileImage != null ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover) : null, gradient: _profileImage == null ? const LinearGradient(colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)]) : null),
                            child: _profileImage == null ? Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : "U", style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold))) : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- CONTENT SWITCHER ---
  Widget _buildTabContent() {
    if (_activeTabIndex == 3) {
      // --- SETTINGS VIEW (Matches image_4fd8a3.png) ---
      return Column(
        children: [
          _buildSettingsTile(Icons.settings_outlined, "Account Settings"),
          _buildSettingsTile(Icons.upload_file_outlined, "Upload Documents"),
          _buildSettingsTile(Icons.verified_outlined, "Certifications"),
          const SizedBox(height: 10),
          // Logout Button
          ListTile(
            onTap: _signOut, // <--- LOGOUT FUNCTION
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
        ],
      );
    } 
    
    // --- DEFAULT: OVERVIEW VIEW (Matches image_5131a6.png) ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("About Me", style: _headerStyle()),
        const SizedBox(height: 8),
        Text("Experienced professional ready to help with your projects. Specialized in home renovations.", style: TextStyle(color: Colors.grey[600], height: 1.5)),
        const SizedBox(height: 24),
        Text("Location", style: _headerStyle()),
        const SizedBox(height: 8),
        const Row(children: [Icon(Icons.location_on_outlined, color: Colors.grey, size: 20), SizedBox(width: 8), Text("Metro Manila", style: TextStyle(fontWeight: FontWeight.w500))]),
        const SizedBox(height: 24),
        Text("Skills", style: _headerStyle()),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [_buildSkillChip("Carpentry"), _buildSkillChip("Plumbing"), _buildSkillChip("Electrical")]),
      ],
    );
  }

  // --- HELPER WIDGETS ---
  TextStyle _headerStyle() => const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87);

  Widget _buildTabItem(String label, int index) {
    bool isActive = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: isActive ? const Color(0xFF2E7EFF) : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          if (isActive) ...[
            const SizedBox(height: 4),
            Container(width: 40, height: 3, color: const Color(0xFF2E7EFF))
          ]
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.grey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon, Color color) {
    return Container(
      width: 90, padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade100)),
      child: Column(children: [Icon(icon, color: color, size: 24), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))]),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)), child: Text(label, style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600, fontSize: 12)));
  }
}