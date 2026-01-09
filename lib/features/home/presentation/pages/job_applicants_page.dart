import 'package:buhay_link/widgets/rate_user_dialog.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../jobs/data/repositories/job_repository.dart';
import 'public_profile_page.dart';

class JobApplicantsPage extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final bool showHiredOnly;
  final bool allowRating;

  const JobApplicantsPage({
    super.key,
    required this.jobId,
    required this.jobTitle,
    this.showHiredOnly = false,
    this.allowRating = false,
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

  // --- 4. RATE FUNCTION (FIXED CRASH) ---
  void _rateApplicant(String applicantId) {
    showDialog(
      context: context,
      // [FIX 1] Rename this to 'dialogContext' to avoid shadowing the main 'context'
      builder: (dialogContext) => RateUserDialog(
        targetUserId: applicantId,
        jobId: widget.jobId,
        onSubmit: (rating, review) async {
          try {
            await _jobRepository.rateUser(
              targetUserId: applicantId,
              rating: rating,
              review: review,
              jobId: widget.jobId,
            );

            // Check if page is still mounted before using 'context'
            if (mounted) {
              // [FIX 2] Use 'context' (from State), NOT 'dialogContext'
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Rating submitted successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
              // Trigger rebuild to update the "Rate" button to "Rated"
              setState(() {});
            }
          } catch (e) {
            if (mounted) {
              String msg = e.toString().contains("already rated")
                  ? "You already rated this user."
                  : "Error submitting rating.";
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
              // If already rated, we still want to update UI to disable button
              if (msg.contains("already rated")) setState(() {});
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.showHiredOnly
              ? (widget.allowRating ? "Rate Team" : "Hired Team")
              : "Applicants",
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
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                widget.showHiredOnly
                    ? "No hired members yet."
                    : "No active applicants.",
                style: const TextStyle(color: Colors.grey),
              ),
            );
          }

          // Filter Logic
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';

            if (widget.showHiredOnly) {
              return status == 'hired' || status == 'completed';
            } else {
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
              String name = data['name'] ?? "Unknown";
              String photoUrl = data['photoUrl'] ?? "";
              Timestamp? appliedAt = data['appliedAt'];
              String status = data['status'] ?? 'pending';
              bool isHired = status == 'hired' || status == 'completed';

              // Disable swipe if in Hired/Rate mode
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
                  child: const Icon(Icons.delete_forever, color: Colors.red),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Reject Applicant?"),
                      content: Text("Reject $name?"),
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
                onDismissed: (_) => _rejectApplicant(applicantId),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfilePage(
                          userId: applicantId,
                          userName: name,
                          isEmployerProfile: false,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isHired ? Colors.green.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isHired
                            ? Colors.green.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty ? Text(name[0]) : null,
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
                                ),
                              ),
                              Text(
                                _timeAgo(appliedAt),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // --- BUTTON LOGIC ---
                        if (widget.allowRating)
                          // [FIX 3] Use FutureBuilder to check if ALREADY RATED
                          FutureBuilder<bool>(
                            future: _jobRepository.hasUserRated(
                              applicantId,
                              widget.jobId,
                            ),
                            builder: (context, snapshot) {
                              // While loading, show nothing or spinner
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                );
                              }

                              bool isRated = snapshot.data ?? false;

                              if (isRated) {
                                return const Chip(
                                  label: Text(
                                    "Rated",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  backgroundColor: Color(0xFFEEEEEE),
                                );
                              }

                              return ElevatedButton(
                                onPressed: () => _rateApplicant(applicantId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                ),
                                child: const Text("Rate"),
                              );
                            },
                          )
                        else if (isHired)
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
                            ),
                            child: const Text("Hire"),
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
