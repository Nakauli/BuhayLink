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
    final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Find Jobs", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false, 
      ),
      body: Column(
        children: [
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // We use snapshots() directly to ensure we get the raw data
              stream: FirebaseFirestore.instance.collection('jobs').orderBy('postedAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No jobs posted yet."));

                final jobs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  
                  // 1. GET ID
                  final String ownerId = data['postedBy'] ?? ""; 

                  // 2. FILTER
                  if (ownerId == currentUid) {
                    return false; // Hide my own jobs
                  }

                  // 3. SEARCH
                  final String title = (data['title'] ?? "").toString().toLowerCase();
                  if (_searchQuery.isNotEmpty && !title.contains(_searchQuery)) return false;

                  return true;
                }).toList();

                if (jobs.isEmpty) return const Center(child: Text("No jobs found (All hidden or filtered)."));

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

  // --- DEBUG CARD ---
  Widget _buildDebugJobCard(BuildContext context, Map<String, dynamic> job, String jobId, String? myId) {
    final String ownerId = job['postedBy'] ?? "Unknown";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailsPage(jobId: jobId, job: job)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- VISUAL DEBUGGER (Remove this later) ---
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              color: Colors.yellow.shade100,
              child: Text(
                "DEBUG MODE:\nOwner ID: $ownerId\nMy ID:    $myId",
                style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold, fontFamily: "monospace"),
              ),
            ),
            const SizedBox(height: 8),
            // -------------------------------------------

            Text(job['title'] ?? "No Title", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("Budget: ₱${job['budgetMin']} - ₱${job['budgetMax']}", style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(job['description'] ?? "No description", maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}