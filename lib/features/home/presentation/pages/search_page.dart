import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// IMPORT YOUR WIDGETS
import '../../../../widgets/job_card.dart';
import 'job_details_page.dart';

class SearchPage extends StatefulWidget {
  final bool isEmployerMode;

  const SearchPage({super.key, required this.isEmployerMode});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // --- 1. SEARCH & FILTER STATE ---
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _minBudgetController = TextEditingController();
  final TextEditingController _maxBudgetController = TextEditingController();

  int _selectedCategoryIndex = 0;
  String _searchQuery = "";
  String _locationQuery = "";
  double? _minBudget;
  double? _maxBudget;
  String _selectedStatus = "All";

  final List<String> _categories = [
    "All Categories",
    "Plumbing",
    "Carpentry",
    "Painting",
    "Electrical",
    "Cleaning",
    "General",
  ];
  final List<String> _statusOptions = ["All", "Open", "In Progress", "Hired"];

  // --- 2. SHOW FILTER MODAL ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 16,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Refine Search",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _locationController.clear();
                              _minBudgetController.clear();
                              _maxBudgetController.clear();
                              _selectedStatus = "All";
                            });
                          },
                          child: const Text(
                            "Reset",
                            style: TextStyle(color: Color(0xFF2E7EFF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Location Input
                    _buildModernLabel("Location"),
                    _buildModernTextField(
                      controller: _locationController,
                      hint: "e.g. Quezon City",
                      icon: Icons.location_on_outlined,
                    ),
                    const SizedBox(height: 20),

                    // Budget Input
                    _buildModernLabel("Budget Range (₱)"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModernTextField(
                            controller: _minBudgetController,
                            hint: "Min",
                            icon: Icons.attach_money,
                            isNumber: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModernTextField(
                            controller: _maxBudgetController,
                            hint: "Max",
                            icon: Icons.attach_money,
                            isNumber: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Job Status
                    _buildModernLabel("Job Status"),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusOptions.map((status) {
                          bool isSelected = _selectedStatus == status;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => _selectedStatus = status),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2E7EFF)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF2E7EFF)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _locationQuery = _locationController.text;
                            _minBudget = double.tryParse(
                              _minBudgetController.text,
                            );
                            _maxBudget = double.tryParse(
                              _maxBudgetController.text,
                            );
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7EFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 5,
                          shadowColor: const Color(0xFF2E7EFF).withOpacity(0.4),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: const Color(0xFF2E7EFF), size: 20),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7EFF), width: 1.5),
        ),
      ),
    );
  }

  // --- 3. FILTER LOGIC ---
  List<DocumentSnapshot> _filterSnapshot(List<DocumentSnapshot> docs) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      if (!widget.isEmployerMode && currentUid != null) {
        final String posterId = data['postedBy'] ?? data['posterId'] ?? "";
        if (posterId == currentUid) {
          return false;
        }
      }

      final title = data['title']?.toString().toLowerCase() ?? '';
      final desc = data['description']?.toString().toLowerCase() ?? '';
      final category = data['category']?.toString().toLowerCase() ?? '';
      final queryLower = _searchQuery.toLowerCase();

      bool matchesSearch =
          title.contains(queryLower) ||
          desc.contains(queryLower) ||
          category.contains(queryLower);

      bool matchesCategory = true;
      if (_selectedCategoryIndex != 0) {
        String selectedCat = _categories[_selectedCategoryIndex].toLowerCase();
        matchesCategory = category.contains(selectedCat);
      }

      bool matchesLocation = true;
      if (_locationQuery.isNotEmpty) {
        final loc = data['location']?.toString().toLowerCase() ?? '';
        matchesLocation = loc.contains(_locationQuery.toLowerCase());
      }

      bool matchesBudget = true;
      double jobMin = (data['budgetMin'] ?? 0).toDouble();
      double jobMax = (data['budgetMax'] ?? 0).toDouble();

      if (_minBudget != null && jobMax < _minBudget!) matchesBudget = false;
      if (_maxBudget != null && jobMin > _maxBudget!) matchesBudget = false;

      bool matchesStatus = true;
      if (_selectedStatus != "All") {
        String status = data['status']?.toString().toLowerCase() ?? 'open';
        matchesStatus = status == _selectedStatus.toLowerCase();
      }

      return matchesSearch &&
          matchesCategory &&
          matchesLocation &&
          matchesBudget &&
          matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    Query jobsQuery = FirebaseFirestore.instance
        .collection('jobs')
        .orderBy('postedAt', descending: true);

    if (widget.isEmployerMode) {
      jobsQuery = jobsQuery.where('postedBy', isEqualTo: uid);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // --- EPIC HEADER & SEARCH STACK ---
          Container(
            height: 220,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Gradient Background
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
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 60,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEmployerMode
                              ? "Find My Posts"
                              : "Search Jobs",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isEmployerMode
                              ? "Manage your active listings"
                              : "Find your next opportunity",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Floating Search Bar
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            decoration: InputDecoration(
                              hintText: widget.isEmployerMode
                                  ? "Search posts..."
                                  : "Search title or skills...",
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF2E7EFF),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF2E7EFF),
                          ),
                          onPressed: _showFilterModal,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- CATEGORY CHIPS (FIXED CUT SHADOW) ---
          const SizedBox(height: 10),
          SizedBox(
            height: 60, // Increased height to prevent shadow clipping
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ), // Added vertical padding
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none, // Allow shadow to overflow
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                bool isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey.shade300),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF2E7EFF).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // --- RESULTS LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: jobsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final allDocs = snapshot.data!.docs;
                final filteredDocs = _filterSnapshot(allDocs);

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        "${filteredDocs.length} ${filteredDocs.length == 1 ? 'Job' : 'Jobs'} Found",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final jobId = doc.id;

                          final Map<String, dynamic> jobMap = {
                            "jobId": jobId,
                            "title": data['title'] ?? "Untitled",
                            "description":
                                data['description'] ?? "No description",
                            "tag": data['category'] ?? "General",
                            "price":
                                "₱${data['budgetMin'] ?? 0} - ₱${data['budgetMax'] ?? 0}",
                            "location": data['location'] ?? "Remote",
                            "duration": data['duration'] ?? "3 days",
                            "applicants": data['applicants'] ?? 0,
                            "isUrgent": data['isUrgent'] ?? false,
                            "status": data['status'] ?? "open",
                            "posterId": data['postedBy'] ?? "",
                            "rating": data['posterRating']?.toString() ?? "New",
                            "posterName": data['posterName'] ?? "Employer",
                            "posterPhoto": data['posterPhoto'],
                          };

                          return JobCard(
                            job: jobMap,
                            showStatus: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JobDetailsPage(job: jobMap, jobId: jobId),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 50,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No jobs found",
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your filters or search query.",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
