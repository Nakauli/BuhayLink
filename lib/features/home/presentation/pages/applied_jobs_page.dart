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
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.black,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          "My Applications",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
    Map<String, dynamic> data,
  ) {
    // 1. Extract Data
    final String title = data['title'] ?? "Unknown Job";
    final String price = data['price'] ?? "N/A";
    final String rawStatus = data['status'] ?? "Applied";
    final String status = rawStatus.isEmpty ? "Applied" : rawStatus; // Fallback
    final Timestamp? timestamp = data['timestamp'];

    // 2. Format Date
    String dateStr = "Recently";
    if (timestamp != null) {
      dateStr = DateFormat('MMM d, yyyy').format(timestamp.toDate());
    }

    // 3. COLOR HIERARCHY LOGIC
    Color statusColor = Colors.orange; // Default: Pending/Applied
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
      statusColor = const Color(0xFF2E7EFF); // Blue for Completed
      statusBg = const Color(0xFF2E7EFF).withOpacity(0.1);
      statusIcon = Icons.task_alt_rounded;
      displayStatus = "Completed";
    } else if (lowerStatus == 'rejected') {
      statusColor = Colors.red;
      statusBg = Colors.red.shade50;
      statusIcon = Icons.cancel_outlined;
      displayStatus = "Rejected";
    } else {
      // Default Applied
      displayStatus = "Applied";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7EFF).withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _navigateToJob(context, data['jobId']),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Icon + Title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Gradient Icon Box (Consistent UI)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title and Price
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            price,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2E7EFF), // Brand color for price
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 12),

                // Bottom Row: Date + Colored Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                          ),
                        ),
                      ],
                    ),

                    // DYNAMIC STATUS BADGE
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            displayStatus,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
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
  }

  void _navigateToJob(BuildContext context, String? jobId) async {
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

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId),
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
