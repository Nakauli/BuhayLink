import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart'; 

class HiredJobsPage extends StatelessWidget {
  final String? userId; // <--- Changed to Optional (Nullable)

  const HiredJobsPage({super.key, this.userId}); // <--- Accepts optional ID

  @override
  Widget build(BuildContext context) {
    // Logic: Use the passed userId if it exists; otherwise use the current logged-in user
    final targetUid = userId ?? FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Hired Jobs", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: targetUid == null 
        ? const Center(child: Text("User not found"))
        : StreamBuilder<QuerySnapshot>(
            // We look for applications where status is 'Hired' for the TARGET user
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(targetUid)
                .collection('applications')
                .where('status', isEqualTo: 'Hired') 
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.handshake_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No hired jobs yet.", style: TextStyle(color: Colors.grey)),
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

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? "Job", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text("Successfully Hired", style: TextStyle(color: Colors.green[800], fontSize: 12)),
                            ],
                          ),
                        ),
                        if (jobId.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.green),
                            onPressed: () => _navigateToJob(context, jobId),
                          )
                      ],
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

         Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId, isHired: true)));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}