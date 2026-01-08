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
  bool _hasRated = false;

  // UX Fix: Start loading as TRUE to prevent button flicker
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
      // Fetch async data in parallel for speed
      final results = await Future.wait([
        _jobRepository.hasApplied(widget.jobId),
        _jobRepository.isJobSaved(widget.jobId),
      ]);

      bool rated = false;
      String targetId = "";
      final String posterId =
          widget.job['posterId'] ?? widget.job['postedBy'] ?? "";
      final String hiredId = widget.job['hiredApplicantId'] ?? "";

      // Logic to check if rating is allowed/done
      if (currentUser.uid == posterId) {
        targetId = hiredId;
      } else if (currentUser.uid == hiredId) {
        targetId = posterId;
      }

      if (targetId.isNotEmpty) {
        rated = await _jobRepository.hasUserRated(targetId, widget.jobId);
      }

      if (mounted) {
        setState(() {
          _hasApplied = results[0];
          _isSaved = results[1];
          _hasRated = rated;
          _isLoadingState = false; // Reveal the UI only after data is ready
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingState = false);
    }
  }

  // [NEW] Start Job Logic
  Future<void> _startJob() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Start Job?"),
        content: const Text(
          "This will officially start the job with the current hired applicants. No more applicants can be hired.",
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
            ),
            child: const Text("Start Now"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _jobRepository.startJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Job Started!")));
      }
    }
  }

  // [UPDATED] Mark Complete (Now handles multiple hires in repo)
  Future<void> _markAsComplete() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark as Completed?"),
        content: const Text(
          "Confirm that the work has been done satisfactorily for all hired workers.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _jobRepository.markJobComplete(widget.jobId);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job marked as completed!")),
        );
    }
  }

  void _showRatingDialog(Map<String, dynamic> liveData) {
    // ... (Rating dialog logic same as before) ...
    // [Keeping existing code logic for brevity, just updating _buildOwnerActionButton]
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String employerId = liveData['posterId'] ?? liveData['postedBy'];
    final String? workerId = liveData['hiredApplicantId'];
    String targetId = "";

    if (currentUser.uid == employerId) {
      if (workerId == null || workerId.isEmpty) return;
      targetId = workerId;
    } else if (currentUser.uid == workerId) {
      targetId = employerId;
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => RateUserDialog(
        targetUserId: targetId,
        jobId: widget.jobId,
        onSubmit: (rating, review) async {
          try {
            await _jobRepository.rateUser(
              targetUserId: targetId,
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
              if (msg.contains("already rated"))
                setState(() => _hasRated = true);
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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Application Sent!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
    // ... (Existing delete logic) ...
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

  void _viewHiredApplicants(String title) {
    // Navigate to applicants page to see list (you can add filter logic there later)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JobApplicantsPage(jobId: widget.jobId, jobTitle: title),
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

        // [NEW] Get hired count safely
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

          // --- FLOATING ACTION BAR (Modern UX) ---
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
                        // [UPDATED] Pass hiredCount to owner buttons
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
                // 1. EPIC HEADER
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
                          // [UPDATED] Status Chips
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
                          // [UPDATED] Clickable Applicants Card
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

  // --- BUTTON HELPERS ---
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

          // [NEW] Show Start Job if anyone hired
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
          // [NEW] View Hired List
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _viewHiredApplicants(data['title']),
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
          // [UPDATED] Mark Complete
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
          onPressed: _hasRated ? null : () => _showRatingDialog(data),
          style: _primaryBtnStyle(_hasRated ? Colors.grey : Colors.amber[800]!),
          child: Text(_hasRated ? "You Rated This Worker" : "Rate Worker"),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildWorkerActionButton(String status, Map<String, dynamic> data) {
    // Keep existing logic for workers
    if (status == 'completed') {
      // ... (Existing completed logic) ...
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _hasRated ? null : () => _showRatingDialog(data),
          style: _primaryBtnStyle(_hasRated ? Colors.grey : Colors.amber[800]!),
          child: Text(_hasRated ? "You Rated This Employer" : "Rate Employer"),
        ),
      );
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
