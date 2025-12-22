import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
// --- FIX: CORRECT IMPORT PATH FOR LOGIN PAGE ---
import '../../../auth/presentation/pages/login_page.dart'; 

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
  
  int _activeTabIndex = 0; 
  bool _isUploading = false; 

  // --- ACTIONS ---
  
  void _showImageSourceActionSheet(BuildContext context) {
    if (_isUploading) return; 

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2E7EFF)),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2E7EFF)),
              title: const Text('Camera'),
              onTap: () {
                Navigator.of(context).pop();
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      
      if (pickedFile == null) return;

      setState(() {
        _profileImage = File(pickedFile.path);
        _isUploading = true;
      });

      // A. Upload to Firebase Storage
      final String fileName = '${currentUser!.uid}_profile.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_images/$fileName');
      
      await storageRef.putFile(File(pickedFile.path));
      final String downloadUrl = await storageRef.getDownloadURL();

      // B. Save URL to Firestore
      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'photoUrl': downloadUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile photo updated!")));
      }

    } catch (e) {
      debugPrint("Error uploading image: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Center(child: Text("Please login to view profile"));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _signOut,
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          String name = data?['fullName'] ?? data?['firstName'] ?? currentUser?.email?.split('@')[0] ?? "User";
          String? photoUrl = data?['photoUrl']; 
          String role = "Member";

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // 1. PROFILE IMAGE PICKER
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                          image: _getImageProvider(photoUrl), 
                        ),
                        child: (_profileImage == null && photoUrl == null)
                            ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                            : null,
                      ),
                      
                      if (_isUploading)
                        const Positioned.fill(
                          child: CircularProgressIndicator(color: Color(0xFF2E7EFF)),
                        ),

                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showImageSourceActionSheet(context), 
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7EFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. USER INFO
                Column(
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(currentUser?.email ?? "", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text("Verified $role", style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),

                const SizedBox(height: 24),

                // 3. STATS ROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("Applied", data?['appliedCount']?.toString() ?? "0", Icons.work_outline),
                      _buildStatItem("Rating", data?['rating']?.toString() ?? "0.0", Icons.star_border),
                      _buildStatItem("Reviews", "0", Icons.rate_review_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 4. CUSTOM TAB BAR
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildTab("Overview", 0),
                      _buildTab("Reviews", 1),
                      _buildTab("Activity", 2),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 5. TAB CONTENT AREA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTabContent(),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- HELPERS ---
  
  DecorationImage? _getImageProvider(String? cloudUrl) {
    if (_profileImage != null) {
      return DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover);
    }
    if (cloudUrl != null && cloudUrl.isNotEmpty) {
      return DecorationImage(image: NetworkImage(cloudUrl), fit: BoxFit.cover);
    }
    return null;
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF2E7EFF), size: 28),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }

  Widget _buildTab(String text, int index) {
    bool isActive = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF2E7EFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              text, 
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
                fontSize: 13
              )
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTabIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("About Me", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              "Experienced freelancer with a passion for high-quality work. Specialized in home renovations and quick repairs. Always available for urgent tasks.",
              style: TextStyle(color: Colors.grey[600], height: 1.5),
            ),
            const SizedBox(height: 20),
            const Text("Skills", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSkillChip("Carpentry"),
                _buildSkillChip("Plumbing"),
                _buildSkillChip("Electrical"),
                _buildSkillChip("Painting"),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text("Metro Manila, Philippines", style: TextStyle(color: Colors.grey[600])),
            ]),
          ],
        );
      case 1: return Center(child: Text("No reviews yet.", style: TextStyle(color: Colors.grey[400])));
      case 2: return Center(child: Text("No recent activity.", style: TextStyle(color: Colors.grey[400])));
      default: return const SizedBox();
    }
  }

  Widget _buildSkillChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF2E7EFF).withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Color(0xFF2E7EFF), fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}