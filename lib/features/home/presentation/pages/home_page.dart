import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    // 1. Get Current User ID
    final user = FirebaseAuth.instance.currentUser;
    final String currentUid = user?.uid ?? "Not Logged In";

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 102, 18, 18),
      appBar: AppBar(
        title: const Text("Find Jobs (Debug Mode)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 77, 138, 8),
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search for job titles...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),

          // --- JOB LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('jobs')
                  .orderBy('postedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // A. Loading State
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // B. No Data
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No jobs posted yet."));
                }

                // --- FILTER LOGIC ---
                final jobs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // 1. Get Owner ID (We check 'postedBy' first, then others just in case)
                  final String jobOwnerId = data['postedBy'] ?? data['recruiterId'] ?? data['uid'] ?? ""; 

                  // 2. THE FILTER
                  // Even if we filter it here, I will temporarily SHOW IT 
                  // so you can see the Yellow Box and confirm the IDs.
                  // Once fixed, we will uncomment the 'return false'.
                  
                  /* // UNCOMMENT THIS LATER TO ACTUALLY HIDE THEM
                  if (jobOwnerId == currentUid) {
                    return false; 
                  }
                  */

                  // 3. Search Filter
                  final String title = (data['title'] ?? data['jobTitle'] ?? "").toString().toLowerCase();
                  if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) {
                    return false;
                  }

                  return true;
                }).toList();
                // --------------------

                if (jobs.isEmpty) {
                  return const Center(child: Text("No jobs found."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final jobData = jobs[index].data() as Map<String, dynamic>;
                    final jobId = jobs[index].id;
                    return _buildDebugJobCard(context, jobData, jobId, currentUid);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET WITH YELLOW DEBUG BOX ---
  Widget _buildDebugJobCard(BuildContext context, Map<String, dynamic> job, String jobId, String myId) {
    // Get the owner ID exactly as the app sees it
    final String ownerId = job['postedBy'] ?? job['recruiterId'] ?? "Unknown";
    
    // Check if they match
    final bool isMyJob = (ownerId == myId);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => JobDetailsPage(jobId: jobId, job: job))
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------------------------------------------------------
            // 🟡 THE YELLOW DEBUG BOX 🟡
            // Look at this box on your screen!
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMyJob ? Colors.red.shade100 : Colors.yellow.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16), 
                  topRight: Radius.circular(16)
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("🕵️‍♀️ DEBUG INFO:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("Job Owner ID: $ownerId"),
                  Text("My Current ID:  $myId"),
                  const SizedBox(height: 4),
                  Text(
                    isMyJob ? "⚠️ THIS IS MY JOB (Should be hidden)" : "✅ NOT MY JOB (Safe to show)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: isMyJob ? Colors.red : Colors.green[800]
                    ),
                  ),
                ],
              ),
            ),
            // ---------------------------------------------------------

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.business, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(job['title'] ?? job['jobTitle'] ?? "No Title", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Budget: ₱${job['budgetMin'] ?? 0} - ₱${job['budgetMax'] ?? 0}", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    job['description'] ?? "No description provided.",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}