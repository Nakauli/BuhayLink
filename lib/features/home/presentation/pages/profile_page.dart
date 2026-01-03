import 'dart:io';
import 'package:buhay_link/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/repositories/profile_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _repository = ProfileRepository();
  final User? user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  // --- NEW: LOGOUT LOGIC ---
  Future<void> _handleLogout() async {
    // 1. Confirm Logout
    bool? shouldLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // 2. Sign out from Firebase
      await _repository.signOut();

      // 3. FORCE NAVIGATION to Login Page and clear history
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false, // This removes all back buttons
        );
      }
    }
  }

  // --- 1. IMAGE PICKER LOGIC ---
  Future<void> _pickAndUploadImage() async {
    try {
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) _uploadFile(File(image.path));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) _uploadFile(File(image.path));
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _uploadFile(File file) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Uploading image...")));
    try {
      String downloadUrl = await _repository.uploadProfileImage(file);
      await _repository.updateProfile(photoUrl: downloadUrl);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Profile picture updated!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
    }
  }

  // --- 2. LOCATION LOGIC ---
  void _showLocationDialog(String currentLocation) {
    final TextEditingController controller = TextEditingController(
      text: currentLocation,
    );
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Update Location"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: "Enter City, Country",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(
                      isLoading ? "Locating..." : "Use Current Location",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() => isLoading = true);
                            try {
                              String address = await _repository
                                  .getCurrentLocation();
                              controller.text = address;
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("GPS Error: $e")),
                              );
                            } finally {
                              setState(() => isLoading = false);
                            }
                          },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _repository.updateProfile(location: controller.text);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- 3. OTHER DIALOGS (Name, About & Skills) ---
  void _showEditDialog(String title, String value, Function(String) onSave) {
    final controller = TextEditingController(text: value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: controller,
          maxLines: title == "About Me" ? 5 : 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onSave(controller.text);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showSkillsDialog(List<dynamic> currentSkills) {
    List<String> tempSkills = List<String>.from(currentSkills);
    TextEditingController skillController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Manage Skills"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: skillController,
                        decoration: const InputDecoration(
                          hintText: "Add skill",
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.blue),
                      onPressed: () {
                        if (skillController.text.isNotEmpty) {
                          setDialogState(() {
                            tempSkills.add(skillController.text);
                            skillController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: tempSkills
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          onDeleted: () =>
                              setDialogState(() => tempSkills.remove(s)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _repository.updateProfile(skills: tempSkills);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          // UPDATED: Now calls _handleLogout instead of just _repository.signOut()
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          String name = data['name'] ?? "";
          if (name.isEmpty) name = user?.displayName ?? "";
          if (name.isEmpty) name = user?.email?.split('@')[0] ?? "User";

          String email = data['email'] ?? user!.email ?? "No Email";
          String about = data['about'] ?? "No bio available.";
          String location = data['location'] ?? "No location set";
          List<dynamic> skills = data['skills'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              children: [
                const SizedBox(height: 30),
                // --- PROFILE HEADER ---
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (data['photoUrl'] != null)
                          ? NetworkImage(data['photoUrl'])
                          : (user?.photoURL != null
                                ? NetworkImage(user!.photoURL!)
                                : null),
                      child:
                          (data['photoUrl'] == null && user?.photoURL == null)
                          ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // --- NAME SECTION (WITH EDIT) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onPressed: () => _showEditDialog(
                        "Name",
                        name,
                        (val) => _repository.updateProfile(name: val),
                      ),
                    ),
                  ],
                ),

                Text(
                  email,
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Verified Member",
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- INFO CARDS ---
                _buildInfoCard(
                  "About Me",
                  about,
                  Icons.person_outline,
                  () => _showEditDialog(
                    "About Me",
                    about,
                    (val) => _repository.updateProfile(about: val),
                  ),
                ),
                _buildInfoCard(
                  "Location",
                  location,
                  Icons.location_on_outlined,
                  () => _showLocationDialog(location),
                ),
                _buildSkillsCard(skills),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI WIDGETS ---
  Widget _buildInfoCard(
    String title,
    String content,
    IconData icon,
    VoidCallback onEdit,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                onPressed: onEdit,
              ),
            ],
          ),
          const Divider(),
          Text(content, style: TextStyle(color: Colors.grey[700], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSkillsCard(List<dynamic> skills) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    "Skills",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
                onPressed: () => _showSkillsDialog(skills),
              ),
            ],
          ),
          const Divider(),
          skills.isEmpty
              ? const Text(
                  "No skills added yet.",
                  style: TextStyle(color: Colors.grey),
                )
              : Wrap(
                  spacing: 8,
                  children: skills
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          backgroundColor: Colors.blue[50],
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }
}
