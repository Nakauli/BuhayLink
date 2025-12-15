import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PostJobPage extends StatefulWidget {
  const PostJobPage({super.key});

  @override
  State<PostJobPage> createState() => _PostJobPageState();
}

class _PostJobPageState extends State<PostJobPage> {

  // ---------------- GET CURRENT LOCATION ----------------
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _isLoading = true);

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        setState(() => _isLoading = false);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.locality}, ${place.country}";

        setState(() {
          _locationController.text = address;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- CONTROLLERS ----------------
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // ---------------- STATE ----------------
  String? _selectedCategory;
  DateTime? _selectedDate;
  bool _isUrgent = false;
  bool _isLoading = false;

  final List<String> _allSkills = [
    "Carpentry",
    "Plumbing",
    "Electrical",
    "Painting",
    "Welding",
    "Masonry",
    "Landscaping",
    "HVAC Maintenance",
    "Web Development",
    "Roofing"
  ];
  final List<String> _selectedSkills = [];

  final List<String> _categories = [
    "Home Repair",
    "Technology",
    "Events",
    "Transport",
    "Cleaning"
  ];

  // ---------------- DATE PICKER ----------------
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2026),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ---------------- SUBMIT JOB ----------------
  Future<void> _submitJob() async {
    if (_titleController.text.isEmpty ||
        _descController.text.isEmpty ||
        _minBudgetController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      await FirebaseFirestore.instance.collection('jobs').add({
        "title": _titleController.text.trim(),
        "category": _selectedCategory,
        "description": _descController.text.trim(),
        "budgetMin": int.tryParse(_minBudgetController.text) ?? 0,
        "budgetMax": int.tryParse(_maxBudgetController.text) ?? 0,
        "location": _locationController.text.trim(),
        "deadline": _selectedDate!.toIso8601String(),
        "skills": _selectedSkills,
        "isUrgent": _isUrgent,
        "postedBy": user.uid,
        "postedAt": FieldValue.serverTimestamp(),
        "status": "Open",
        "applicants": 0,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Job Posted Successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      _clearForm();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: const [
                  Text(
                    "Post a Job",
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    _buildLabel("Job Title *"),
                    _buildTextField(
                      _titleController,
                      "e.g., Need a plumber to fix kitchen sink",
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Category *"),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Description *"),
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 20),

                    _buildLabel("Budget Range (₱) *"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            _minBudgetController,
                            "Min",
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            _maxBudgetController,
                            "Max",
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 🔁 REPLACED LOCATION ROW (GPS ENABLED)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel("Location *"),
                              TextField(
                                controller: _locationController,
                                decoration: InputDecoration(
                                  hintText: "City",
                                  prefixIcon: const Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.grey,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.my_location,
                                      color: Color(0xFF2E7EFF),
                                    ),
                                    onPressed: _getCurrentLocation,
                                    tooltip: "Use my current location",
                                  ),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
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
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _selectedDate == null
                                        ? "dd/mm/yy"
                                        : "${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
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
                        final isSelected =
                            _selectedSkills.contains(skill);
                        return FilterChip(
                          label: Text(skill),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              val
                                  ? _selectedSkills.add(skill)
                                  : _selectedSkills.remove(skill);
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : _submitJob,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Post Job"),
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

  Widget _buildLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
