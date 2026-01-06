import 'package:flutter/material.dart';
import '../../../jobs/data/repositories/job_repository.dart';
import '../../data/repositories/profile_repository.dart'; // Import ProfileRepo for Location
import 'dashboard_page.dart';

class AddJobPage extends StatefulWidget {
  final bool showBackButton;

  const AddJobPage({super.key, this.showBackButton = true});

  @override
  State<AddJobPage> createState() => _AddJobPageState();
}

class _AddJobPageState extends State<AddJobPage> {
  final _formKey = GlobalKey<FormState>();
  final JobRepository _jobRepository = JobRepository();
  final ProfileRepository _profileRepository = ProfileRepository(); // For GPS

  // Controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _customCategoryController =
      TextEditingController();

  // State
  String _selectedCategory = "General";
  bool _isUrgent = false;
  bool _isLoading = false;
  bool _isLocating = false; // Loading state for GPS button
  bool _isCustomCategory = false;

  // --- UPDATED: Extensive List of Categories (Local + Online) ---
  final List<String> _categories = [
    // Common Local Works
    "General",
    "Plumbing",
    "Electrical",
    "Carpentry",
    "Cleaning / Housekeeping",
    "Painting",
    "Welding",
    "Construction / Labor",
    "Appliance Repair",
    "Gardening / Landscaping",

    // Service
    "Driver / Rider",
    "Nanny / Yaya",
    "Caregiver",
    "Cooking / Chef",
    "Massage / Therapy",
    "Hair & Beauty",
    "Delivery / Errand",
    "Event Helper / Staff",
    "Security",

    // Tech & Repair
    "Computer / Phone Repair",
    "Auto Mechanic",

    // Education
    "Tutor / Academic",
    "Music / Arts Lessons",

    // --- NEW: Online / Digital Jobs ---
    "Virtual Assistant",
    "Graphic Design",
    "Video Editing",
    "Social Media Manager",
    "Web / App Development",
    "Writing / Translation",
    "Data Entry",
    "Customer Service",
    "Accounting / Bookkeeping",

    // Fallback
    "Other",
  ];

  Future<void> _handlePostJob() async {
    if (!_formKey.currentState!.validate()) return;

    // Validation for "Other" category
    if (_isCustomCategory && _customCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please specify the category")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // If "Other" is selected, use the text from the controller
      final categoryToSave = _isCustomCategory
          ? _customCategoryController.text.trim()
          : _selectedCategory;

      await _jobRepository.postJob(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: categoryToSave,
        budgetMin: int.tryParse(_minBudgetController.text) ?? 0,
        budgetMax: int.tryParse(_maxBudgetController.text) ?? 0,
        location: _locationController.text.trim(),
        duration: _durationController.text.trim(),
        isUrgent: _isUrgent,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job Posted Successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Location Feature Logic ---
  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      // Re-using the logic from your Profile Page/Repository
      String address = await _profileRepository.getCurrentLocation();
      _locationController.text = address;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("GPS Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _clearForm() {
    _titleController.clear();
    _descController.clear();
    _minBudgetController.clear();
    _maxBudgetController.clear();
    _locationController.clear();
    _durationController.clear();
    _customCategoryController.clear();
    setState(() {
      _isUrgent = false;
      _selectedCategory = "General";
      _isCustomCategory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 1. EPIC GRADIENT HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: 50,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                if (widget.showBackButton)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                const Text(
                  "Create New Job",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // 2. FORM BODY
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Job Details"),
                    _buildModernTextField(
                      controller: _titleController,
                      label: "Job Title",
                      hint: "e.g. Graphic Designer Needed",
                      icon: Icons.work_outline,
                    ),
                    const SizedBox(height: 20),

                    _buildSectionTitle("Category"),

                    // --- Wrap layout for better UX ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return ChoiceChip(
                            label: Text(cat),
                            selected: isSelected,
                            selectedColor: const Color(0xFF2E7EFF),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            backgroundColor: Colors.grey[100],
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                  _isCustomCategory = (cat == "Other");
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ),

                    // --- LOGIC: If "Other" is selected, show this text field ---
                    if (_isCustomCategory) ...[
                      const SizedBox(height: 12),
                      _buildModernTextField(
                        controller: _customCategoryController,
                        label: "Please specify category",
                        hint: "e.g. Network Technician",
                        icon: Icons.category_outlined,
                      ),
                    ],

                    const SizedBox(height: 20),

                    _buildSectionTitle("Budget (₱) & Duration"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            controller: _minBudgetController,
                            label: "Min Budget",
                            hint: "1000",
                            // Use Wallet icon, but show Peso in text
                            icon: Icons.account_balance_wallet_outlined,
                            isNumber: true,
                            isCurrency: true, // Show ₱
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernTextField(
                            controller: _maxBudgetController,
                            label: "Max Budget",
                            hint: "5000",
                            // Use Wallet icon, but show Peso in text
                            icon: Icons.account_balance_wallet_outlined,
                            isNumber: true,
                            isCurrency: true, // Show ₱
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildModernTextField(
                      controller: _durationController,
                      label: "Duration",
                      hint: "e.g. 1 Week / Ongoing",
                      icon: Icons.access_time,
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle("Location"),
                    // --- Added GPS Button ---
                    _buildModernTextField(
                      controller: _locationController,
                      label: "Location",
                      hint: "e.g. Makati / Remote",
                      icon: Icons.location_on_outlined,
                      suffixIcon: IconButton(
                        icon: _isLocating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                color: Color(0xFF2E7EFF),
                              ),
                        onPressed: _isLocating ? null : _useCurrentLocation,
                        tooltip: "Use my current location",
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildSectionTitle("Description"),
                    _buildModernTextField(
                      controller: _descController,
                      label: "Description",
                      hint: "Describe the tasks and requirements...",
                      icon: Icons.description_outlined,
                      maxLines: 4,
                    ),

                    const SizedBox(height: 20),

                    // Urgent Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isUrgent ? Colors.red.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isUrgent
                              ? Colors.red.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: SwitchListTile(
                        title: Text(
                          "Mark as Urgent",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isUrgent ? Colors.red : Colors.black87,
                          ),
                        ),
                        secondary: Icon(
                          Icons.warning_amber_rounded,
                          color: _isUrgent ? Colors.red : Colors.grey,
                        ),
                        activeColor: Colors.red,
                        value: _isUrgent,
                        onChanged: (val) => setState(() => _isUrgent = val),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handlePostJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7EFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 5,
                          shadowColor: const Color(0xFF2E7EFF).withOpacity(0.4),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Post Job Now",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    bool isCurrency = false, // New Flag for Peso Sign
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        // --- UPDATED PREFIX LOGIC ---
        prefixIcon: isCurrency
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  "₱",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7EFF),
                  ),
                ),
              )
            : Icon(icon, color: const Color(0xFF2E7EFF)),

        // Use prefixIconConstraints to center the text properly if using Text widget
        prefixIconConstraints: isCurrency
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,

        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2E7EFF), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
