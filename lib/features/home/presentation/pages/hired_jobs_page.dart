import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart'; 

class HiredJobsPage extends StatelessWidget {
  const HiredJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Hired Jobs", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
              // We check notifications because that's where we recorded the 'hired' status
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: uid)
                  .where('type', isEqualTo: 'hired')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

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

                final docs = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String jobId = data['jobId'] ?? "";
                    
                    // Fetch Job Details for each hired notification
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('jobs').doc(jobId).get(),
                      builder: (context, jobSnapshot) {
                        if (!jobSnapshot.hasData || !jobSnapshot.data!.exists) {
                          return const SizedBox.shrink(); // Hide if job deleted
                        }

                        final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;

                        return GestureDetector(
                          onTap: () {
                             _navigateToJob(context, jobId);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.green.shade200), // Green border for Hired
                              boxShadow: [
                                 BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                              ]
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.check_circle, color: Colors.green),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        jobData['title'] ?? "Job Title", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        "Status: Hired", 
                                        style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        );
                      }
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
            "title": jobData['title'] ?? "Job",
            "tag": jobData['category'] ?? "General",
            "price": "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}",
            "location": jobData['location'] ?? "Remote",
            "user": jobData['posterName'] ?? "Employer",
            "posterId": jobData['postedBy'],
            "rating": "New", 
            "applicants": "${jobData['applicants'] ?? 0} applicants",
            "duration": "3 days",
            "isUrgent": jobData['isUrgent'] ?? false,
            "description": jobData['description'] ?? "No description available.",
         };

         Navigator.push(
           context, 
           MaterialPageRoute(
             builder: (context) => JobDetailsPage(
               job: jobMap, 
               jobId: jobId,
               isHired: true, // Show the Green Hired Banner
               isRejected: false, 
             )
           )
         );
      }
    } catch (e) {
      debugPrint("Error fetching job: $e");
    }
  }
}