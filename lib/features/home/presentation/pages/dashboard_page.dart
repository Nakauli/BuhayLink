import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 1. CATEGORIES
  int selectedCategoryIndex = 0;
  final List<String> categories = ["All", "Nearby", "Urgent", "High Pay", "Remote"];

  // 2. YOUR JOB DATA (Converted from the text you sent)
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
      "title": "Garden landscaping and maintenance",
      "tags": "Landscaping • Garden Design",
      "price": "₱6,000 - ₱9,000",
      "location": "Mandaluyong",
      "user": "Lisa Tan",
      "rating": "4.6",
      "applicants": "9 applicants",
      "time": "10 days ago",
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
    {
      "title": "Web developer for small business website",
      "tags": "Web Dev • E-commerce",
      "price": "₱20,000 - ₱35,000",
      "location": "Remote",
      "user": "Sarah Chen",
      "rating": "4.9",
      "applicants": "18 applicants",
      "time": "3 weeks ago",
      "isUrgent": false,
    },
    {
      "title": "Roof repair after storm damage",
      "tags": "Roofing • Leak Repair",
      "price": "₱7,000 - ₱12,000",
      "location": "Caloocan City",
      "user": "Miguel Ramos",
      "rating": "4.7",
      "applicants": "3 applicants",
      "time": "1 day ago",
      "isUrgent": true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // --- HEADER SECTION ---
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
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text("Find Jobs", style: TextStyle(color: Color(0xFF2E7EFF), fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text("My Posts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard("12", "Completed", Icons.trending_up),
                    _buildStatCard("4.8", "Rating", Icons.star_border), // Updated to match highest rating in data
                    _buildStatCard("0", "Saved", Icons.bookmark_border),
                  ],
                ),
              ],
            ),
          ),

          // --- SCROLLABLE CONTENT ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 20, bottom: 20),
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
                      const Text("Available Jobs", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: (){}, child: const Text("See All", style: TextStyle(color: Colors.blue))),
                    ],
                  ),
                ),

                // JOB LIST GENERATOR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListView.separated(
                    // Important properties for nested listviews
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: jobList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final job = jobList[index];
                      return _buildJobCard(job);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF2E7EFF),
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        currentIndex: 0,
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

  // --- WIDGETS ---

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

  // Updated to accept the Map data directly
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
          // Title & Urgent
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(job['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.3)),
              ),
              if (job['isUrgent'])
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.red),
                      SizedBox(width: 4),
                      Text("Urgent", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else 
                const Icon(Icons.bookmark_border, color: Colors.grey)
            ],
          ),
          const SizedBox(height: 12),
          
          // Tags
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
            child: Text(job['tags'], style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),

          // Price & Location
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
          
          // User & Applicants
          Row(
            children: [
              // Avatar Placeholder with Initials
              Container(
                width: 24, height: 24,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
                child: Center(child: Text(job['user'][0], style: const TextStyle(color: Colors.white, fontSize: 10))),
              ),
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