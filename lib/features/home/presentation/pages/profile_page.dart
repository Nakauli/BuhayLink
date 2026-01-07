import 'dart:io';
import 'package:buhay_link/features/auth/presentation/pages/login_page.dart';
import 'package:buhay_link/features/jobs/data/repositories/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../../data/repositories/profile_repository.dart';
import 'create_resume_page.dart';

// --- IMPORTS ---

import 'applied_jobs_page.dart';
import 'hired_jobs_page.dart';
import 'saved_jobs_page.dart';
import 'my_posted_jobs_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileRepository _repository = ProfileRepository();
  final DashboardRepository _dashboardRepo = DashboardRepository();

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

  // --- PERMISSION DIALOG ---
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

  // --- IMAGE UPLOAD LOGIC ---
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Updated!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }
  }

  // --- LOCATION DIALOG ---
  void _showLocationDialog(String current) {
    final ctrl = TextEditingController(text: current);
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
                  controller: ctrl,
                  decoration: const InputDecoration(
                    hintText: "Enter City, Country",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() => isLoading = true);
                            try {
                              String address = await _repository
                                  .getCurrentLocation();
                              ctrl.text = address;
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e")),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => isLoading = false);
                            }
                          },
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
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
                onPressed: () {
                  Navigator.pop(context);
                  _repository.updateProfile(location: ctrl.text);
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
    final ctrl = TextEditingController(text: value);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $title"),
        content: TextField(
          controller: ctrl,
          maxLines: title == "About Me" ? 4 : 1,
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
              onSave(ctrl.text);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showSkillsDialog(List<dynamic> current) {
    List<String> temp = List.from(current);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text("Skills"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  hintText: "Add skill",
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (ctrl.text.isNotEmpty) {
                        setState(() {
                          temp.add(ctrl.text);
                          ctrl.clear();
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: temp
                    .map(
                      (s) => Chip(
                        label: Text(s),
                        onDeleted: () => setState(() => temp.remove(s)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _repository.updateProfile(skills: temp);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    if (user == null)
      return const Scaffold(body: Center(child: Text("Please log in")));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white, size: 20),
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
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          String name =
              data['name'] ??
              user?.displayName ??
              user?.email?.split('@')[0] ??
              "User";
          String email = data['email'] ?? user!.email ?? "";
          String about = data['about'] ?? "Tell us about yourself.";
          String location = data['location'] ?? "Add location";
          List<dynamic> skills = data['skills'] ?? [];
          bool hasResume = data['hasResume'] == true;
          bool isVerified = data['isVerified'] == true;

          final Map<String, dynamic>? resumeData = hasResume
              ? (data['resume'] as Map<String, dynamic>?)
              : null;

          String appliedCount = (data['appliedCount']?.toString() ?? "0");
          String savedCount = (data['savedCount']?.toString() ?? "0");
          String hiredCount = (data['hiredCompleted']?.toString() ?? "0");

          return SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 1. HEADER (FIXED CLICKABILITY)
                SizedBox(
                  height: 260,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // Gradient Background
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(32),
                            bottomRight: Radius.circular(32),
                          ),
                        ),
                      ),

                      // Profile Picture & Camera Button
                      Positioned(
                        top: 120,
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundColor: Colors.white,
                                  backgroundImage: (data['photoUrl'] != null)
                                      ? NetworkImage(data['photoUrl'])
                                      : null,
                                  child: (data['photoUrl'] == null)
                                      ? const Icon(
                                          Icons.person,
                                          size: 50,
                                          color: Colors.grey,
                                        )
                                      : null,
                                ),
                              ),

                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  color: const Color(0xFF2E7EFF),
                                  shape: const CircleBorder(),
                                  elevation: 4,
                                  child: InkWell(
                                    onTap: _pickAndUploadImage,
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. NAME & EDIT BUTTON (UPDATED)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // EDIT NAME BUTTON
                    GestureDetector(
                      onTap: () => _showEditDialog(
                        "Name",
                        name,
                        (val) => _repository.updateProfile(name: val),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 16,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),

                if (isVerified) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 12, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          "Verified",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),

                const SizedBox(height: 20),

                // 3. RESUME BUTTON
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateResumePage(),
                        ),
                      ),
                      icon: Icon(hasResume ? Icons.edit : Icons.add, size: 18),
                      label: Text(
                        hasResume ? "Edit My Resume" : "Create Resume",
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFF2E7EFF)),
                        foregroundColor: const Color(0xFF2E7EFF),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // 4. COMPACT STATS GRID
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildSectionHeader(
                        "My Activity",
                        Icons.person_search_rounded,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CompactStatItem(
                              label: "Applied",
                              value: appliedCount,
                              color: Colors.blue,
                              icon: Icons.send_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AppliedJobsPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CompactStatItem(
                              label: "Hired",
                              value: hiredCount,
                              color: Colors.green,
                              icon: Icons.check_circle_outline,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HiredJobsPage(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CompactStatItem(
                              label: "Saved",
                              value: savedCount,
                              color: Colors.orange,
                              icon: Icons.bookmark_border_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SavedJobsPage(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildSectionHeader(
                        "Employer Dashboard",
                        Icons.business_center_rounded,
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: _dashboardRepo.getMyPostsStream(),
                        builder: (context, jobSnap) {
                          int active = 0, hired = 0, total = 0;
                          if (jobSnap.hasData) {
                            total = jobSnap.data!.docs.length;
                            active = jobSnap.data!.docs
                                .where((d) => d['status'] == 'open')
                                .length;
                            hired = jobSnap.data!.docs
                                .where(
                                  (d) =>
                                      ['hired', 'closed'].contains(d['status']),
                                )
                                .length;
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: _CompactStatItem(
                                  label: "Active",
                                  value: "$active",
                                  color: const Color(0xFF2E7EFF),
                                  icon: Icons.campaign_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MyPostedJobsPage(
                                        title: "Active",
                                        statusFilter: ['open'],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CompactStatItem(
                                  label: "Hired",
                                  value: "$hired",
                                  color: Colors.purple,
                                  icon: Icons.handshake_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MyPostedJobsPage(
                                        title: "Hired",
                                        statusFilter: ['hired', 'closed'],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CompactStatItem(
                                  label: "Total",
                                  value: "$total",
                                  color: Colors.grey,
                                  icon: Icons.folder_open_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MyPostedJobsPage(
                                        title: "All",
                                        statusFilter: [],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 5. INFO LIST
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (hasResume && resumeData != null) ...[
                        _buildResumeCard(resumeData),
                        const Divider(height: 30),
                      ],
                      _buildProfileItem(
                        "About Me",
                        about,
                        Icons.person_outline,
                        () => _showEditDialog(
                          "About Me",
                          about,
                          (v) => _repository.updateProfile(about: v),
                        ),
                      ),
                      const Divider(height: 30),
                      _buildProfileItem(
                        "Location",
                        location,
                        Icons.location_on_outlined,
                        () => _showLocationDialog(location),
                      ),
                      const Divider(height: 30),
                      _buildSkillsItem(skills, () => _showSkillsDialog(skills)),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileItem(
    String title,
    String content,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit, size: 16, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildSkillsItem(List<dynamic> skills, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.stars_rounded, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Skills",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (skills.isEmpty)
                  Text(
                    "Add skills...",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: skills
                        .map(
                          (s) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          Icon(Icons.edit, size: 16, color: Colors.grey[300]),
        ],
      ),
    );
  }

  Widget _buildResumeCard(Map<String, dynamic> resume) {
    List<dynamic> experience = resume['experience'] ?? [];
    String summary = resume['summary'] ?? "No summary provided.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.description, size: 20, color: Colors.grey),
            SizedBox(width: 16),
            Text(
              "Resume Highlights",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 36, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              if (experience.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "• ${experience[0]['title']} at ${experience[0]['company']}",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// --- LOCAL WIDGET: COMPACT STAT ITEM (Built-in to avoid crashes) ---
class _CompactStatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _CompactStatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
