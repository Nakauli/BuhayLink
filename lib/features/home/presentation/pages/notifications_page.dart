import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_page.dart'; 

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text("Notifications", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: uid)
                  .snapshots(), 
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No notifications yet", style: TextStyle(color: Colors.grey)));
                }

                final docs = snapshot.data!.docs;
                // Client-side sort (Newest first)
                docs.sort((a, b) {
                  Timestamp t1 = a['timestamp'] ?? Timestamp.now();
                  Timestamp t2 = b['timestamp'] ?? Timestamp.now();
                  return t2.compareTo(t1); 
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    // --- GET THE DATA ---
                    final String applicantId = data['applicantId'] ?? "";
                    final String? jobId = data['jobId']; // Get the Job ID
                    final bool isRead = data['read'] ?? false;

                    return GestureDetector(
                      onTap: () async {
                        // 1. Mark as read
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(docs[index].id)
                            .update({'read': true});

                        if (applicantId.isNotEmpty) {
                          // 2. FETCH NAME & NAVIGATE
                          String finalName = "Applicant";
                          try {
                            DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(applicantId).get();
                            if (userDoc.exists) {
                              final userData = userDoc.data() as Map<String, dynamic>;
                              finalName = userData['fullName'] ?? userData['firstName'] ?? userData['username'] ?? "Applicant";
                            }
                          } catch (e) {
                            debugPrint("Error fetching name: $e");
                          }

                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PublicProfilePage(
                                  userId: applicantId,
                                  userName: finalName,
                                  jobId: jobId, // <--- IMPORTANT: PASS THE JOB ID HERE
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : Colors.blue[50], 
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFF2E7EFF),
                              radius: 20,
                              child: Icon(Icons.person, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['title'] ?? "Notification", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(data['message'] ?? "", style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                                ],
                              ),
                            ),
                            if (!isRead) const CircleAvatar(radius: 5, backgroundColor: Colors.red),
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
}