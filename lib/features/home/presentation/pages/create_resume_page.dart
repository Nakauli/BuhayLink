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

      // Save to Firebase (You need to add this method to your repository or call Firestore directly)
      // Since I cannot edit your repo file directly here, I will use direct Firestore call for safety
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
      appBar: AppBar(
        title: const Text(
          "Build Your Resume",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle("Professional Summary"),
              _buildTextField(
                controller: _summaryController,
                hint: "Write a short bio about your professional self...",
                maxLines: 4,
              ),
              const SizedBox(height: 20),

              _buildSectionTitle("Contact Info"),
              _buildTextField(
                controller: _phoneController,
                hint: "Phone Number",
                icon: Icons.phone,
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _linkedinController,
                hint: "LinkedIn / Portfolio URL",
                icon: Icons.link,
              ),
              const SizedBox(height: 30),

              // --- EXPERIENCE SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Experience"),
                  IconButton(
                    onPressed: () => _addExperienceField(),
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF2E7EFF),
                    ),
                  ),
                ],
              ),
              ..._experienceControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                var controllers = entry.value;
                return _buildCardItem(
                  idx,
                  onRemove: () => _removeExperienceField(idx),
                  children: [
                    _buildTextField(
                      controller: controllers["title"]!,
                      hint: "Job Title",
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: controllers["company"]!,
                      hint: "Company Name",
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: controllers["year"]!,
                      hint: "Years (e.g. 2020 - 2022)",
                    ),
                  ],
                );
              }),

              const SizedBox(height: 20),

              // --- EDUCATION SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("Education"),
                  IconButton(
                    onPressed: () => _addEducationField(),
                    icon: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF2E7EFF),
                    ),
                  ),
                ],
              ),
              ..._educationControllers.asMap().entries.map((entry) {
                int idx = entry.key;
                var controllers = entry.value;
                return _buildCardItem(
                  idx,
                  onRemove: () => _removeEducationField(idx),
                  children: [
                    _buildTextField(
                      controller: controllers["school"]!,
                      hint: "School / University",
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: controllers["degree"]!,
                      hint: "Degree / Course",
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: controllers["year"]!,
                      hint: "Year Graduated",
                    ),
                  ],
                );
              }),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveResume,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7EFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
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
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      validator: (val) => val != null && val.isEmpty ? "Required" : null,
    );
  }

  Widget _buildCardItem(
    int index, {
    required VoidCallback onRemove,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: onRemove,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
