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
      // --- HEADER UPDATED TO MATCH HIRED JOBS FORMAT ---
      appBar: AppBar(
        title: const Text(
          "My Applications",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      // -------------------------------------------------
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
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.assignment_outlined,
                            size: 60,
                            color: Colors.grey[400],
                          ),
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
                        const SizedBox(height: 8),
                        Text(
                          "Start applying to jobs to see them here.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
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
          "Are you sure you want to remove this job application? This action cannot be undone.",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep it", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Withdraw"),
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
        border: Border.all(color: Colors.red.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            "Withdraw",
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.delete_outline, color: Colors.red[700]),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(
    BuildContext context,
    Map<String, dynamic> appData,
  ) {
    // We only rely on Application Data for ID, Status and Date
    final String jobId = appData['jobId'];
    final String rawStatus = appData['status'] ?? "Applied";
    final String status = rawStatus.isEmpty ? "Applied" : rawStatus;
    final Timestamp? timestamp = appData['timestamp'] ?? appData['appliedDate'];

    // 1. Format Date
    String dateStr = "Recently";
    if (timestamp != null) {
      dateStr = DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }

    // 2. Status Badge Config
    Color statusColor = Colors.orange;
    Color statusBg = Colors.orange.shade50;
    IconData statusIcon = Icons.hourglass_empty_rounded;
    String displayStatus = status;
    String lowerStatus = status.toLowerCase();

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
    } else if (lowerStatus == 'rejected') {
      statusColor = Colors.red;
      statusBg = Colors.red.shade50;
      statusIcon = Icons.cancel_outlined;
      displayStatus = "Rejected";
    } else {
      displayStatus = "Applied";
    }

    // --- MAIN FIX: STREAM THE REAL JOB DATA ---
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .snapshots(),
      builder: (context, jobSnapshot) {
        // 3. Fallback Data (if job is loading or deleted)
        String title =
            appData['title'] ?? appData['jobTitle'] ?? "Loading Job...";
        String price = appData['price']?.toString() ?? "N/A";
        String posterId = appData['posterId'] ?? appData['employerId'] ?? "";

        // 4. Overwrite with Live Job Data if available
        if (jobSnapshot.hasData && jobSnapshot.data!.exists) {
          final jobData = jobSnapshot.data!.data() as Map<String, dynamic>;
          title = jobData['title'] ?? title;
          posterId = jobData['postedBy'] ?? jobData['posterId'] ?? posterId;

          // ✅ FIX: Calculate Price exactly like Job Details Page
          if (jobData['budgetMin'] != null && jobData['budgetMax'] != null) {
            price = "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}";
          } else {
            price = jobData['price']?.toString() ?? price;
          }
        } else if (jobSnapshot.connectionState == ConnectionState.done &&
            !jobSnapshot.data!.exists) {
          title = "Job Unavailable (Deleted)";
          price = "N/A";
        }

        // --- SECONDARY STREAM: FETCH EMPLOYER DATA ---
        return StreamBuilder<DocumentSnapshot>(
          stream: posterId.isNotEmpty
              ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(posterId)
                    .snapshots()
              : null,
          builder: (context, userSnapshot) {
            String employerName = "Employer";
            String? employerPhoto;

            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              final userData =
                  userSnapshot.data!.data() as Map<String, dynamic>;
              employerName =
                  userData['fullName'] ?? userData['name'] ?? "Employer";
              employerPhoto = userData['profileImage'] ?? userData['photoUrl'];
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _navigateToJob(context, jobId, lowerStatus),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- TOP ROW: Live Employer Info ---
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.grey[100],
                              backgroundImage:
                                  (employerPhoto != null &&
                                      employerPhoto.isNotEmpty)
                                  ? NetworkImage(employerPhoto)
                                  : null,
                              child:
                                  (employerPhoto == null ||
                                      employerPhoto.isEmpty)
                                  ? Text(
                                      employerName.isNotEmpty
                                          ? employerName[0].toUpperCase()
                                          : "E",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                employerName,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
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
                          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                        ),

                        // --- MIDDLE ROW: Job Info (Live Title & Price) ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    price,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2E7EFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // --- BOTTOM ROW: Metadata ---
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Applied on $dateStr",
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
            );
          },
        );
      },
    );
  }

  void _navigateToJob(
    BuildContext context,
    String? jobId,
    String applicationStatus,
  ) async {
    if (jobId == null) return;
    try {
      DocumentSnapshot jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();
      if (jobDoc.exists && context.mounted) {
        final jobData = jobDoc.data() as Map<String, dynamic>;
        final Map<String, dynamic> jobMap = {
          "title": jobData['title'] ?? "Unknown",
          "tag": jobData['category'] ?? "General",
          "price": "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}",
          "location": jobData['location'] ?? "Remote",
          "user": jobData['posterName'] ?? "Employer",
          "posterId": jobData['postedBy'],
          "applicants": "${jobData['applicants'] ?? 0} applicants",
          "description": jobData['description'] ?? "No description",
          "posterPhoto": jobData['posterPhoto'],
          "status": jobData['status'],
        };

        bool isRejected = applicationStatus == 'rejected';

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
