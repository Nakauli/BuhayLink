import 'package:buhay_link/widgets/rate_user_dialog.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Ensure this path matches your project structure
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
    required this.job, // kept as required but we prefer live data
    required this.jobId,
    this.isHired = false,
    this.isRejected = false,
  });

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  final JobRepository _jobRepository = JobRepository();
  bool _isApplying = false;
  bool _hasApplied = false;
  bool _isSaved = false;

  // --- NEW: Track if already rated ---
  bool _hasRated = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final applied = await _jobRepository.hasApplied(widget.jobId);
    final saved = await _jobRepository.isJobSaved(widget.jobId);

    // --- CHECK IF ALREADY RATED ---
    bool rated = false;
    String targetId = "";

    // Check against the initial data first (live updates handled in build)
    final String posterId =
        widget.job['posterId'] ?? widget.job['postedBy'] ?? "";
    final String hiredId = widget.job['hiredApplicantId'] ?? "";

    if (currentUser.uid == posterId) {
      // I am Employer -> Check if I rated Worker
      targetId = hiredId;
    } else if (currentUser.uid == hiredId) {
      // I am THE HIRED Worker -> Check if I rated Employer
      targetId = posterId;
    }

    if (targetId.isNotEmpty) {
      rated = await _jobRepository.hasUserRated(targetId, widget.jobId);
    }
    // ------------------------------

    if (mounted) {
      setState(() {
        _hasApplied = applied;
        _isSaved = saved;
        _hasRated = rated;
      });
    }
  }

  // --- SMART MARK AS COMPLETE (Fixes "No ID" Error) ---
  Future<void> _markAsComplete(Map<String, dynamic> liveData) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark as Completed?"),
        content: const Text(
          "Confirm that the work has been done satisfactorily. You will then be able to rate the worker.",
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
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. Try to get ID from live data
      String workerId = liveData['hiredApplicantId'] ?? "";

      // 2. FALLBACK: If missing, find who is marked as 'hired' in subcollection
      if (workerId.isEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('jobs')
            .doc(widget.jobId)
            .collection('applicants')
            .where('status', isEqualTo: 'hired')
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          workerId = snapshot.docs.first.id;
          // Self-heal the database
          await _jobRepository.updateJob(widget.jobId, {
            'hiredApplicantId': workerId,
          });
        }
      }

      if (workerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Error: No hired worker found in database."),
          ),
        );
        return;
      }

      await _jobRepository.markJobComplete(widget.jobId, workerId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Job marked as completed!")),
        );
      }
    }
  }

  // --- RATING DIALOG ---
  void _showRatingDialog(Map<String, dynamic> liveData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String employerId = liveData['posterId'] ?? liveData['postedBy'];
    final String? workerId = liveData['hiredApplicantId'];

    String targetId = "";
    String targetName = "User";

    if (currentUser.uid == employerId) {
      // I am Employer -> Rate Worker
      if (workerId == null || workerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No worker to rate found.")),
        );
        return;
      }
      targetId = workerId;
      targetName = "the Worker";
    } else if (currentUser.uid == workerId) {
      // I am THE HIRED Worker -> Rate Employer
      targetId = employerId;
      targetName = "the Employer";
    } else {
      // I am a random user (Safety Check)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You are not authorized to rate this job."),
        ),
      );
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
              // --- UPDATE UI IMMEDIATELY ---
              setState(() {
                _hasRated = true;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("You rated $targetName successfully!"),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            // Handle duplicate error gracefully
            if (mounted) {
              String msg = e.toString().replaceAll("Exception: ", "");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: Colors.red),
              );
              // If already rated, make sure UI reflects that
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

  // --- DELETE FUNCTION ---
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Job?"),
        content: const Text(
          "Are you sure you want to remove this job post? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _jobRepository.deleteJob(widget.jobId);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Job deleted successfully")),
                );
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- EDIT FUNCTION ---
  void _showEditDialog() {
    final titleCtrl = TextEditingController(text: widget.job['title']);
    final categoryCtrl = TextEditingController(
      text: widget.job['tag'] ?? widget.job['category'] ?? "",
    );
    final locationCtrl = TextEditingController(text: widget.job['location']);
    final descCtrl = TextEditingController(text: widget.job['description']);
    final minBudgetCtrl = TextEditingController(
      text: (widget.job['budgetMin'] ?? 0).toString(),
    );
    final maxBudgetCtrl = TextEditingController(
      text: (widget.job['budgetMax'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Edit Job Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Job Title",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(
                  labelText: "Location",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minBudgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Min Budget",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxBudgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Max Budget",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _jobRepository.updateJob(widget.jobId, {
                'title': titleCtrl.text,
                'category': categoryCtrl.text,
                'location': locationCtrl.text,
                'description': descCtrl.text,
                'budgetMin': double.tryParse(minBudgetCtrl.text) ?? 0,
                'budgetMax': double.tryParse(maxBudgetCtrl.text) ?? 0,
              });
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Job Updated!")));
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. STREAM BUILDER: Listens for updates (This fixes the sync issues)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Error / Deleted
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Center(child: Text("Job not found or deleted.")),
          );
        }

        // Live Data
        final data = snapshot.data!.data() as Map<String, dynamic>;

        final currentUser = FirebaseAuth.instance.currentUser;
        final String currentUid = currentUser?.uid ?? "";
        final String posterId = data['posterId'] ?? data['postedBy'] ?? "";
        final bool isOwner = currentUid.isNotEmpty && currentUid == posterId;
        final String status = data['status'] ?? 'open';

        return Scaffold(
          backgroundColor: Colors.white,

          // --- APP BAR ---
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Job Details",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _showEditDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _confirmDelete,
                ),
              ] else
                IconButton(
                  icon: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: _isSaved ? const Color(0xFF2E7EFF) : Colors.black,
                  ),
                  onPressed: () => _toggleSaveJob(data),
                ),
            ],
          ),

          // --- STICKY BOTTOM ACTION BAR ---
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: isOwner
                  ? _buildOwnerActionButton(status, data, context)
                  : _buildWorkerActionButton(status, data),
            ),
          ),

          // --- MAIN SCROLLABLE CONTENT ---
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // 1. STATUS BADGES & TAGS
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                      const Chip(
                        label: Text(
                          "Completed",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    else if (status == 'hired')
                      const Chip(
                        label: Text(
                          "Hired",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: Colors.orange,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. TITLE & PRICE
                Text(
                  data['title'] ?? "Job Title",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['price'] ??
                      "₱${data['budgetMin']} - ₱${data['budgetMax']}",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7EFF),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. STATS GRID (Cleaner Look)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        Icons.location_on,
                        "Location",
                        data['location'] ?? "Remote",
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        Icons.access_time_filled,
                        "Duration",
                        data['duration'] ?? "N/A",
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        Icons.people,
                        "Applicants",
                        "${data['applicants'] ?? 0}",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 4. DESCRIPTION
                const Text(
                  "Job Description",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  data['description'] ?? "No description provided.",
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // 5. EMPLOYER / POSTER CARD
                if (!isOwner) _buildEmployerCard(data),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- BUTTON BUILDERS (UPDATED TO DISABLE IF RATED) ---

  Widget _buildOwnerActionButton(
    String status,
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    if (status == 'open') {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobApplicantsPage(
                jobId: widget.jobId,
                jobTitle: data['title'],
              ),
            ),
          );
        },
        icon: const Icon(Icons.people_alt_outlined),
        label: const Text("View Applicants"),
        style: _actionButtonStyle(const Color(0xFF2E7EFF)),
      );
    } else if (status == 'hired') {
      return ElevatedButton.icon(
        onPressed: () => _markAsComplete(data),
        icon: const Icon(Icons.check_circle_outline),
        label: const Text("Mark as Completed"),
        style: _actionButtonStyle(Colors.green),
      );
    } else if (status == 'completed') {
      // --- CHECK IF ALREADY RATED ---
      if (_hasRated) {
        return ElevatedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.check, color: Colors.grey),
          label: const Text(
            "You have rated this user",
            style: TextStyle(color: Colors.grey),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      // ------------------------------
      return ElevatedButton.icon(
        onPressed: () => _showRatingDialog(data),
        icon: const Icon(Icons.star),
        label: const Text("Rate Worker"),
        style: _actionButtonStyle(Colors.amber[800]!),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildWorkerActionButton(String status, Map<String, dynamic> data) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? "";
    final hiredId = data['hiredApplicantId'] ?? "";

    if (status == 'completed') {
      // --- SECURITY CHECK: ONLY HIRED WORKER CAN RATE ---
      if (currentUid != hiredId) {
        return ElevatedButton(
          onPressed: null, // Disabled
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            "Position Filled (Closed)",
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      // --- CHECK IF ALREADY RATED ---
      if (_hasRated) {
        return ElevatedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.check, color: Colors.grey),
          label: const Text(
            "You have rated this user",
            style: TextStyle(color: Colors.grey),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[300],
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      // ------------------------------
      return ElevatedButton.icon(
        onPressed: () => _showRatingDialog(data),
        icon: const Icon(Icons.star),
        label: const Text("Rate Employer"),
        style: _actionButtonStyle(Colors.amber[800]!),
      );
    }

    return ElevatedButton(
      onPressed: (_isApplying || _hasApplied || status != 'open')
          ? null
          : () => _applyForJob(data),
      style: _actionButtonStyle(
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
                  ? "Applied"
                  : (status == 'hired' ? "Position Filled" : "Apply Now"),
            ),
    );
  }

  ButtonStyle _actionButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

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

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade300);
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
        int reviews = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final uData = snapshot.data!.data() as Map<String, dynamic>;
          name = uData['fullName'] ?? uData['name'] ?? name;
          photoUrl = uData['profileImage'] ?? uData['photoUrl'];
          rating = (uData['rating'] ?? 0.0).toDouble();
          reviews = uData['reviewCount'] ?? 0;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Text(
                        name[0].toUpperCase(),
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
                      "Posted by",
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (reviews > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "$rating ($reviews reviews)",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (userId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PublicProfilePage(userId: userId, userName: name),
                      ),
                    );
                  }
                },
                child: const Text("View Profile"),
              ),
            ],
          ),
        );
      },
    );
  }
}
