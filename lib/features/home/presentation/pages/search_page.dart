import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

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
  String _selectedStatus = "All"; // "All", "Open", "In Progress"

  final List<String> _categories = ["All Categories", "Plumbing", "Carpentry", "Painting", "Electrical", "Cleaning"];
  final List<String> _statusOptions = ["All", "Open", "In Progress"];

  // --- 2. DATA (Updated with 'status' for filtering) ---
  final List<Map<String, dynamic>> _allJobs = [
    {
      "title": "Need experienced plumber for kitchen renovation",
      "tags": "Plumbing • Pipe Installation",
      "price": "₱5,000 - ₱8,000",
      "location": "Quezon City",
      "user": "Maria Santos",
      "rating": "4.8",
      "applicants": "8 applicants",
      "time": "3 days",
      "isUrgent": true,
      "status": "Open",
    },
    {
      "title": "Carpenter needed for custom furniture",
      "tags": "Carpentry • Furniture Making",
      "price": "₱12,000 - ₱15,000",
      "location": "Makati City",
      "user": "Juan dela Cruz",
      "rating": "4.5",
      "applicants": "12 applicants",
      "time": "1 week",
      "isUrgent": false,
      "status": "Open",
    },
    {
      "title": "House painting - interior walls",
      "tags": "Painting • Surface Preparation",
      "price": "₱8,000 - ₱10,000",
      "location": "Pasig City",
      "user": "Ana Reyes",
      "rating": "4.9",
      "applicants": "15 applicants",
      "time": "5 days",
      "isUrgent": false,
      "status": "In Progress",
    },
    {
      "title": "Electrical wiring for new construction",
      "tags": "Electrical Wiring • Safety",
      "price": "₱25,000 - ₱30,000",
      "location": "Taguig City",
      "user": "Robert Garcia",
      "rating": "4.7",
      "applicants": "6 applicants",
      "time": "2 weeks",
      "isUrgent": false,
      "status": "Open",
    },
    {
      "title": "Garden landscaping and maintenance",
      "tags": "Landscaping • Garden Design",
      "price": "₱6,000 - ₱9,000",
      "location": "Mandaluyong",
      "user": "Lisa Tan",
      "rating": "4.6",
      "applicants": "9 applicants",
      "time": "10 days",
      "isUrgent": false,
      "status": "In Progress",
    },
     {
      "title": "AC repair and maintenance",
      "tags": "AC Repair • HVAC Maintenance",
      "price": "₱3,000 - ₱5,000",
      "location": "Manila City",
      "user": "Pedro Martinez",
      "rating": "4.4",
      "applicants": "5 applicants",
      "time": "2 days",
      "isUrgent": true,
      "status": "Open",
    },
  ];

  // --- 3. FILTER LOGIC ---
  List<Map<String, dynamic>> _getFilteredJobs() {
    return _allJobs.where((job) {
      // A. Text Search (Title/Tags)
      final titleLower = job['title'].toString().toLowerCase();
      final tagsLower = job['tags'].toString().toLowerCase();
      final queryLower = _searchQuery.toLowerCase();
      bool matchesSearch = titleLower.contains(queryLower) || tagsLower.contains(queryLower);

      // B. Category Chip
      bool matchesCategory = true;
      if (_selectedCategoryIndex != 0) {
        String selectedCat = _categories[_selectedCategoryIndex];
        matchesCategory = tagsLower.contains(selectedCat.toLowerCase()) || 
                          titleLower.contains(selectedCat.toLowerCase().substring(0, 4)); // loose match
      }

      // C. Location Filter
      bool matchesLocation = true;
      if (_locationQuery.isNotEmpty) {
        matchesLocation = job['location'].toString().toLowerCase().contains(_locationQuery.toLowerCase());
      }

      // D. Budget Filter
      bool matchesBudget = true;
      if (_minBudget != null || _maxBudget != null) {
        // Parse "₱5,000 - ₱8,000" -> 5000
        String priceStr = job['price'].toString().replaceAll('₱', '').replaceAll(',', '');
        double jobMinPrice = double.tryParse(priceStr.split('-')[0].trim()) ?? 0;
        
        if (_minBudget != null && jobMinPrice < _minBudget!) matchesBudget = false;
        if (_maxBudget != null && jobMinPrice > _maxBudget!) matchesBudget = false;
      }

      // E. Status Filter
      bool matchesStatus = true;
      if (_selectedStatus != "All") {
        matchesStatus = job['status'] == _selectedStatus;
      }

      return matchesSearch && matchesCategory && matchesLocation && matchesBudget && matchesStatus;
    }).toList();
  }

  // --- 4. SHOW FILTER MODAL ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allow full height if needed
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder( // Needed to update state INSIDE the modal
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 24, left: 24, right: 24, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 24 // Handle keyboard
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Filters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Location Input
                    const Text("Location", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        hintText: "Enter location",
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Budget Input
                    const Text("Budget Range (₱)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minBudgetController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: "Min",
                              prefixIcon: const Icon(Icons.attach_money, size: 18, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
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
                              prefixIcon: const Icon(Icons.attach_money, size: 18, color: Colors.grey),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Job Status Chips
                    const Text("Job Status", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      children: _statusOptions.map((status) {
                        bool isSelected = _selectedStatus == status;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() => _selectedStatus = status); // Update inside modal
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2E7EFF) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),

                    // Action Buttons
                    Column(
                      children: [
                         // Apply Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              // Save values to main state
                              setState(() {
                                _locationQuery = _locationController.text;
                                _minBudget = double.tryParse(_minBudgetController.text);
                                _maxBudget = double.tryParse(_maxBudgetController.text);
                                // Status is already updated via _selectedStatus
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7EFF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text("Apply Filters", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                            child: const Text("Clear All Filters", style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredJobs = _getFilteredJobs();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // --- HEADER ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Search Jobs", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            // --- SEARCH BAR & FILTER BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: "Search jobs...",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // --- FILTER BUTTON (Triggers Modal) ---
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7EFF), // Blue to show it's active/clickable
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: const Color(0xFF2E7EFF).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.tune, color: Colors.white),
                    ),
                  )
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2E7EFF) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected ? null : Border.all(color: Colors.grey.shade300),
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

            // --- RESULTS COUNT ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text("${filteredJobs.length} jobs found", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  if (_locationQuery.isNotEmpty || _minBudget != null || _selectedStatus != "All")
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                        child: const Text("Filters Active", style: TextStyle(fontSize: 10, color: Colors.blue)),
                      ),
                    )
                ],
              ),
            ),
            const SizedBox(height: 12),

            // --- JOB LIST ---
            Expanded(
              child: filteredJobs.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text("No jobs found", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    itemCount: filteredJobs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildJobCard(filteredJobs[index]);
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // --- JOB CARD WIDGET ---
  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(job['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.3))),
              if (job['isUrgent'])
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [Icon(Icons.access_time, size: 12, color: Colors.red), SizedBox(width: 4), Text("Urgent", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))]),
                )
              else 
                const Icon(Icons.bookmark_border, color: Colors.grey)
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Text(job['tags'], style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(job['price'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7EFF))),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(job['time'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(width: 12),
              Icon(Icons.people_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(job['applicants'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
           const SizedBox(height: 12),
           const Divider(height: 1, color: Colors.black12),
           const SizedBox(height: 12),
           Row(
             children: [
                Container(width: 32, height: 32, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)])), child: Center(child: Text(job['user'][0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job['user'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Row(children: [const Icon(Icons.star, size: 12, color: Colors.amber), Text(" ${job['rating']}", style: TextStyle(fontSize: 12, color: Colors.grey[600]))]),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                  child: Text(job['status'] ?? "Open", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                )
             ],
           )
        ],
      ),
    );
  }
}