import 'package:flutter/material.dart';
import 'search_page.dart'; // Ensure you created this file from the previous step!
import 'messages_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- 1. NAVIGATION STATE ---
  int _bottomNavIndex = 0; // 0 = Home, 1 = Search, etc.

  // --- 2. HOME TAB STATE ---
  int selectedCategoryIndex = 0;
  bool isFindJobs = true; // Toggle state
  
  final List<String> categories = ["All", "Nearby", "Urgent", "High Pay", "Remote"];

  // Your Job Data
  final List<Map<String, dynamic>> jobList = [
    {
      "title": "Need experienced plumber for kitchen renovation",
      "tags": "Plumbing • Pipe Installation",
      "price": "₱5,000 - ₱8,000",
      "location": "Quezon City",
      "user": "Maria Santos",
      "rating": "4.8",
      "applicants": "8 applicants",
      "time": "3 days ago",
      "isUrgent": true,
    },
    {
      "title": "Carpenter needed for custom furniture",
      "tags": "Carpentry • Furniture Making",
      "price": "₱12,000 - ₱15,000",
      "location": "Makati City",
      "user": "Juan dela Cruz",
      "rating": "4.5",
      "applicants": "12 applicants",
      "time": "1 week ago",
      "isUrgent": false,
    },
    {
      "title": "House painting - interior walls",
      "tags": "Painting • Surface Preparation",
      "price": "₱8,000 - ₱10,000",
      "location": "Pasig City",
      "user": "Ana Reyes",
      "rating": "4.9",
      "applicants": "15 applicants",
      "time": "5 days ago",
      "isUrgent": false,
    },
    {
      "title": "Electrical wiring for new construction",
      "tags": "Electrical Wiring • Safety",
      "price": "₱25,000 - ₱30,000",
      "location": "Taguig City",
      "user": "Robert Garcia",
      "rating": "4.7",
      "applicants": "6 applicants",
      "time": "2 weeks ago",
      "isUrgent": false,
    },
    {
      "title": "AC repair and maintenance",
      "tags": "AC Repair • HVAC Maintenance",
      "price": "₱3,000 - ₱5,000",
      "location": "Manila City",
      "user": "Pedro Martinez",
      "rating": "4.4",
      "applicants": "5 applicants",
      "time": "2 days ago",
      "isUrgent": true,
    },
  ];

  // Filter Logic
  List<Map<String, dynamic>> getFilteredJobs() {
    if (!isFindJobs) return []; 

    String selectedCategory = categories[selectedCategoryIndex];
    switch (selectedCategory) {
      case "All": return jobList;
      case "Urgent": return jobList.where((job) => job['isUrgent'] == true).toList();
      case "Remote": return jobList.where((job) => job['location'] == "Remote").toList();
      case "High Pay": return jobList.where((job) {
          String priceStr = job['price'].toString().replaceAll('₱', '').replaceAll(',', '');
          String lowerPrice = priceStr.split('-')[0].trim();
          return int.parse(lowerPrice) >= 20000;
        }).toList();
      case "Nearby": return jobList.where((job) {
          String loc = job['location'];
          return loc.contains("Quezon City") || loc.contains("Manila");
        }).toList();
      default: return jobList;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

// --- MAIN BODY SWITCHER ---
      body: _bottomNavIndex == 0 
          ? _buildHomeContent()      // Index 0: Dashboard
          : _bottomNavIndex == 1 
              ? const SearchPage()   // Index 1: Search
              : _bottomNavIndex == 3 
                  ? const MessagesPage() // Index 3: MESSAGES (Added this!)
                  : Center(child: Text("Tab $_bottomNavIndex Coming Soon")),

      // --- BOTTOM NAVIGATION ---
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2E7EFF),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: _bottomNavIndex,
        onTap: (index) => setState(() => _bottomNavIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 45, color: Color(0xFF2E7EFF)), label: ""), 
          BottomNavigationBarItem(icon: Icon(Icons.message_outlined), label: "Messages"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  // --- HOME TAB CONTENT (Full Code) ---
  Widget _buildHomeContent() {
    final filteredJobs = getFilteredJobs();

    return Column(
      children: [
        // 1. Header Section
        Container(
          padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 30),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2E7EFF), Color(0xFF9542FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Welcome Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text("John Doe", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_none, color: Colors.white),
                  )
                ],
              ),
              const SizedBox(height: 24),
              
              // Toggle Button
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildToggleOption("Find Jobs", true),
                    _buildToggleOption("My Posts", false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard("12", "Completed", Icons.trending_up),
                  _buildStatCard("4.8", "Rating", Icons.star_border),
                  _buildStatCard("0", "Saved", Icons.bookmark_border),
                ],
              ),
            ],
          ),
        ),

        // 2. Scrollable Body
        Expanded(
          child: isFindJobs 
            ? ListView( // View 1: Job List
                padding: const EdgeInsets.symmetric(vertical: 20),
                children: [
                  // Categories
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        bool isSelected = selectedCategoryIndex == index;
                        return GestureDetector(
                          onTap: () => setState(() => selectedCategoryIndex = index),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF2E7EFF) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                              boxShadow: isSelected 
                                ? [BoxShadow(color: const Color(0xFF2E7EFF).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))]
                                : null,
                            ),
                            child: Text(
                              categories[index],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Available Jobs (${filteredJobs.length})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton(onPressed: (){}, child: const Text("See All", style: TextStyle(color: Colors.blue))),
                      ],
                    ),
                  ),

                  // Job List Items
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: filteredJobs.isEmpty 
                      ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No jobs found")))
                      : ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: filteredJobs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) => _buildJobCard(filteredJobs[index]),
                        ),
                  ),
                ],
              ) 
            : _buildMyPostsView(), // View 2: My Posts
        ),
      ],
    );
  }

  // --- HELPER WIDGETS (Full Styling Restored) ---

  Widget _buildToggleOption(String title, bool isOptionFindJobs) {
    bool isActive = isFindJobs == isOptionFindJobs; 
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isFindJobs = isOptionFindJobs),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? const Color(0xFF2E7EFF) : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyPostsView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Your Job Posts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: (){}, child: const Text("See All", style: TextStyle(color: Colors.blue))),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)],
            ),
            child: Icon(Icons.post_add, size: 60, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          Text(
            "You haven't posted any jobs yet.\nTap the Post button to create your first job.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16, height: 1.5),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildStatCard(String count, String label, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))
        ],
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
              else const Icon(Icons.bookmark_border, color: Colors.grey)
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Text(job['tags'], style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(job['price'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7EFF))),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(job['time'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey), child: Center(child: Text(job['user'][0], style: const TextStyle(color: Colors.white, fontSize: 10)))),
              const SizedBox(width: 8),
              Text(job['user'], style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.star, size: 12, color: Colors.amber[700]),
              Text(job['rating'], style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(Icons.people_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(job['applicants'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}