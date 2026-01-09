import 'package:buhay_link/widgets/rate_user_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../jobs/data/repositories/job_repository.dart';
import 'public_profile_page.dart';
import 'job_applicants_page.dart';

class JobDetailsPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final bool isHired;
  final bool isRejected;

  const JobDetailsPage({
    super.key,
    required this.job,
    required this.jobId,
    this.isHired = false,
    this.isRejected = false,
  });

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  final JobRepository _jobRepository = JobRepository();

  // State variables
  bool _isApplying = false;
  bool _hasApplied = false;
  bool _isSaved = false;
  bool _hasRated = false; // Only used for Worker rating Employer
  bool _isLoadingState = true;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final results = await Future.wait([
        _jobRepository.hasApplied(widget.jobId),
        _jobRepository.isJobSaved(widget.jobId),
      ]);

      bool rated = false;

      // [UPDATED] Logic: Only check rating status here if I am the WORKER rating the EMPLOYER.
      final String posterId =
          widget.job['posterId'] ?? widget.job['postedBy'] ?? "";

      if (currentUser.uid != posterId) {
        // I am a worker, check if I have rated the employer for this job
        rated = await _jobRepository.hasUserRated(posterId, widget.jobId);
      }

      if (mounted) {
        setState(() {
          _hasApplied = results[0];
          _isSaved = results[1];
          _hasRated = rated;
          _isLoadingState = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingState = false);
    }
  }

  // [NEW] Start Job Logic (Updated for Safety)
  Future<void> _startJob() async {
    // 1. Double check confirmation
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Start Job?"),
        content: const Text(
          "This will close applications and change the status to 'In Progress'.\n\nOnly the currently hired applicants will be part of the job.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7EFF),
              foregroundColor: Colors.white,
            ),
            child: const Text("Start Now"),
          ),
        ],
      ),
    );

    // 2. Execute
    if (confirm == true) {
      try {
        await _jobRepository.startJob(widget.jobId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Job successfully started!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error starting job: $e")));
        }
      }
    }
  }

  // [UPDATED] Mark Complete (Handles state transition)
  Future<void> _markAsComplete() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark as Completed?"),
        content: const Text(
          "This confirms all work has been finished. You will then be able to rate your hired workers.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("Confirm Complete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _jobRepository.markJobComplete(widget.jobId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Job marked as completed!")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  // [UPDATED] Helper to navigate to list view (for Viewing or Rating)
  void _viewHiredApplicants(String title, {bool allowRating = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobApplicantsPage(
          jobId: widget.jobId,
          jobTitle: title,
          showHiredOnly: true, // Only show the team
          allowRating: allowRating, // Enable rating buttons if completed
        ),
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> liveData) {
    // This is primarily for the Worker to rate the Employer
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String employerId = liveData['posterId'] ?? liveData['postedBy'];

    // Safety check
    if (currentUser.uid == employerId) return; // Employers don't rate here

    showDialog(
      context: context,
      builder: (context) => RateUserDialog(
        targetUserId: employerId,
        jobId: widget.jobId,
        onSubmit: (rating, review) async {
          try {
            await _jobRepository.rateUser(
              targetUserId: employerId,
              rating: rating,
              review: review,
              jobId: widget.jobId,
            );
            if (mounted) {
              setState(() => _hasRated = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Rating submitted successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              String msg = e.toString().contains("already rated")
                  ? "You already rated this user."
                  : "Error submitting rating.";
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
              if (msg.contains("already rated")) {
                setState(() => _hasRated = true);
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _applyForJob(Map<String, dynamic> liveData) async {
    setState(() => _isApplying = true);
    try {
      await _jobRepository.applyForJob(widget.jobId, liveData);
      setState(() => _hasApplied = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Application Sent!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _toggleSaveJob(Map<String, dynamic> liveData) async {
    setState(() => _isSaved = !_isSaved);
    try {
      await _jobRepository.toggleSaveJob(widget.jobId, liveData, !_isSaved);
    } catch (e) {
      if (mounted) setState(() => _isSaved = !_isSaved);
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Job?"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _jobRepository.deleteJob(widget.jobId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Job deleted")));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text("Job not found.")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final currentUser = FirebaseAuth.instance.currentUser;
        final String currentUid = currentUser?.uid ?? "";
        final String posterId = data['posterId'] ?? data['postedBy'] ?? "";
        final bool isOwner = currentUid.isNotEmpty && currentUid == posterId;
        final String status = data['status'] ?? 'open';
        final int hiredCount = data['hiredCount'] ?? 0;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FD),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              "Job Details",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.black87,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: isOwner
                      ? IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: _confirmDelete,
                        )
                      : IconButton(
                          icon: Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: _isSaved
                                ? const Color(0xFF2E7EFF)
                                : Colors.black87,
                            size: 20,
                          ),
                          onPressed: () => _toggleSaveJob(data),
                        ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _isLoadingState
              ? Container(
                  height: 100,
                  color: Colors.white,
                  child: const Center(child: CircularProgressIndicator()),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    child: isOwner
                        ? _buildOwnerActionButton(
                            status,
                            hiredCount,
                            data,
                            context,
                          )
                        : _buildWorkerActionButton(status, data),
                  ),
                ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 30),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildTag(
                            data['category'] ?? "General",
                            Colors.blue.shade50,
                            Colors.blue.shade700,
                          ),
                          if (data['isUrgent'] == true)
                            _buildTag(
                              "Urgent",
                              Colors.red.shade50,
                              Colors.red.shade700,
                            ),
                          if (status == 'completed')
                            _buildStatusChip(
                              "Completed",
                              Colors.green,
                              Icons.check_circle,
                            )
                          else if (status == 'in_progress')
                            _buildStatusChip(
                              "In Progress",
                              Colors.orange,
                              Icons.run_circle,
                            )
                          else if (status == 'open')
                            _buildStatusChip(
                              "Open",
                              Colors.blue,
                              Icons.lock_open,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        data['title'] ?? "Job Title",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data['price'] ??
                            "₱${data['budgetMin']} - ₱${data['budgetMax']}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7EFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isOwner) _buildEmployerCard(data),
                      if (!isOwner) const SizedBox(height: 24),
                      _buildInfoCard(
                        Icons.location_on,
                        "Location",
                        data['location'] ?? "Remote",
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              Icons.access_time_filled,
                              "Job Duration",
                              data['duration'] ?? "N/A",
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: isOwner
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => JobApplicantsPage(
                                          jobId: widget.jobId,
                                          jobTitle: data['title'],
                                        ),
                                      ),
                                    )
                                  : null,
                              child: _buildInfoCard(
                                Icons.people,
                                "Applicants",
                                "${data['applicants'] ?? 0} people",
                                isClickable: isOwner,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text(
                        "About the Job",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data['description'] ?? "No description provided.",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF555555),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI WIDGETS ---
  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textCol,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value, {
    bool isClickable = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isClickable ? const Color(0xFF2E7EFF) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF2E7EFF), size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.black87,
            ),
            maxLines: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerCard(Map<String, dynamic> jobData) {
    final String userId = jobData['posterId'] ?? jobData['postedBy'] ?? "";
    return StreamBuilder<DocumentSnapshot>(
      stream: userId.isNotEmpty
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        String name = jobData['posterName'] ?? "Employer";
        String? photoUrl;
        double rating = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final uData = snapshot.data!.data() as Map<String, dynamic>;
          name = uData['fullName'] ?? uData['name'] ?? name;
          photoUrl = uData['profileImage'] ?? uData['photoUrl'];
          rating = (uData['rating'] ?? 0.0).toDouble();
        }
        return GestureDetector(
          onTap: () {
            if (userId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicProfilePage(
                    userId: userId,
                    userName: name,
                    isEmployerProfile: true, // Hides resume/skills
                  ),
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7EFF).withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$rating",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            " • View Profile",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ButtonStyle _primaryBtnStyle(Color color) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 0,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  // [UPDATED] Owner Action Buttons Logic
  Widget _buildOwnerActionButton(
    String status,
    int hiredCount,
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    if (status == 'open') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => JobApplicantsPage(
                    jobId: widget.jobId,
                    jobTitle: data['title'],
                  ),
                ),
              ),
              style: _primaryBtnStyle(const Color(0xFF2E7EFF)),
              child: const Text("View Applicants"),
            ),
          ),

          if (hiredCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startJob,
                style: _primaryBtnStyle(Colors.green),
                child: Text("Start Job ($hiredCount Hired)"),
              ),
            ),
          ],
        ],
      );
    } else if (status == 'in_progress') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _viewHiredApplicants(
                data['title'],
                allowRating: false,
              ), // View only
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text("View Hired Team"),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _markAsComplete,
              style: _primaryBtnStyle(Colors.purple),
              child: const Text("Mark as Completed"),
            ),
          ),
        ],
      );
    } else if (status == 'completed') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () =>
              _viewHiredApplicants(data['title'], allowRating: true),
          style: _primaryBtnStyle(Colors.amber[800]!),
          child: const Text("Rate Workers"),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // [FIXED] Updated to check if current user is the hired worker
  Widget _buildWorkerActionButton(String status, Map<String, dynamic> data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final String currentUid = currentUser?.uid ?? "";
    final String hiredId = data['hiredApplicantId'] ?? "";

    if (status == 'completed') {
      // CHECK: Is this the hired worker?
      if (currentUid == hiredId) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _hasRated ? null : () => _showRatingDialog(data),
            style: _primaryBtnStyle(
              _hasRated ? Colors.grey : Colors.amber[800]!,
            ),
            child: Text(
              _hasRated ? "You Rated This Employer" : "Rate Employer",
            ),
          ),
        );
      } else {
        // Not the hired worker (just an observer or rejected applicant)
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: null, // Disabled
            style: _primaryBtnStyle(Colors.grey),
            child: const Text("Job Completed"),
          ),
        );
      }
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isApplying || _hasApplied || status != 'open')
            ? null
            : () => _applyForJob(data),
        style: _primaryBtnStyle(
          _hasApplied ? Colors.green : const Color(0xFF2E7EFF),
        ),
        child: _isApplying
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _hasApplied
                    ? "Application Sent"
                    : (status == 'in_progress'
                          ? "Position Filled"
                          : (status == 'hired' ? "Hiring..." : "Apply Now")),
              ),
      ),
    );
  }
}
