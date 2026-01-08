import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/profile_repository.dart';

class CreateResumePage extends StatefulWidget {
  const CreateResumePage({super.key});

  @override
  State<CreateResumePage> createState() => _CreateResumePageState();
}

class _CreateResumePageState extends State<CreateResumePage> {
  final _formKey = GlobalKey<FormState>();
  // ignore: unused_field
  final _repository = ProfileRepository();
  bool _isLoading = false;

  // Controllers
  final _summaryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();

  // Dynamic Lists
  List<Map<String, TextEditingController>> _experienceControllers = [];
  List<Map<String, TextEditingController>> _educationControllers = [];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && doc.data()!.containsKey('resume')) {
      final data = doc.data()!['resume'] as Map<String, dynamic>;

      setState(() {
        _summaryController.text = data['summary'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _linkedinController.text = data['linkedin'] ?? '';

        // Load Experience
        if (data['experience'] != null) {
          for (var item in data['experience']) {
            _addExperienceField(
              title: item['title'],
              company: item['company'],
              year: item['year'],
            );
          }
        }

        // Load Education
        if (data['education'] != null) {
          for (var item in data['education']) {
            _addEducationField(
              school: item['school'],
              degree: item['degree'],
              year: item['year'],
            );
          }
        }
      });
    } else {
      // Add one empty slot by default if new
      _addExperienceField();
      _addEducationField();
    }
  }

  void _addExperienceField({String? title, String? company, String? year}) {
    setState(() {
      _experienceControllers.add({
        "title": TextEditingController(text: title),
        "company": TextEditingController(text: company),
        "year": TextEditingController(text: year),
      });
    });
  }

  void _addEducationField({String? school, String? degree, String? year}) {
    setState(() {
      _educationControllers.add({
        "school": TextEditingController(text: school),
        "degree": TextEditingController(text: degree),
        "year": TextEditingController(text: year),
      });
    });
  }

  void _removeExperienceField(int index) {
    setState(() {
      _experienceControllers.removeAt(index);
    });
  }

  void _removeEducationField(int index) {
    setState(() {
      _educationControllers.removeAt(index);
    });
  }

  Future<void> _saveResume() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Compile Data
      List<Map<String, String>> experienceData = _experienceControllers.map((
        e,
      ) {
        return {
          "title": e["title"]!.text,
          "company": e["company"]!.text,
          "year": e["year"]!.text,
        };
      }).toList();

      List<Map<String, String>> educationData = _educationControllers.map((e) {
        return {
          "school": e["school"]!.text,
          "degree": e["degree"]!.text,
          "year": e["year"]!.text,
        };
      }).toList();

      final resumeMap = {
        "summary": _summaryController.text,
        "phone": _phoneController.text,
        "linkedin": _linkedinController.text,
        "experience": experienceData,
        "education": educationData,
        "updatedAt": DateTime.now().toIso8601String(),
      };

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'resume': resumeMap,
          'hasResume': true,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Resume saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // [UX FIX] Used CustomScrollView with SliverAppBar so the header pins
      // and doesn't make text unreadable when scrolling up.
      body: CustomScrollView(
        slivers: [
          // 1. SLIVER APP BAR (The Gradient Header)
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true, // Keeps "Build Your Resume" visible
            backgroundColor: const Color(0xFF2E7EFF), // Fallback color
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                  ),
                ),
              ),
            ),
            title: const Text(
              "Build Your Resume",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 2. THE FORM CONTENT
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                  children: [
                    const Text(
                      "Craft your professional profile to stand out.",
                      // [UX FIX] Grey color ensures readability on white background
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 20),

                    // --- SECTION A: PERSONAL INFO ---
                    _buildCardContainer(
                      title: "Personal Info",
                      icon: Icons.person,
                      color: Colors.orange,
                      children: [
                        _buildModernTextField(
                          controller: _summaryController,
                          label: "Professional Summary",
                          hint: "Write a short bio...",
                          icon: Icons.description_outlined,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _phoneController,
                          label: "Phone Number",
                          hint: "+63 912 345 6789",
                          icon: Icons.phone_android_rounded,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _linkedinController,
                          label: "Portfolio / LinkedIn",
                          hint: "https://linkedin.com/in/you",
                          icon: Icons.link_rounded,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION B: EXPERIENCE ---
                    _buildSectionHeader("Experience", Icons.work_rounded),
                    ..._experienceControllers.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var controllers = entry.value;
                      return _buildDismissibleCard(
                        idx,
                        onRemove: () => _removeExperienceField(idx),
                        children: [
                          _buildModernTextField(
                            controller: controllers["title"]!,
                            label: "Job Title",
                            hint: "e.g. Flutter Developer",
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildModernTextField(
                            controller: controllers["company"]!,
                            label: "Company",
                            hint: "e.g. Tech Solutions Inc.",
                            icon: Icons.business_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildModernTextField(
                            controller: controllers["year"]!,
                            label: "Years Active",
                            hint: "e.g. 2021 - Present",
                            icon: Icons.calendar_today_rounded,
                          ),
                        ],
                      );
                    }),
                    _buildAddButton(
                      "Add Position",
                      _addExperienceField,
                      Colors.blue,
                    ),

                    const SizedBox(height: 24),

                    // --- SECTION C: EDUCATION ---
                    _buildSectionHeader("Education", Icons.school_rounded),
                    ..._educationControllers.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var controllers = entry.value;
                      return _buildDismissibleCard(
                        idx,
                        onRemove: () => _removeEducationField(idx),
                        children: [
                          _buildModernTextField(
                            controller: controllers["school"]!,
                            label: "School / University",
                            hint: "e.g. University of Santo Tomas",
                            icon: Icons.account_balance_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildModernTextField(
                            controller: controllers["degree"]!,
                            label: "Degree / Course",
                            hint: "e.g. BS Computer Science",
                            icon: Icons.school_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildModernTextField(
                            controller: controllers["year"]!,
                            label: "Year Graduated",
                            hint: "e.g. 2023",
                            icon: Icons.calendar_today_rounded,
                          ),
                        ],
                      );
                    }),
                    _buildAddButton(
                      "Add Education",
                      _addEducationField,
                      Colors.purple,
                    ),

                    const SizedBox(height: 40),

                    // --- SAVE BUTTON ---
                    Container(
                      width: double.infinity,
                      height: 55,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7EFF).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveResume,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Save Resume",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[700], size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDismissibleCard(
    int index, {
    required VoidCallback onRemove,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "Remove",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2E7EFF)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
          validator: (val) => val != null && val.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildAddButton(String text, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, color: color),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
