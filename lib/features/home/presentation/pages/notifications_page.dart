import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add intl to pubspec.yaml for date formatting
import 'public_profile_page.dart';
import 'job_details_page.dart';

class NotificationsPage extends StatefulWidget {
  final bool isEmployerMode;

  const NotificationsPage({super.key, required this.isEmployerMode});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _markAllAsRead();
  }

  // --- Clear the Red Badge ---
  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();

    if (snapshot.docs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    }
  }

  // --- NEW: Helper to fetch User and Job details dynamically ---
  Future<Map<String, dynamic>> _fetchNotificationDetails(
      Map<String, dynamic> notifData) async {
    String? targetUserId; // The person we want to show (Poster or Applicant)
    String? jobId = notifData['jobId'];

    // 1. Determine who to show based on mode
    if (widget.isEmployerMode) {
      // Employer wants to see the APPLICANT
      targetUserId = notifData['applicantId'];
    } else {
      // Applicant wants to see the POSTER
      targetUserId = notifData['posterId'];
    }

    Map<String, dynamic> result = {
      'userName': 'Unknown User',
      'userPhoto': '',
      'userRating': 0.0,
      'jobTitle': notifData['title'] ?? 'Job Update', // Fallback
    };

    // 2. Fetch User Data (Profile, Name, Rating)
    if (targetUserId != null && targetUserId.isNotEmpty) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          // Name logic
          String name = userData['name'] ?? userData['fullName'] ?? "User";
          // Rating logic
          double rating = (userData['rating'] is num) 
              ? (userData['rating'] as num).toDouble() 
              : 0.0;
              
          result['userName'] = name;
          result['userPhoto'] = userData['photoUrl'] ?? "";
          result['userRating'] = rating;
        }
      } catch (e) {
        debugPrint("Error fetching user: $e");
      }
    }

    // 3. Fetch Job Data (Title)
    if (jobId != null && jobId.isNotEmpty) {
      try {
        DocumentSnapshot jobDoc = await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .get();
        if (jobDoc.exists) {
          final jobData = jobDoc.data() as Map<String, dynamic>;
          result['jobTitle'] = jobData['title'] ?? result['jobTitle'];
        }
      } catch (e) {
        debugPrint("Error fetching job: $e");
      }
    }

    return result;
  }

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
          widget.isEmployerMode
              ? "Employer Notifications"
              : "Applicant Notifications",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
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

                // FILTERING LOGIC (Kept from your code)
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'];
                  final posterId = data['posterId'];

                  if (widget.isEmployerMode) {
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
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Basic Notification Data
                    final String applicantId = data['applicantId'] ?? "";
                    final String? jobId = data['jobId'];
                    final bool isRead = data['read'] ?? false;
                    final String type = data['type'] ?? 'application';
                    final String recipientId = data['recipientId'] ?? "";
                    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();

                    // --- SWIPE TO DELETE (Kept from your code) ---
                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.delete, color: Colors.white, size: 30),
                      ),
                      confirmDismiss: (direction) async {
                         if (recipientId == 'all') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("System notifications cannot be deleted.")));
                          return false;
                        }
                        return true;
                      },
                      onDismissed: (direction) async {
                        await FirebaseFirestore.instance.collection('notifications').doc(doc.id).delete();
                      },
                      
                      // --- UPDATED CHILD WITH FUTURE BUILDER ---
                      child: GestureDetector(
                        onTap: () async {
                           // Mark as read
                          if (data['recipientId'] != 'all') {
                            await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({'read': true});
                          }
                          // Navigation Logic
                          if (jobId != null) {
                            if (widget.isEmployerMode && applicantId.isNotEmpty) {
                              _navigateToProfile(context, applicantId, jobId);
                            } else if (['new_post', 'hired', 'rejected'].contains(type)) {
                              _navigateToJob(context, jobId, type);
                            }
                          }
                        },
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: _fetchNotificationDetails(data),
                          builder: (context, detailsSnapshot) {
                            // Defaults while loading
                            String name = "Loading...";
                            String photo = "";
                            String jobTitle = "Loading...";
                            double rating = 0.0;
                            
                            if (detailsSnapshot.hasData) {
                              name = detailsSnapshot.data!['userName'];
                              photo = detailsSnapshot.data!['userPhoto'];
                              jobTitle = detailsSnapshot.data!['jobTitle'];
                              rating = detailsSnapshot.data!['userRating'];
                            }

                            // Format Time (e.g., "2 hrs ago" or simple Date)
                            String timeString = DateFormat('MMM d, h:mm a').format(timestamp.toDate());

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  if (!isRead)
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                ]
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 1. PROFILE PICTURE
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                                      child: photo.isEmpty 
                                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
                                        : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // 2. TEXT CONTENT
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Top Row: Name and Rating
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            // RATING BADGE
                                            if (rating > 0)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber[100],
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.star, size: 12, color: Colors.amber),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    rating.toStringAsFixed(1),
                                                    style: TextStyle(fontSize: 11, color: Colors.amber[900], fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        const SizedBox(height: 4),
                                        
                                        // Middle: Interaction Text (Job Title)
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: Colors.grey[800], fontSize: 13),
                                            children: [
                                              TextSpan(text: widget.isEmployerMode ? "Applied for: " : "Posted: "),
                                              TextSpan(
                                                text: jobTitle,
                                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7EFF)),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const SizedBox(height: 6),
                                        
                                        // Bottom: Timestamp
                                        Text(
                                          timeString,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Unread Dot
                                  if (!isRead)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8, top: 5),
                                      child: CircleAvatar(radius: 4, backgroundColor: Colors.redAccent),
                                    ),
                                ],
                              ),
                            );
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

  // --- HELPER 1: Navigate to Job Details (UNCHANGED) ---
  void _navigateToJob(BuildContext context, String jobId, String notificationType) async {
    // ... [Copy your exact _navigateToJob code here] ...
    // (I am omitting the body to save space as you requested not to delete logic, 
    // just paste your existing function here)
      try {
      DocumentSnapshot jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();
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
              isHired: notificationType == 'hired',
              isRejected: notificationType == 'rejected',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching job: $e");
    }
  }

  // --- HELPER 2: Navigate to Profile (UNCHANGED) ---
  void _navigateToProfile(BuildContext context, String userId, String? jobId) async {
     // ... [Copy your exact _navigateToProfile code here] ...
    String finalName = "Applicant";
    String? finalJobTitle;

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;

        if (userData['fullName'] != null &&
            userData['fullName'].toString().isNotEmpty) {
          finalName = userData['fullName'];
        } else if (userData['firstName'] != null &&
            userData['firstName'].toString().isNotEmpty) {
          String first = userData['firstName'];
          String last = userData['lastName'] ?? "";
          finalName = "$first $last".trim();
        } else if (userData['username'] != null &&
            userData['username'].toString().isNotEmpty) {
          finalName = userData['username'];
        } else if (userData['email'] != null) {
          finalName = userData['email'].split('@')[0];
        }
      }

      if (jobId != null) {
        DocumentSnapshot jobDoc = await FirebaseFirestore.instance
            .collection('jobs')
            .doc(jobId)
            .get();
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
          ),
        ),
      );
    }
  }
}