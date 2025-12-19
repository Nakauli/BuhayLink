import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_page.dart'; 
import 'job_details_page.dart'; 

class NotificationsPage extends StatelessWidget {
  final bool isEmployerMode; 

  const NotificationsPage({super.key, required this.isEmployerMode});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          isEmployerMode ? "Employer Notifications" : "Applicant Notifications", 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
              // Fetch notifications for the current user OR 'all'
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', whereIn: [uid, 'all']) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                   return const Center(child: Text("No notifications found.", style: TextStyle(color: Colors.grey)));
                }

                // --- FILTERING LOGIC ---
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'];
                  final posterId = data['posterId'];

                  if (isEmployerMode) {
                    // Employer Mode: Only see Applications
                    return type == 'application';
                  } else {
                    // Applicant Mode: See Hired, Rejected, New Posts
                    if (type == 'new_post') {
                       return posterId != uid; // Hide my own posts
                    }
                    return ['hired', 'rejected', 'new_post'].contains(type);
                  }
                }).toList();

                if (filteredDocs.isEmpty) {
                   return const Center(child: Text("No new notifications.", style: TextStyle(color: Colors.grey)));
                }

                // --- SORTING (Client-side) ---
                filteredDocs.sort((a, b) {
                  Timestamp t1 = a['timestamp'] ?? Timestamp.now();
                  Timestamp t2 = b['timestamp'] ?? Timestamp.now();
                  return t2.compareTo(t1); 
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    
                    final String applicantId = data['applicantId'] ?? "";
                    final String? jobId = data['jobId'];
                    final bool isRead = data['read'] ?? false;
                    final String type = data['type'] ?? 'application';

                    IconData icon = Icons.notifications;
                    Color iconBg = Colors.grey;

                    if (type == 'hired') {
                      icon = Icons.check_circle;
                      iconBg = Colors.green;
                    } else if (type == 'rejected') {
                      icon = Icons.cancel;
                      iconBg = Colors.redAccent;
                    } else if (type == 'new_post') {
                      icon = Icons.work; 
                      iconBg = const Color(0xFF2E7EFF);
                    } else if (type == 'application') {
                      icon = Icons.person;
                      iconBg = Colors.blue;
                    }

                    return GestureDetector(
                      onTap: () async {
                        if (data['recipientId'] != 'all') {
                           await FirebaseFirestore.instance.collection('notifications').doc(filteredDocs[index].id).update({'read': true});
                        }

                        // NAVIGATION LOGIC
                        if (type == 'new_post' && jobId != null) {
                           _navigateToJob(context, jobId);
                        } else if (isEmployerMode && applicantId.isNotEmpty) {
                           _navigateToProfile(context, applicantId, jobId);
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
                            CircleAvatar(
                              backgroundColor: iconBg,
                              radius: 20,
                              child: Icon(icon, color: Colors.white, size: 20),
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

  // --- 1. IMPROVED NAME FETCHING LOGIC ---
  void _navigateToProfile(BuildContext context, String userId, String? jobId) async {
    String finalName = "Applicant"; // Default fallback
    
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // CHECK ALL POSSIBLE FIELDS
        if (userData['fullName'] != null && userData['fullName'].toString().isNotEmpty) {
          finalName = userData['fullName'];
        } else if (userData['firstName'] != null && userData['firstName'].toString().isNotEmpty) {
           // Combine First + Last if available
           String first = userData['firstName'];
           String last = userData['lastName'] ?? "";
           finalName = "$first $last".trim();
        } else if (userData['username'] != null && userData['username'].toString().isNotEmpty) {
          finalName = userData['username'];
        } else if (userData['name'] != null && userData['name'].toString().isNotEmpty) {
          finalName = userData['name'];
        } else if (userData['email'] != null) {
          // Absolute last resort: use email prefix
          finalName = userData['email'].split('@')[0];
        }
      }
    } catch (e) {
      debugPrint("Error fetching name: $e");
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicProfilePage(
            userId: userId, 
            userName: finalName, // Now passes the correct fetched name
            jobId: jobId
          )
        )
      );
    }
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
         };
         Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId)));
      }
    } catch (e) {
      debugPrint("Error fetching job: $e");
    }
  }
}