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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEmployerMode ? "Employer Notifications" : "Applicant Notifications", 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
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

                // FILTERING LOGIC
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'];
                  final posterId = data['posterId'];

                  if (isEmployerMode) {
                    return type == 'application';
                  } else {
                    if (type == 'new_post') {
                       return posterId != uid; 
                    }
                    return ['hired', 'rejected', 'new_post'].contains(type);
                  }
                }).toList();

                if (filteredDocs.isEmpty) {
                   return const Center(child: Text("No new notifications.", style: TextStyle(color: Colors.grey)));
                }

                // SORTING
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
                        // Mark as read
                        if (data['recipientId'] != 'all') {
                           await FirebaseFirestore.instance.collection('notifications').doc(filteredDocs[index].id).update({'read': true});
                        }

                        if (jobId != null) {
                          // CASE 1: Employer clicking an applicant -> Open Profile
                          if (isEmployerMode && applicantId.isNotEmpty) {
                             _navigateToProfile(context, applicantId, jobId);
                          } 
                          // CASE 2: New Job Alert -> Open Job (No status)
                          else if (type == 'new_post') {
                             _navigateToJob(context, jobId, type); 
                          }
                          // CASE 3: Hired/Rejected -> Open Job (WITH STATUS FLAGS)
                          else if (type == 'hired' || type == 'rejected') {
                             _navigateToJob(context, jobId, type); 
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

  // --- HELPER 1: Navigate to Job Details (Updated to pass Flags) ---
  void _navigateToJob(BuildContext context, String jobId, String notificationType) async {
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
            "description": jobData['description'] ?? "No description.",
         };

         Navigator.push(
           context, 
           MaterialPageRoute(
             builder: (context) => JobDetailsPage(
               job: jobMap, 
               jobId: jobId,
               // --- THIS IS THE KEY CHANGE ---
               isHired: notificationType == 'hired', 
               isRejected: notificationType == 'rejected',
             )
           )
         );
      }
    } catch (e) {
      debugPrint("Error fetching job: $e");
    }
  }

  // --- HELPER 2: Navigate to Profile ---
  void _navigateToProfile(BuildContext context, String userId, String? jobId) async {
    String finalName = "Applicant";
    String? finalJobTitle; 

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        if (userData['fullName'] != null && userData['fullName'].toString().isNotEmpty) {
          finalName = userData['fullName'];
        } else if (userData['firstName'] != null && userData['firstName'].toString().isNotEmpty) {
           String first = userData['firstName'];
           String last = userData['lastName'] ?? "";
           finalName = "$first $last".trim();
        } else if (userData['username'] != null && userData['username'].toString().isNotEmpty) {
          finalName = userData['username'];
        } else if (userData['email'] != null) {
          finalName = userData['email'].split('@')[0];
        }
      }

      if (jobId != null) {
        DocumentSnapshot jobDoc = await FirebaseFirestore.instance.collection('jobs').doc(jobId).get();
        if (jobDoc.exists) {
           final jobData = jobDoc.data() as Map<String, dynamic>;
           finalJobTitle = jobData['title'];
        }
      }

    } catch (e) {
      debugPrint("Error fetching data: $e");
    }

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicProfilePage(
            userId: userId, 
            userName: finalName, 
            jobId: jobId,
            jobTitle: finalJobTitle, 
          )
        )
      );
    }
  }
}