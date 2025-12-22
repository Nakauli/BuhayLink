import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart'; 

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
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('saved').orderBy('savedAt', descending: true).snapshots(),
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
                  final doc = snapshot.data!.docs[index]; // Get the document
                  final data = doc.data() as Map<String, dynamic>;
                  final String jobId = data['jobId'] ?? "";
                  
                  // --- SWIPE TO DELETE FEATURE ---
                  return Dismissible(
                    key: Key(jobId), // Unique ID for this row
                    direction: DismissDirection.endToStart, // Swipe Right to Left
                    
                    // 1. CONFIRMATION POPUP
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Remove Bookmark?"),
                            content: const Text("Are you sure you want to unsave this job?"),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false), // Cancel
                                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true), // Confirm
                                child: const Text("Remove", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          );
                        },
                      );
                    },

                    // 2. RED BACKGROUND (Visual Cue)
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text("Remove", style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.bookmark_remove, color: Colors.red[700], size: 26),
                        ],
                      ),
                    ),

                    // 3. ACTUAL DELETE LOGIC
                    onDismissed: (direction) async {
                      // A. Remove from 'saved' collection
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('saved')
                          .doc(jobId) // Be sure to use the correct Doc ID (usually jobId)
                          .delete();

                      // B. Decrement the counter on Dashboard
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .set({
                            'savedCount': FieldValue.increment(-1)
                          }, SetOptions(merge: true));

                      // Optional: Show "Undo" snackbar if you want
                    },

                    child: Card(
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