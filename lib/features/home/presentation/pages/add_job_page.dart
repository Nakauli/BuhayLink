import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart';     // Import Auth

class PostJobPage extends StatefulWidget {
  const PostJobPage({super.key});

  @override
  State<PostJobPage> createState() => _PostJobPageState();
}

class _PostJobPageState extends State<PostJobPage> {
  // --- CONTROLLERS ---
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // --- STATE VARIABLES ---
  String? _selectedCategory;
  DateTime? _selectedDate;
  bool _isUrgent = false;
  bool _isLoading = false; // To show loading spinner

  // Skills Data
  final List<String> _allSkills = [
    "Carpentry", "Plumbing", "Electrical", "Painting", "Welding",
    "Masonry", "Landscaping", "HVAC Maintenance", "Web Development", "Roofing"
  ];
  final List<String> _selectedSkills = [];

  // Categories
  final List<String> _categories = ["Home Repair", "Technology", "Events", "Transport", "Cleaning"];

  // --- DATE PICKER ---
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- SUBMIT JOB TO FIREBASE ---
  // ✅ PASTE THIS INSTEAD:
  Future<void> _submitJob() async {
    // 1. Check if empty
    if (_titleController.text.isEmpty || _descController.text.isEmpty || _minBudgetController.text.isEmpty || _locationController.text.isEmpty || _selectedCategory == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all required fields marked with *"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("You must be logged in.");

      // 2. Prepare Data
      final Map<String, dynamic> jobData = {
        "title": _titleController.text.trim(),
        "category": _selectedCategory,
        "description": _descController.text.trim(),
        "budgetMin": int.tryParse(_minBudgetController.text) ?? 0,
        "budgetMax": int.tryParse(_maxBudgetController.text) ?? 0,
        "location": _locationController.text.trim(),
        "deadline": _selectedDate?.toIso8601String(),
        "skills": _selectedSkills,
        "isUrgent": _isUrgent,
        "postedBy": user.uid,
        "postedAt": FieldValue.serverTimestamp(),
        "status": "Open", 
        "applicants": 0,
      };

      // 3. SEND TO FIREBASE
      await FirebaseFirestore.instance.collection('jobs').add(jobData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job Posted Successfully!"), backgroundColor: Colors.green));
        _clearForm();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descController.clear();
    _minBudgetController.clear();
    _maxBudgetController.clear();
    _locationController.clear();
    setState(() {
      _selectedCategory = null;
      _selectedDate = null;
      _selectedSkills.clear();
      _isUrgent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: const [
                  Text("Post a Job", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Fill in the details to find the right worker", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),

                    _buildLabel("Job Title *"),
                    _buildTextField(_titleController, "e.g., Need a plumber to fix kitchen sink"),
                    const SizedBox(height: 20),

                    _buildLabel("Category *"),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          hint: const Text("Select a category", style: TextStyle(color: Colors.grey)),
                          isExpanded: true,
                          items: _categories.map((String value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                          onChanged: (newValue) => setState(() => _selectedCategory = newValue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Description *"),
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: "Describe the job in detail...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 60), child: Icon(Icons.description_outlined, color: Colors.grey)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Budget Range (₱) *"),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_minBudgetController, "Min", icon: Icons.attach_money, isNumber: true)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField(_maxBudgetController, "Max", icon: Icons.attach_money, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Location *"),
                              _buildTextField(_locationController, "City", icon: Icons.location_on_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Deadline *"),
                              GestureDetector(
                                onTap: _pickDate,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(_selectedDate == null ? "dd/mm/yy" : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}", style: TextStyle(color: _selectedDate == null ? Colors.grey : Colors.black)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildLabel("Skills Required"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allSkills.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        return FilterChip(
                          label: Text(skill),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              selected ? _selectedSkills.add(skill) : _selectedSkills.remove(skill);
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFFE3F2FD),
                          labelStyle: TextStyle(color: isSelected ? const Color(0xFF2E7EFF) : Colors.grey[700], fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF2E7EFF) : Colors.transparent)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF2E7EFF),
                      title: const Text("Mark as Urgent", style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text("Get faster responses", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      value: _isUrgent,
                      onChanged: (val) => setState(() => _isUrgent = val),
                    ),
                    const SizedBox(height: 30),

                    // SUBMIT BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7EFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Post Job", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)));

  Widget _buildTextField(TextEditingController controller, String hint, {IconData? icon, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2E7EFF))),
      ),
    );
  }
}