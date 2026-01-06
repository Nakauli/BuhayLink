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
  bool _isApplying = false;
  bool _hasApplied = false;
  bool _isSaved = false;
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

    bool rated = false;
    String targetId = "";
    final String posterId =
        widget.job['posterId'] ?? widget.job['postedBy'] ?? "";
    final String hiredId = widget.job['hiredApplicantId'] ?? "";

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
        _hasApplied = applied;
        _isSaved = saved;
        _hasRated = rated;
      });
    }
  }

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
      String workerId = liveData['hiredApplicantId'] ?? "";

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
          await _jobRepository.updateJob(widget.jobId, {
            'hiredApplicantId': workerId,
          });
        }
      }

      if (workerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No hired worker found.")),
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

  void _showRatingDialog(Map<String, dynamic> liveData) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String employerId = liveData['posterId'] ?? liveData['postedBy'];
    final String? workerId = liveData['hiredApplicantId'];

    String targetId = "";
    String targetName = "User";

    if (currentUser.uid == employerId) {
      if (workerId == null || workerId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No worker to rate found.")),
        );
        return;
      }
      targetId = workerId;
      targetName = "the Worker";
    } else if (currentUser.uid == workerId) {
      targetId = employerId;
      targetName = "the Employer";
    } else {
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
            if (mounted) {
              String msg = e.toString().replaceAll("Exception: ", "");
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg), backgroundColor: Colors.red),
              );
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

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Job?"),
        content: const Text("Are you sure you want to remove this job post?"),
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(leading: const BackButton()),
            body: const Center(child: Text("Job not found.")),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final currentUser = FirebaseAuth.instance.currentUser;
        final String currentUid = currentUser?.uid ?? "";
        final String posterId = data['posterId'] ?? data['postedBy'] ?? "";
        final bool isOwner = currentUid.isNotEmpty && currentUid == posterId;
        final String status = data['status'] ?? 'open';

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Job Details",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
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
                    color: _isSaved ? const Color(0xFF2E7EFF) : Colors.black87,
                  ),
                  onPressed: () => _toggleSaveJob(data),
                ),
            ],
          ),

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

          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER SECTION (Modern Hierarchy)
                const SizedBox(height: 10),

                // Title
                Text(
                  data['title'] ?? "Job Title",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                // Price (Use FittedBox to prevent overflow on small screens)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data['price'] ??
                        "₱${data['budgetMin']} - ₱${data['budgetMax']}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7EFF),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Badges
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
                      _buildChip("Completed", Colors.green)
                    else if (status == 'hired')
                      _buildChip("Hired", Colors.orange),
                  ],
                ),

                const SizedBox(height: 32),

                // 2. MODERN VERTICAL STATS (Solves Address Overflow)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FE), // Subtle bluish-grey bg
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      _buildStatItemRow(
                        Icons.location_on_rounded,
                        "Location",
                        data['location'] ?? "Remote",
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(height: 1, color: Colors.black12),
                      ),
                      _buildStatItemRow(
                        Icons.access_time_filled_rounded,
                        "Duration",
                        data['duration'] ?? "N/A",
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Divider(height: 1, color: Colors.black12),
                      ),
                      _buildStatItemRow(
                        Icons.people_alt_rounded,
                        "Applicants",
                        "${data['applicants'] ?? 0}",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 3. DESCRIPTION
                const Text(
                  "About the job",
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
                    color: Color(0xFF555555),
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 32),
                const Divider(color: Colors.black12),
                const SizedBox(height: 24),

                // 4. EMPLOYER CARD
                if (!isOwner) _buildEmployerCard(data),

                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- MODERN UI HELPERS ---

  Widget _buildStatItemRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Modern Icon Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF2E7EFF), size: 22),
        ),
        const SizedBox(width: 16),
        // Text Column (Wrapped in Expanded to fix overflow)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
                // This allows the address to wrap to multiple lines
                maxLines: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
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

  Widget _buildChip(String label, Color color) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide.none,
      shape: const StadiumBorder(),
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
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: photoUrl != null
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.blue,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // --- FIXED: WRAPPED IN EXPANDED AND ADDED OVERFLOW HANDLING ---
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
                      maxLines: 1, // Fix: Prevent name from breaking layout
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (reviews > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$rating ",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          // Fix: Wrap reviews in Flexible for small screens
                          Flexible(
                            child: Text(
                              "($reviews reviews)",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (userId.isNotEmpty)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PublicProfilePage(userId: userId, userName: name),
                      ),
                    );
                },
                child: const Text("View Profile"),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- BUTTON LOGIC ---
  ButtonStyle _actionButtonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildDisabledButton(String text) {
    return ElevatedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        disabledBackgroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Widget _buildOwnerActionButton(
    String status,
    Map<String, dynamic> data,
    BuildContext context,
  ) {
    if (status == 'open') {
      return ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                JobApplicantsPage(jobId: widget.jobId, jobTitle: data['title']),
          ),
        ),
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
      if (_hasRated) return _buildDisabledButton("You rated this user");
      return ElevatedButton.icon(
        onPressed: () => _showRatingDialog(data),
        icon: const Icon(Icons.star_rounded),
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
      if (currentUid != hiredId)
        return _buildDisabledButton("Position Filled (Closed)");
      if (_hasRated) return _buildDisabledButton("You rated this user");
      return ElevatedButton.icon(
        onPressed: () => _showRatingDialog(data),
        icon: const Icon(Icons.star_rounded),
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
}
