import 'dart:io';
import 'package:buhay_link/features/auth/presentation/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart'; // Needed for PlatformException
import '../../data/repositories/profile_repository.dart';
import 'create_resume_page.dart'; // IMPORT THE NEW RESUME PAGE

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _repository = ProfileRepository();
  final User? user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  // --- LOGOUT LOGIC ---
  Future<void> _handleLogout() async {
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
      await _repository.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // --- PERMISSION RECOVERY DIALOG ---
  void _showPermissionDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$feature Access Denied"),
        content: Text(
          "To upload a profile picture, please enable $feature access in your phone settings.\n\n"
          "1. Go to Settings\n"
          "2. Select Apps > BuhayLink\n"
          "3. Tap Permissions\n"
          "4. Allow $feature",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // --- IMAGE PICKER LOGIC ---
  Future<void> _pickAndUploadImage() async {
    showModalBottomSheet(
      context: context,
      builder: (modalContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.of(modalContext).pop();
                try {
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) _uploadFile(File(image.path));
                } catch (e) {
                  _showPermissionDialog("Photo Library");
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.of(modalContext).pop();
                try {
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) _uploadFile(File(image.path));
                } catch (e) {
                  _showPermissionDialog("Camera");
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFile(File file) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Uploading image...")));

    try {
      String downloadUrl = await _repository.uploadProfileImage(file);
      await _repository.updateProfile(photoUrl: downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile picture updated!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
    }
  }

  // --- LOCATION LOGIC ---
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
                      foregroundColor: Colors.white,
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
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("GPS Error: $e")),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => isLoading = false);
                              }
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

  // --- OTHER DIALOGS ---
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
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF2E7EFF),
                      ),
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

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in")));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _handleLogout,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          String name = data['name'] ?? "";
          if (name.isEmpty) name = user?.displayName ?? "";
          if (name.isEmpty) name = user?.email?.split('@')[0] ?? "User";

          String email = data['email'] ?? user!.email ?? "No Email";
          String about = data['about'] ?? "No bio available.";
          String location = data['location'] ?? "No location set";
          List<dynamic> skills = data['skills'] ?? [];
          bool hasResume = data['hasResume'] == true; // Check if resume exists

          double rawRating = (data['rating'] is num)
              ? (data['rating'] as num).toDouble()
              : 0.0;
          String rating = rawRating.toStringAsFixed(1);

          String applied = (data['appliedCount']?.toString() ?? "0");

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              children: [
                // 1. EPIC HEADER SECTION
                SizedBox(
                  height: 350,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // A. Main Gradient
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 280,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                          ),
                        ),
                      ),

                      // B. Abstract Circles
                      Positioned(
                        top: -60,
                        left: -40,
                        child: Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 80,
                        right: -30,
                        child: Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 200,
                        left: 30,
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                      ),

                      // C. Profile Image
                      Positioned(
                        top: 210,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 65,
                                backgroundColor: Colors.white,
                                backgroundImage: (data['photoUrl'] != null)
                                    ? NetworkImage(data['photoUrl'])
                                    : (user?.photoURL != null
                                          ? NetworkImage(user!.photoURL!)
                                          : null),
                                child:
                                    (data['photoUrl'] == null &&
                                        user?.photoURL == null)
                                    ? const Icon(
                                        Icons.person,
                                        size: 70,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                            GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2E7EFF),
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
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 2. USER INFO
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 12), // Spacing for button
                    // --- NEW RESUME BUTTON ---
                    SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateResumePage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7EFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          elevation: 4,
                        ),
                        icon: Icon(
                          hasResume ? Icons.edit_document : Icons.add_circle,
                          color: Colors.white,
                        ),
                        label: Text(
                          hasResume ? "Edit Resume" : "Create Resume",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 3. STATS ROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        "Rating",
                        rating,
                        Icons.star_rounded,
                        Colors.amber,
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        "Applied",
                        applied,
                        Icons.work_rounded,
                        Colors.blue,
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        "Skills",
                        skills.length.toString(),
                        Icons.school_rounded,
                        Colors.purple,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 4. INFO CARDS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildInfoCard(
                        "About Me",
                        about,
                        Icons.person_outline,
                        Colors.orange,
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
                        Colors.redAccent,
                        () => _showLocationDialog(location),
                      ),
                      _buildSkillsCard(skills),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    String title,
    String content,
    IconData icon,
    Color iconColor,
    VoidCallback onEdit,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[700],
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsCard(List<dynamic> skills) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Skills",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showSkillsDialog(skills),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Icon(Icons.edit, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          skills.isEmpty
              ? const Text(
                  "No skills added yet.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7EFF).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF2E7EFF).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              color: Color(0xFF2E7EFF),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }
}
