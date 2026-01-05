import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1. IMPORT YOUR WIDGETS
import '../../../../widgets/job_card.dart'; // Ensure path is correct
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filters",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Location Input
                    const Text(
                      "Location",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: "Enter location",
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Budget Input
                    const Text(
                      "Budget Range (₱)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minBudgetController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "Min",
                              prefixIcon: const Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maxBudgetController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "Max",
                              prefixIcon: const Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Job Status
                    const Text(
                      "Job Status",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _statusOptions.map((status) {
                          bool isSelected = _selectedStatus == status;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => _selectedStatus = status),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2E7EFF)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
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
                      height: 50,
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Apply Filters",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Clear Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            _locationController.clear();
                            _minBudgetController.clear();
                            _maxBudgetController.clear();
                            _selectedStatus = "All";
                          });
                        },
                        child: const Text(
                          "Clear All Filters",
                          style: TextStyle(color: Colors.grey),
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

  // --- 3. FILTER LOGIC (UPDATED) ---
  List<DocumentSnapshot> _filterSnapshot(List<DocumentSnapshot> docs) {
    // 1. Get Current User ID
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // --- LOGIC FIX: Hide My Own Posts ---
      // If I am NOT in Employer Mode (I'm a seeker),
      // check if I posted this job. If yes, return false (hide it).
      if (!widget.isEmployerMode && currentUid != null) {
        final String posterId = data['postedBy'] ?? data['posterId'] ?? "";
        if (posterId == currentUid) {
          return false; // HIDE THIS CARD
        }
      }
      // ------------------------------------

      // A. Text Search
      final title = data['title']?.toString().toLowerCase() ?? '';
      final desc = data['description']?.toString().toLowerCase() ?? '';
      final category = data['category']?.toString().toLowerCase() ?? '';
      final queryLower = _searchQuery.toLowerCase();

      bool matchesSearch =
          title.contains(queryLower) ||
          desc.contains(queryLower) ||
          category.contains(queryLower);

      // B. Category Chip
      bool matchesCategory = true;
      if (_selectedCategoryIndex != 0) {
        String selectedCat = _categories[_selectedCategoryIndex].toLowerCase();
        matchesCategory = category.contains(selectedCat);
      }

      // C. Location Filter
      bool matchesLocation = true;
      if (_locationQuery.isNotEmpty) {
        final loc = data['location']?.toString().toLowerCase() ?? '';
        matchesLocation = loc.contains(_locationQuery.toLowerCase());
      }

      // D. Budget Filter
      bool matchesBudget = true;
      double jobMin = (data['budgetMin'] ?? 0).toDouble();
      double jobMax = (data['budgetMax'] ?? 0).toDouble();

      if (_minBudget != null && jobMax < _minBudget!) matchesBudget = false;
      if (_maxBudget != null && jobMin > _maxBudget!) matchesBudget = false;

      // E. Status Filter
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

    // If I am in Employer Mode, I ONLY want to see my posts.
    if (widget.isEmployerMode) {
      jobsQuery = jobsQuery.where('postedBy', isEqualTo: uid);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.isEmployerMode ? "Find My Posts" : "Search Jobs",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: widget.isEmployerMode
                            ? "Search my posts..."
                            : "Search jobs...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7EFF),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7EFF).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.tune, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // --- CATEGORY CHIPS ---
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  bool isSelected = _selectedCategoryIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2E7EFF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // --- RESULTS ---
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

                  // This is where we filter out your own posts (logic is in _filterSnapshot)
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
                          "${filteredDocs.length} jobs found",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final doc = filteredDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final jobId = doc.id;

                            // 4. MAP DATA TO REUSE JOB CARD
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
                              "rating":
                                  data['posterRating']?.toString() ?? "New",
                              "posterName": data['posterName'] ?? "Employer",
                              "posterPhoto": data['posterPhoto'],
                            };

                            // 5. USE THE REUSABLE WIDGET
                            return JobCard(
                              job: jobMap,
                              // ALWAYS SHOW STATUS (Open/Completed/Ongoing)
                              showStatus: true,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => JobDetailsPage(
                                      job: jobMap,
                                      jobId: jobId,
                                    ),
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            widget.isEmployerMode ? "No posts found." : "No jobs found.",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
