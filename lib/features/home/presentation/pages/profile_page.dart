import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Import the package you just added

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // --- STATE FOR IMAGE UPLOAD ---
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- STACK FOR HEADER + OVERLAPPING CARD ---
            Stack(
              clipBehavior: Clip.none, // Allows the card to overflow
              alignment: Alignment.center,
              children: [
                // 1. Purple Gradient Header
                Container(
                  height: 220,
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

                // 2. The White Profile Card
                Container(
                  margin: const EdgeInsets.only(top: 100, left: 24, right: 24), // Push it down
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: Column(
                    children: [
                      // --- AVATAR (Clickable) ---
                      GestureDetector(
                        onTap: _pickImage, // <--- Tapping opens gallery
                        child: Stack(
                          children: [
                            Container(
                              width: 100, height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                image: _profileImage != null
                                    ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover)
                                    : null, // No image yet
                                gradient: _profileImage == null 
                                  ? const LinearGradient(colors: [Color(0xFF8EC5FC), Color(0xFFE0C3FC)]) 
                                  : null,
                              ),
                              child: _profileImage == null 
                                ? const Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 30)) 
                                : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Name & Email
                      const Text("John Doe", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("john@example.com", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      const SizedBox(height: 8),
                      
                      // Verified Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text("Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- STATS ROW ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem("12", "Jobs Done", Icons.work_outline, Colors.blue),
                          _buildStatItem("4.5", "Rating", Icons.star_border, Colors.amber),
                          _buildStatItem("0", "Reviews", Icons.rate_review_outlined, Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- TABS (Visual Only) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTabItem("Overview", true),
                          _buildTabItem("Reviews", false),
                          _buildTabItem("Activity", false),
                          _buildTabItem("Settings", false),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress Bar for Tab
                      Align(
                         alignment: Alignment.centerLeft,
                         child: Container(width: 60, height: 3, color: const Color(0xFF2E7EFF)),
                      ),
                      
                      const SizedBox(height: 24),

                      // --- DETAILS SECTION ---
                      Align(alignment: Alignment.centerLeft, child: Text("About Me", style: _headerStyle())),
                      const SizedBox(height: 8),
                      Text(
                        "Experienced professional ready to help with your projects. Specialized in home renovations and quick repairs.",
                        style: TextStyle(color: Colors.grey[600], height: 1.5),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      Align(alignment: Alignment.centerLeft, child: Text("Location", style: _headerStyle())),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: Colors.grey, size: 20),
                          SizedBox(width: 8),
                          Text("Metro Manila", style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),

                      const SizedBox(height: 24),
                      
                      Align(alignment: Alignment.centerLeft, child: Text("Skills", style: _headerStyle())),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildSkillChip("Carpentry"),
                          _buildSkillChip("Plumbing"),
                          _buildSkillChip("Electrical"),
                        ],
                      ),

                       const SizedBox(height: 24),
                      
                      Align(alignment: Alignment.centerLeft, child: Text("Hourly Rate", style: _headerStyle())),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text("₱300 - ₱500/hour", style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40), // Bottom spacing
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  
  TextStyle _headerStyle() => const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87);

  Widget _buildStatItem(String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildTabItem(String label, bool isActive) {
    return Text(
      label,
      style: TextStyle(
        color: isActive ? const Color(0xFF2E7EFF) : Colors.grey,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}