import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_job_page.dart';
// --- IMPORTS FOR NAVIGATION ---
import 'profile_page.dart'; 
import 'messages_page.dart';
import 'search_page.dart'; 

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _showMyPosts = false;
  String _selectedFilter = "All"; // Tracks active button filter
  String _searchQuery = "";       // <--- NEW: Tracks search text

  // --- 1. MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _selectedIndex == 0 
          ? _buildHomeWithHeader() 
          : _getBodyContent(),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2E7EFF),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle, size: 40, color: Color(0xFF2E7EFF)), label: "Post"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  // --- 2. HOME SCREEN DESIGN ---
  Widget _buildHomeWithHeader() {
    return Column(
      children: [
        // A. BLUE HEADER
        Container(
          padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              // Greeting
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
                    child: const Icon(Icons.notifications, color: Colors.white),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Toggle Button
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(child: _buildToggleButton("Find Jobs", !_showMyPosts)),
                    Expanded(child: _buildToggleButton("My Posts", _showMyPosts)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard("12", "Completed", Icons.trending_up),
                  _buildStatCard("4.8", "Rating", Icons.star),
                  _buildStatCard("0", "Saved", Icons.bookmark),
                ],
              ),
            ],
          ),
        ),

        // B. SEARCH BAR (NOW WORKING!)
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase(); // <--- UPDATES SEARCH QUERY
              });
            },
            decoration: InputDecoration(
              hintText: "Search for jobs...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
        ),

        // C. FILTER ROW
        if (!_showMyPosts)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildFilterChip("All"),
                const SizedBox(width: 10),
                _buildFilterChip("Nearby", icon: Icons.location_on_outlined),
                const SizedBox(width: 10),
                _buildFilterChip("Urgent", icon: Icons.access_time),
                const SizedBox(width: 10),
                _buildFilterChip("\$ High Pay"),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // D. "AVAILABLE JOBS" HEADER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_showMyPosts ? "My Active Posts" : "Available Jobs", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Text("See All", style: TextStyle(color: Color(0xFF2E7EFF), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // E. LIVE FIREBASE LIST (WITH SEARCH + FILTER LOGIC)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _showMyPosts 
              ? FirebaseFirestore.instance.collection('jobs').where('postedBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid).orderBy('postedAt', descending: true).snapshots()
              : FirebaseFirestore.instance.collection('jobs').orderBy('postedAt', descending: true).snapshots(),
            
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text(_showMyPosts ? "You haven't posted any jobs." : "No jobs found.", style: TextStyle(color: Colors.grey[500])));
              }

              // --- FILTERING LOGIC ---
              var docs = snapshot.data!.docs;

              // 1. APPLY SEARCH FILTER
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? "").toString().toLowerCase();
                  final category = (data['category'] ?? "").toString().toLowerCase();
                  // Check if title OR category contains the search text
                  return title.contains(_searchQuery) || category.contains(_searchQuery);
                }).toList();
              }

              // 2. APPLY BUTTON FILTERS (Only in "Find Jobs" mode)
              if (!_showMyPosts) { 
                if (_selectedFilter == "Urgent") {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['isUrgent'] == true;
                  }).toList();
                } 
                else if (_selectedFilter == "\$ High Pay") {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final budget = data['budgetMax'] ?? 0;
                    return budget >= 20000;
                  }).toList();
                }
                else if (_selectedFilter == "Nearby") {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final loc = (data['location'] ?? "").toString().toLowerCase();
                    return loc.contains("santo tomas") || loc.contains("davao");
                  }).toList();
                }
              }

              if (docs.isEmpty) {
                return Center(child: Text("No matches found.", style: TextStyle(color: Colors.grey[500])));
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final Map<String, dynamic> jobMap = {
                    "title": data['title'] ?? "Untitled",
                    "tags": data['category'] ?? "General",
                    "price": "₱${data['budgetMin'] ?? 0} - ₱${data['budgetMax'] ?? 0}",
                    "location": data['location'] ?? "Remote",
                    "user": data['posterName'] ?? "Employer", 
                    "rating": "5.0",
                    "applicants": "${data['applicants'] ?? 0} applicants",
                    "time": "Active",
                    "isUrgent": data['isUrgent'] ?? false,
                  };
                  return _buildJobCard(jobMap);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 3. HELPERS ---
  
  Widget _getBodyContent() {
    switch (_selectedIndex) {
      case 1: return const SearchPage(); // Connects to search_page.dart
      case 2: return const PostJobPage();
      case 3: return const MessagesPage(); // Connects to messages_page.dart
      case 4: return const ProfilePage();  // Connects to profile_page.dart
      default: return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildToggleButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() {
        _showMyPosts = text == "My Posts";
        _selectedFilter = "All"; // Reset filter when switching tabs
        _searchQuery = "";       // Reset search when switching tabs
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(text, style: TextStyle(color: isActive ? const Color(0xFF2E7EFF) : Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, {IconData? icon}) {
    bool isActive = _selectedFilter == label;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label), 
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2E7EFF) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isActive ? Colors.white : Colors.grey[600]),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

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
            child: Text(job['tags'].toString(), style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(job['price'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2E7EFF))),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(job['time'].toString(), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 24, height: 24, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey), child: Center(child: Text(job['user'][0], style: const TextStyle(color: Colors.white, fontSize: 10)))),
              const SizedBox(width: 8),
              Text(job['user'], style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.people_outline, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(job['applicants'].toString(), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}