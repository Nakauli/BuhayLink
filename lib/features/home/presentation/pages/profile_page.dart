import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- STATE ---
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  final User? currentUser = FirebaseAuth.instance.currentUser; // Get logged in user

  // --- IMAGE PICKER ---
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
      // TODO: Here you would upload this file to Firebase Storage
    }
  }

  // --- FETCH USER DATA ---
  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserData() async {
    if (currentUser == null) {
      throw Exception("No user logged in");
    }
    return await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // We wrap the body in a FutureBuilder to wait for the database
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _getUserData(),
        builder: (context, snapshot) {
          
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error State
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 3. Data Ready!
          final userData = snapshot.data?.data();
          final String username = userData?['username'] ?? "No Name";
          final String email = userData?['email'] ?? currentUser?.email ?? "No Email";

          return SingleChildScrollView(
            child: Column(
              children: [
                // --- HEADER + CARD STACK ---
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Header Background
                    Container(
                      height: 240,
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
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

                    // Main Profile Card
                    Container(
                      margin: const EdgeInsets.only(top: 100, left: 24, right: 24),
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          // --- REAL USERNAME & EMAIL ---
                          Text(username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                          const SizedBox(height: 12),
                          
                          // Verified Badge (Static for now)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                SizedBox(width: 4),
                                Text("Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Stats Row (Mock Data for now)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatBox("12", "Jobs Done", Icons.work_outline, Colors.blue),
                              _buildStatBox("4.5", "Rating", Icons.star_border, Colors.blue),
                              _buildStatBox("0", "Reviews", Icons.emoji_events_outlined, Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Tabs
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text("Overview", style: TextStyle(color: Color(0xFF2E7EFF), fontWeight: FontWeight.bold, fontSize: 14)),
                               Text("Reviews", style: TextStyle(color: Colors.grey, fontSize: 14)),
                               Text("Activity", style: TextStyle(color: Colors.grey, fontSize: 14)),
                               Text("Settings", style: TextStyle(color: Colors.grey, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(width: 65, height: 3, color: const Color(0xFF2E7EFF)),
                          ),
                          const Divider(height: 1, color: Colors.grey),
                          
                          const SizedBox(height: 24),

                          // About Me
                          Align(alignment: Alignment.centerLeft, child: Text("About Me", style: _headerStyle())),
                          const SizedBox(height: 8),
                          Text(
                            "This is your profile description. You can edit this in settings later.",
                            style: TextStyle(color: Colors.grey[600], height: 1.5, fontSize: 14),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Location
                          Align(alignment: Alignment.centerLeft, child: Text("Location", style: _headerStyle())),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                              SizedBox(width: 8),
                              Text("Metro Manila", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
                            ],
                          ),

                          const SizedBox(height: 24),
                          
                          // Skills
                          Align(alignment: Alignment.centerLeft, child: Text("Skills", style: _headerStyle())),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildSkillChip("Carpentry"),
                              _buildSkillChip("Plumbing"),
                            ],
                          ),

                           const SizedBox(height: 24),
                          
                          // Hourly Rate
                          Align(alignment: Alignment.centerLeft, child: Text("Hourly Rate", style: _headerStyle())),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(Icons.attach_money, color: Colors.grey, size: 20),
                              SizedBox(width: 8),
                              Text("₱300 - ₱500/hour", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 3. THE AVATAR (Interactive)
                    Positioned(
                      top: 50,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey[200],
                              image: _profileImage != null
                                  ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                                  : null,
                              gradient: _profileImage == null 
                                ? const LinearGradient(colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)]) 
                                : null,
                            ),
                            child: _profileImage == null 
                              ? Center(child: Text(username.isNotEmpty ? username[0].toUpperCase() : "U", style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold)))
                              : null,
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

  // --- HELPER WIDGETS ---
  
  TextStyle _headerStyle() => const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87);

  Widget _buildStatBox(String value, String label, IconData icon, Color color) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade50),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}