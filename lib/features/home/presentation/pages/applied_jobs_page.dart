import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../jobs/data/repositories/job_repository.dart';
import 'job_details_page.dart';

class AppliedJobsPage extends StatefulWidget {
  final bool showBackButton;

  const AppliedJobsPage({super.key, this.showBackButton = true});

  @override
  State<AppliedJobsPage> createState() => _AppliedJobsPageState();
}

class _AppliedJobsPageState extends State<AppliedJobsPage> {
  final JobRepository _jobRepository = JobRepository();

  @override
  void initState() {
    super.initState();
    _jobRepository.syncApplicationCount();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "My Applications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
              stream: _jobRepository.getApplicationsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "No applications yet",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (direction) =>
                          _showWithdrawDialog(context),
                      background: _buildDismissBackground(),
                      onDismissed: (direction) =>
                          _jobRepository.withdrawApplication(doc.id),
                      child: _buildApplicationCard(context, data),
                    );
                  },
                );
              },
            ),
    );
  }

  // --- UI COMPONENTS ---

  Future<bool?> _showWithdrawDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Withdraw Application?"),
        content: const Text(
          "Are you sure you want to remove this job application?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Withdraw",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Icon(Icons.delete_outline, color: Colors.red[700]),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    Map<String, dynamic> initialData,
  ) {
    final String jobId = initialData['jobId'];
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return const SizedBox.shrink();

    // 1. STREAM THE REAL STATUS directly from the Job's Applicant List
    // This ignores the local copy and looks at what the Employer actually set.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .collection('applicants')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, statusSnapshot) {
        // Determine Status
        String status = initialData['status'] ?? "Applied"; // Default

        if (statusSnapshot.hasData && statusSnapshot.data!.exists) {
          final liveData = statusSnapshot.data!.data() as Map<String, dynamic>;
          status = liveData['status'] ?? status;
        }

        // --- STATUS LOGIC & STYLING ---
        String lowerStatus = status.toLowerCase().trim();
        bool isRejected = lowerStatus == 'rejected';

        // Colors
        Color statusColor = Colors.orange;
        Color statusBg = Colors.orange.shade50;
        IconData statusIcon = Icons.hourglass_empty_rounded;
        String displayStatus = "Applied";

        // Card Appearance
        Color cardBg = Colors.white;
        Color textColor = Colors.black87;
        Color priceColor = const Color(0xFF2E7EFF);
        double opacity = 1.0;
        List<BoxShadow> shadows = [
          BoxShadow(
            color: const Color(0xFF2E7EFF).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ];

        if (lowerStatus == 'hired') {
          statusColor = Colors.green;
          statusBg = Colors.green.shade50;
          statusIcon = Icons.check_circle_rounded;
          displayStatus = "Hired";
        } else if (lowerStatus == 'completed') {
          statusColor = const Color(0xFF2E7EFF);
          statusBg = const Color(0xFF2E7EFF).withOpacity(0.1);
          statusIcon = Icons.task_alt_rounded;
          displayStatus = "Completed";
        } else if (isRejected) {
          // --- REJECTED STYLING ---
          statusColor = Colors.red;
          statusBg = Colors.white;
          statusIcon = Icons.cancel_outlined;
          displayStatus = "Rejected";

          cardBg = Colors.grey[200]!; // Gray Box
          textColor = Colors.grey[600]!; // Dim Text
          priceColor = Colors.grey[500]!; // Dim Price
          opacity = 0.6; // Fade effect
          shadows = []; // Flat look
        }

        // 2. STREAM JOB DETAILS (Title, Price, Employer)
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .snapshots(),
          builder: (context, jobSnapshot) {
            // Data Fallbacks
            String title = initialData['title'] ?? "Loading...";
            String price = "N/A";
            String posterId = initialData['posterId'] ?? "";

            if (jobSnapshot.hasData && jobSnapshot.data!.exists) {
              final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;
              title = jobData['title'] ?? title;
              posterId = jobData['postedBy'] ?? jobData['posterId'] ?? posterId;

              // Price Formatting
              if (jobData['budgetMin'] != null &&
                  jobData['budgetMax'] != null) {
                price = "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}";
              } else {
                price = jobData['price']?.toString() ?? "Negotiable";
              }
            } else if (jobSnapshot.connectionState == ConnectionState.done &&
                !jobSnapshot.data!.exists) {
              title = "Job Deleted";
            }

            // 3. STREAM EMPLOYER DETAILS
            return StreamBuilder<DocumentSnapshot>(
              stream: posterId.isNotEmpty
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(posterId)
                        .snapshots()
                  : null,
              builder: (context, userSnapshot) {
                String empName = "Employer";
                String? empPhoto;

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;
                  empName = userData['fullName'] ?? userData['name'] ?? empName;
                  empPhoto = userData['profileImage'] ?? userData['photoUrl'];
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: shadows,
                    border: isRejected
                        ? null
                        : Border.all(color: Colors.grey.shade100),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _navigateToJob(
                        context,
                        jobId,
                        status, // Pass the LIVE status
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Opacity(
                          opacity: opacity,
                          child: Column(
                            children: [
                              // --- HEADER: Employer & Status ---
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isRejected
                                        ? Colors.white
                                        : Colors.grey[100],
                                    backgroundImage:
                                        (empPhoto != null &&
                                            empPhoto.isNotEmpty)
                                        ? NetworkImage(empPhoto)
                                        : null,
                                    child:
                                        (empPhoto == null || empPhoto.isEmpty)
                                        ? Text(
                                            empName[0].toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      empName,
                                      style: TextStyle(
                                        color: isRejected
                                            ? Colors.grey[700]
                                            : Colors.grey[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // STATUS BADGE
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isRejected
                                          ? Border.all(
                                              color: Colors.red.withOpacity(
                                                0.2,
                                              ),
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          statusIcon,
                                          size: 12,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          displayStatus,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Divider(
                                  height: 1,
                                  color: Color(0xFFE0E0E0),
                                ),
                              ),
                              // --- BODY: Job Title & Price ---
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          price,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: priceColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // --- FOOTER: Date ---
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Applied recently", // You can parse date here if needed
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _navigateToJob(
    BuildContext context,
    String? jobId,
    String liveStatus,
  ) async {
    if (jobId == null) return;
    try {
      DocumentSnapshot jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();
      if (jobDoc.exists && context.mounted) {
        final jobData = jobDoc.data() as Map<String, dynamic>;

        // Price Parser for Detail Page
        String displayPrice = "Negotiable";
        if (jobData['budgetMin'] != null && jobData['budgetMax'] != null) {
          displayPrice = "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}";
        } else {
          displayPrice = jobData['price']?.toString() ?? "Negotiable";
        }

        final Map<String, dynamic> jobMap = {
          "title": jobData['title'] ?? "Unknown",
          "tag": jobData['category'] ?? "General",
          "price": displayPrice,
          "location": jobData['location'] ?? "Remote",
          "user": jobData['posterName'] ?? "Employer",
          "posterId": jobData['postedBy'],
          "applicants": "${jobData['applicants'] ?? 0} applicants",
          "description": jobData['description'] ?? "No description",
          "posterPhoto": jobData['posterPhoto'],
          "status": liveStatus, // Pass the LIVE status from the card
        };

        bool isRejected = liveStatus.toLowerCase().contains('rejected');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(
              job: jobMap,
              jobId: jobId,
              isRejected: isRejected,
            ),
          ),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This job is no longer available.")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}
