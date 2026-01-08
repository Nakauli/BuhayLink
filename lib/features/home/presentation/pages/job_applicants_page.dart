import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../jobs/data/repositories/job_repository.dart';
import 'public_profile_page.dart';

class JobApplicantsPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  // [NEW] Parameter to filter for hired team only
  final bool showHiredOnly;

  const JobApplicantsPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
    this.showHiredOnly = false, // Default to showing all applicants
  });

  @override
  State<JobApplicantsPage> createState() => _JobApplicantsPageState();
}

class _JobApplicantsPageState extends State<JobApplicantsPage> {
  final JobRepository _jobRepository = JobRepository();

  // --- 1. TIME HELPER ---
  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown";
    final DateTime appliedTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(appliedTime);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${appliedTime.month}/${appliedTime.day}/${appliedTime.year}";
  }

  // --- 2. HIRE FUNCTION ---
  Future<void> _hireApplicant(String applicantId, String applicantName) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Hire $applicantName?"),
        content: const Text(
          "This will mark them as hired. You can hire multiple people. Click 'Start Job' in the details page when ready.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Yes, Hire"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _jobRepository.hireApplicant(
        widget.jobId,
        applicantId,
        widget.jobTitle,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("You hired $applicantName!")));
        setState(() {});
      }
    }
  }

  // --- 3. REJECT FUNCTION ---
  Future<void> _rejectApplicant(String applicantId) async {
    await _jobRepository.rejectApplicant(widget.jobId, applicantId);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Applicant rejected.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          // [UPDATED] Dynamic Title
          widget.showHiredOnly ? "Hired Team" : "Applicants",
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .collection('applicants')
            .orderBy('appliedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Error Handling
          if (snapshot.hasError) {
            return Center(
              child: Text("Something went wrong: ${snapshot.error}"),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    size: 60,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.showHiredOnly
                        ? "No hired members yet."
                        : "No active applicants.",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // FIX: Safer filtering logic based on showHiredOnly parameter
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';

            if (widget.showHiredOnly) {
              // Only show hired or completed
              return status == 'hired' || status == 'completed';
            } else {
              // Show everyone EXCEPT rejected
              return status != 'rejected';
            }
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Text(
                widget.showHiredOnly
                    ? "No hired members yet."
                    : "No active applicants.",
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var doc = docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String applicantId = doc.id;

              // Safe Data Handling
              String name = data['name'] ?? "Unknown";
              String photoUrl = data['photoUrl'] ?? "";
              Timestamp? appliedAt = data['appliedAt'];

              // --- Check Status ---
              String status = data['status'] ?? 'pending';
              bool isHired = status == 'hired' || status == 'completed';

              // --- 4. SWIPE TO REJECT WRAPPER ---
              // [UPDATED] Disable swipe if we are in "Hired Team" mode
              bool canDismiss = !widget.showHiredOnly && !isHired;

              return Dismissible(
                key: Key(applicantId),
                direction: canDismiss
                    ? DismissDirection.endToStart
                    : DismissDirection.none,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_forever,
                    color: Colors.red,
                    size: 30,
                  ),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Reject Applicant?"),
                      content: Text("Are you sure you want to reject $name?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            "Reject",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  _rejectApplicant(applicantId);
                },
                child: InkWell(
                  onTap: () {
                    // Navigate to Public Profile
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfilePage(
                          userId: applicantId,
                          userName: name,
                          // [FIX]: Set to FALSE so we can see the applicant's resume & skills
                          isEmployerProfile: false,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHired
                          ? Colors.green.shade50
                          : Colors.white, // Highlight if hired
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHired
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.blue.shade50,
                          backgroundImage: (photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _timeAgo(appliedAt),
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // --- SHOW HIRED BADGE OR HIRE BUTTON ---
                        if (isHired)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Hired",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _hireApplicant(applicantId, name),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Hire",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
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
