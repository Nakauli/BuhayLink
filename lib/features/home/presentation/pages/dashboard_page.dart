import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_job_page.dart';
import 'profile_page.dart'; 
import 'messages_page.dart';
import 'search_page.dart'; 
import 'notifications_page.dart';
import 'job_details_page.dart';
import 'applied_jobs_page.dart';
import 'hired_jobs_page.dart'; // NEW
import 'saved_jobs_page.dart'; // NEW
import 'my_posted_jobs_page.dart';
import 'public_profile_page.dart'; // Ensure this is imported for the Ratings box

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _showMyPosts = false; 
  String _selectedFilter = "All"; 
  String _searchQuery = "";       

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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(
              _showMyPosts ? Icons.add_circle : Icons.assignment, 
              size: 40, 
              color: const Color(0xFF2E7EFF)
            ), 
            label: _showMyPosts ? "Post" : "Applied"
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildHomeWithHeader() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final emailName = user?.email?.split('@')[0] ?? "Guest"; 

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
              // Greeting Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Welcome back,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      if (uid != null)
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data!.exists) {
                              final data = snapshot.data!.data() as Map<String, dynamic>?;
                              final String realName = data?['fullName'] ?? data?['firstName'] ?? data?['username'] ?? emailName;
                              return Text(realName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold));
                            }
                            return Text(emailName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold));
                          },
                        )
                      else
                         const Text("Guest", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  
                  // Notification Bell
                  GestureDetector(
                    onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage(isEmployerMode: _showMyPosts)));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.notifications, color: Colors.white),
                    ),
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


              // --- DYNAMIC STATS BOXES ---
              // 1. EMPLOYER MODE (My Posts)
              if (_showMyPosts)
                 StreamBuilder<QuerySnapshot>(
                   stream: FirebaseFirestore.instance.collection('jobs').where('postedBy', isEqualTo: uid).snapshots(),
                   builder: (context, snapshot) {
                     int active = 0;
                     int hired = 0;
                     int total = 0;

                     if (snapshot.hasData) {
                       total = snapshot.data!.docs.length;
                       // Count 'open' as Active
                       active = snapshot.data!.docs.where((doc) => doc['status'] == 'open').length;
                       // Count 'hired' or 'closed' as Hired
                       hired = snapshot.data!.docs.where((doc) => doc['status'] == 'hired' || doc['status'] == 'closed').length;
                     }

                     return Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         // 1. ACTIVE JOBS -> Navigate to MyPostedJobsPage (Filter: open)
                         _buildStatCard(
                           active.toString(), 
                           "Active", 
                           Icons.work_outline,
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostedJobsPage(title: "Active Jobs", statusFilter: ['open'])))
                         ),
                         
                         // 2. HIRED JOBS -> Navigate to MyPostedJobsPage (Filter: hired/closed)
                         _buildStatCard(
                           hired.toString(), 
                           "Hired", 
                           Icons.handshake_rounded,
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostedJobsPage(title: "Hired History", statusFilter: ['hired', 'closed'])))
                         ),
                         
                         // 3. RATINGS -> Go to Public Profile (See yourself as others see you)
                         _buildStatCard(
                           "4.5", 
                           "Ratings", 
                           Icons.star_rounded,
                           onTap: uid != null ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: uid, userName: "Me"))) : null
                         ), 
                         
                         // 4. TOTAL -> Navigate to MyPostedJobsPage (No Filter = All)
                         _buildStatCard(
                           total.toString(), 
                           "Total Posts", 
                           Icons.list_alt_rounded,
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPostedJobsPage(title: "All Posts", statusFilter: [])))
                         ),
                       ],
                     );
                   }
                 )
              // 2. APPLICANT MODE (Find Jobs)
              else
                 StreamBuilder<DocumentSnapshot>(
                   stream: uid != null ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots() : null,
                   builder: (context, snapshot) {
                     final data = snapshot.data?.data() as Map<String, dynamic>?;
                     
                     // Get counts from User Profile
                     final String appliedCount = data?['appliedCount']?.toString() ?? "0";
                     final String savedCount = data?['savedCount']?.toString() ?? "0";
                     // (You can add 'hiredCount' to your user profile later if you want to track it precisely)
                     
                     return Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         // BOX 1: APPLIED -> Goes to AppliedJobsPage
                         _buildStatCard(
                           appliedCount, 
                           "Applied", 
                           Icons.assignment_turned_in_rounded, 
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppliedJobsPage()))
                         ),
                         // BOX 2: HIRED -> Goes to HiredJobsPage
                         _buildStatCard(
                           "0", // You can calculate this properly later by querying applications where status == 'Hired'
                           "Hired", 
                           Icons.check_circle_outline,
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HiredJobsPage()))
                         ),
                         // BOX 3: RATINGS (Profile)
                         _buildStatCard(
                           data?['rating']?.toString() ?? "0.0", 
                           "Ratings", 
                           Icons.star_rounded
                         ),
                         // BOX 4: SAVED -> Goes to SavedJobsPage
                         _buildStatCard(
                           savedCount, 
                           "Saved", 
                           Icons.bookmark_rounded,
                           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedJobsPage()))
                         ),
                       ],
                     );
                   }
                 ),
            ],
          ),
        ),

        // REST OF THE DASHBOARD
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: _showMyPosts ? "Search my posts..." : "Search for jobs...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
        ),

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

              var docs = snapshot.data!.docs;

              // Filter out my own posts if in "Find Jobs" mode
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              if (!_showMyPosts && currentUid != null) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['postedBy'] != currentUid;
                }).toList();
              }

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['title'] ?? "").toString().toLowerCase().contains(_searchQuery) || (data['category'] ?? "").toString().toLowerCase().contains(_searchQuery);
                }).toList();
              }
              
              if (!_showMyPosts) { 
                if (_selectedFilter == "Urgent") docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['isUrgent'] == true).toList();
                else if (_selectedFilter == "\$ High Pay") docs = docs.where((doc) => ((doc.data() as Map<String, dynamic>)['budgetMax'] ?? 0) >= 20000).toList();
                else if (_selectedFilter == "Nearby") docs = docs.where((doc) => (doc.data() as Map<String, dynamic>)['location'].toString().toLowerCase().contains("santo tomas")).toList();
              }

              if (docs.isEmpty) return Center(child: Text("No matches found.", style: TextStyle(color: Colors.grey[500])));

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String jobId = doc.id; 

                  final Map<String, dynamic> jobMap = {
                    "title": data['title'] ?? "Untitled Job",
                    "tag": data['category'] ?? "General",
                    "price": "₱${data['budgetMin'] ?? 0} - ₱${data['budgetMax'] ?? 0}",
                    "location": data['location'] ?? "Remote",
                    "user": data['posterName'] ?? "Employer", 
                    "posterId": data['postedBy'], 
                    "rating": data['posterRating']?.toString() ?? "New", 
                    "applicants": "${data['applicants'] ?? 0} applicants",
                    "duration": "3 days", 
                    "isUrgent": data['isUrgent'] ?? false,
                    "description": data['description'] ?? "No description.",
                  };

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId)));
                    },
                    child: _buildJobCard(jobMap),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---
  Widget _getBodyContent() {
    switch (_selectedIndex) {
      case 1: return const SearchPage();
      case 2: return _showMyPosts 
          ? const AddJobPage(showBackButton: false)
          : const AppliedJobsPage(showBackButton: false);
      case 3: return const MessagesPage();
      case 4: return const ProfilePage();
      default: return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildToggleButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() { _showMyPosts = text == "My Posts"; _selectedFilter = "All"; _searchQuery = ""; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(text, style: TextStyle(color: isActive ? const Color(0xFF2E7EFF) : Colors.white, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, {VoidCallback? onTap}) {
    double boxWidth = (MediaQuery.of(context).size.width - 64) / 4; 
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: boxWidth,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.2))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.7), height: 1.1)),
          ],
        ),
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
        decoration: BoxDecoration(color: isActive ? const Color(0xFF2E7EFF) : Colors.white, borderRadius: BorderRadius.circular(20), border: isActive ? null : Border.all(color: Colors.grey.shade300)),
        child: Row(children: [if (icon != null) ...[Icon(icon, size: 14, color: isActive ? Colors.white : Colors.grey[600]), const SizedBox(width: 6)], Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 13))]),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: Colors.grey.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(job['title'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.3, color: Colors.black87))),
              if (job['isUrgent'])
                Container(margin: const EdgeInsets.only(left: 12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)), child: Row(children: [Icon(Icons.access_time_filled, size: 14, color: Colors.red[400]), const SizedBox(width: 6), Text("Urgent", style: TextStyle(color: Colors.red[400], fontSize: 11, fontWeight: FontWeight.w700))])),
              const SizedBox(width: 12),
              Icon(Icons.bookmark_border_rounded, color: Colors.grey[400], size: 26),
            ],
          ),
          const SizedBox(height: 12),
          Text(job['description'] ?? "Looking for a skilled professional to help with this project.", style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)), child: Text(job['tag'].toString(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600))),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInfoItem(Icons.payments_outlined, job['price'], isPrimary: true), const SizedBox(height: 12), _buildInfoItem(Icons.location_on_outlined, job['location'])])),
              Expanded(flex: 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildInfoItem(Icons.schedule_outlined, job['duration']), const SizedBox(height: 12), _buildInfoItem(Icons.people_outline_rounded, job['applicants'])])),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: job['posterId'] != null ? FirebaseFirestore.instance.collection('users').doc(job['posterId']).snapshots() : null,
            builder: (context, snapshot) {
              String name = "Employer";
              if (job['user'] != null && job['user'] != "Employer") name = job['user'];
              final currentUser = FirebaseAuth.instance.currentUser;
              if (name == "Employer" && job['posterId'] == currentUser?.uid) name = currentUser?.email?.split('@')[0] ?? "Me";
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>?;
                if (userData != null) {
                   String? fetchedName = userData['fullName'] ?? userData['firstName'] ?? userData['username'];
                   if (fetchedName != null && fetchedName.isNotEmpty) name = fetchedName;
                }
              }
              String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "E";
              return Row(
                children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.purple.shade300])), child: Center(child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w700)), const SizedBox(height: 2), Row(children: [const Icon(Icons.star_rounded, size: 16, color: Colors.amber), const SizedBox(width: 4), Text(job['rating'], style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w600))])]),
                  const Spacer(),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)), child: Text("Open", style: TextStyle(color: Colors.green[700], fontSize: 13, fontWeight: FontWeight.w700)))
                ],
              );
            }
          )
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {bool isPrimary = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: isPrimary ? const Color(0xFF2E7EFF) : Colors.grey[400]), const SizedBox(width: 8), Flexible(child: Text(text, style: TextStyle(color: isPrimary ? Colors.black87 : Colors.grey[600], fontSize: 13, fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500), overflow: TextOverflow.ellipsis))]);
  }
}