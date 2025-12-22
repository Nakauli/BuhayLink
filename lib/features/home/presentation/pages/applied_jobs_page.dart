import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart'; 

class AppliedJobsPage extends StatefulWidget {
  final bool showBackButton; // <--- The Dashboard needs this!

  const AppliedJobsPage({super.key, this.showBackButton = true});

  @override
  State<AppliedJobsPage> createState() => _AppliedJobsPageState();
}

class _AppliedJobsPageState extends State<AppliedJobsPage> {

  @override
  void initState() {
    super.initState();
    _syncApplicationCount();
  }

  Future<void> _syncApplicationCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('applications')
          .count() 
          .get();

      final int actualCount = query.count ?? 0;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'appliedCount': actualCount});
    } catch (e) {
      debugPrint("Error syncing count: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // --- FIX: Only show arrow if allowed ---
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            )
          : null,
        title: const Text(
          "Applied Jobs", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('applications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  if (snapshot.connectionState == ConnectionState.active) {
                     _syncApplicationCount(); 
                  }
                  
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("You haven't applied to any jobs yet.", style: TextStyle(color: Colors.grey)),
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
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String jobId = data['jobId'] ?? "";
                    
                    return Dismissible(
                      key: Key(doc.id), 
                      direction: DismissDirection.endToStart, 
                      
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white, size: 30),
                      ),
                      
                      onDismissed: (direction) async {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('applications')
                            .doc(doc.id)
                            .delete();
                        
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .update({
                              'appliedCount': FieldValue.increment(-1)
                            });
                      },

                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                             BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.work, color: Color(0xFF2E7EFF)),
                            ),
                            const SizedBox(width: 16),
                            
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? "Unknown Job", 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    data['price'] ?? "₱0", 
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)
                                  ),
                                ],
                              ),
                            ),
                            
                            TextButton(
                              onPressed: () {
                                if (jobId.isNotEmpty) {
                                  _navigateToJob(context, jobId);
                                }
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.green[50],
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: Text(
                                "View", 
                                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12)
                              ),
                            )
                          ],
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
               isHired: false, 
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