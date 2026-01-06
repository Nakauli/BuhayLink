import 'package:flutter/material.dart';
import '../../../jobs/data/repositories/job_repository.dart';

// --- FIXED: Import the correct Dashboard Page ---
// Since DashboardPage imports this file directly, they are likely in the same folder.
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

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  String _selectedCategory = "General";
  bool _isUrgent = false;
  bool _isLoading = false;

  final List<String> _categories = [
    "General",
    "Plumbing",
    "Electrical",
    "Cleaning",
    "Technology",
    "Carpentry",
  ];

  Future<void> _handlePostJob() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _jobRepository.postJob(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
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

        // ---------------------------------------------------------
        // FIXED NAVIGATION LOGIC
        // ---------------------------------------------------------
        if (Navigator.canPop(context)) {
          // If we came from another page (e.g., pushed from Home), go back
          Navigator.pop(context);
        } else {
          // If we can't go back (e.g., Black Screen issue), FORCE go to Dashboard
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const DashboardPage(), // <--- FIXED CLASS NAME
            ),
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

  void _clearForm() {
    _titleController.clear();
    _descController.clear();
    _minBudgetController.clear();
    _maxBudgetController.clear();
    _locationController.clear();
    _durationController.clear();
    setState(() => _isUrgent = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Post a New Job",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  // Same logic for the Back Button
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const DashboardPage(), // <--- FIXED CLASS NAME
                      ),
                    );
                  }
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Job Title"),
              _buildTextField(_titleController, "Ex: Kitchen Sink Repair"),
              const SizedBox(height: 16),

              _buildLabel("Category"),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDecoration("Select Category"),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Min Budget"),
                        _buildTextField(
                          _minBudgetController,
                          "1000",
                          isNumber: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Max Budget"),
                        _buildTextField(
                          _maxBudgetController,
                          "5000",
                          isNumber: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel("Location"),
              _buildTextField(_locationController, "Ex: Quezon City"),
              const SizedBox(height: 16),

              _buildLabel("Duration / Deadline"),
              _buildTextField(_durationController, "Ex: 3 Days"),
              const SizedBox(height: 16),

              _buildLabel("Description"),
              _buildTextField(
                _descController,
                "Describe the work needed...",
                maxLines: 4,
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text(
                  "Mark as Urgent",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                activeColor: Colors.red,
                value: _isUrgent,
                onChanged: (val) => setState(() => _isUrgent = val),
              ),

              const SizedBox(height: 30),
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
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Post Job",
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
    );
  }

  // --- UI Helpers ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      validator: (val) => val == null || val.isEmpty ? "Required" : null,
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
    );
  }
}
