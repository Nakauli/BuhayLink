import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart'; // Needed for navigation

class SavedJobsPage extends StatelessWidget {
  const SavedJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Saved Jobs", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null 
        ? const Center(child: Text("Please login"))
        : StreamBuilder<QuerySnapshot>(
            // We look at the 'saved' subcollection of the user
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('saved').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No saved jobs yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final String jobId = data['jobId'] ?? "";
                  
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.bookmark, color: Color(0xFF2E7EFF)),
                      ),
                      title: Text(data['title'] ?? "Job Title", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(data['price'] ?? "Budget"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                         if (jobId.isNotEmpty) _navigateToJob(context, jobId);
                      },
                    ),
                  );
                },
              );
            },
          ),
    );
  }

  void _navigateToJob(BuildContext context, String jobId) async {
    try {
      DocumentSnapshot jobDoc = await FirebaseFirestore.instance.collection('jobs').doc(jobId).get();
      if (jobDoc.exists && context.mounted) {
         final jobData = jobDoc.data() as Map<String, dynamic>;
         final Map<String, dynamic> jobMap = {
           "title": jobData['title'],
           "tag": jobData['category'],
           "price": "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}",
           "location": jobData['location'],
           "user": jobData['posterName'],
           "posterId": jobData['postedBy'],
           "rating": "New", 
           "applicants": "${jobData['applicants']} applicants",
           "duration": "3 days",
           "isUrgent": jobData['isUrgent'] ?? false,
           "description": jobData['description'] ?? "",
         };

         Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId)));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}