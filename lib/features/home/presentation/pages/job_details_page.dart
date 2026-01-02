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

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final applied = await _jobRepository.hasApplied(widget.jobId);
    final saved = await _jobRepository.isJobSaved(widget.jobId);
    if (mounted) {
      setState(() {
        _hasApplied = applied;
        _isSaved = saved;
      });
    }
  }

  Future<void> _toggleSaveJob() async {
    setState(() => _isSaved = !_isSaved);
    try {
      await _jobRepository.toggleSaveJob(widget.jobId, widget.job, !_isSaved);
    } catch (e) {
      if (mounted) setState(() => _isSaved = !_isSaved);
    }
  }

  Future<void> _applyForJob() async {
    setState(() => _isApplying = true);
    try {
      await _jobRepository.applyForJob(widget.jobId, widget.job);
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

  // --- DELETE FUNCTION ---
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        // <--- RENAME THIS
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
              Navigator.pop(dialogContext); // Close the dialog

              await _jobRepository.deleteJob(widget.jobId);

              if (mounted) {
                Navigator.pop(context); // Close the Page using main context
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
    final descCtrl = TextEditingController(text: widget.job['description']);
    final minBudgetCtrl = TextEditingController(
      text: (widget.job['budgetMin'] ?? 0).toString(),
    );
    final maxBudgetCtrl = TextEditingController(
      text: (widget.job['budgetMax'] ?? 0).toString(),
    );

    showDialog(
      context: context, // Uses the Page Context
      builder: (dialogContext) => AlertDialog(
        // <--- RENAME THIS to dialogContext
        title: const Text("Edit Job Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Job Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minBudgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Min Budget",
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
            onPressed: () => Navigator.pop(
              dialogContext,
            ), // Close Dialog using dialogContext
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              // 1. Close the Dialog immediately
              Navigator.pop(dialogContext);

              // 2. Perform the update
              await _jobRepository.updateJob(widget.jobId, {
                'title': titleCtrl.text,
                'description': descCtrl.text,
                'budgetMin': double.tryParse(minBudgetCtrl.text) ?? 0,
                'budgetMax': double.tryParse(maxBudgetCtrl.text) ?? 0,
              });

              // 3. Use the PAGE context to show the message and go back
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  // Uses Page context (Safe)
                  const SnackBar(content: Text("Job Updated!")),
                );
                Navigator.pop(
                  context,
                ); // Goes back to the list using Page context
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
    final currentUser = FirebaseAuth.instance.currentUser;
    final String currentUid = currentUser?.uid ?? "";
    final String posterId = (widget.job['posterId'] ?? "").toString();
    final bool isOwner = currentUid.isNotEmpty && currentUid == posterId;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Job Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOwner) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: _showEditDialog,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _confirmDelete,
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? const Color(0xFF2E7EFF) : Colors.black,
              ),
              onPressed: _toggleSaveJob,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: HEADER (Title & Price) ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade100,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hired/Rejected Banners
                        if (widget.isHired && !isOwner)
                          _buildBanner(
                            Colors.green,
                            Icons.check_circle,
                            "Congratulations!",
                            "You have been hired!",
                          ),
                        if (widget.isRejected && !isOwner)
                          _buildBanner(
                            Colors.red,
                            Icons.cancel,
                            "Application Update",
                            "Unfortunately, you were not selected.",
                          ),

                        // TAG
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.job['tag'].toString().toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // TITLE
                        Text(
                          widget.job['title'] ?? "Job Title",
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: Colors.black,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // PRICE (HIERARCHY: BIGGER & BLUE)
                        Text(
                          widget.job['price'] ??
                              "₱${widget.job['budgetMin']} - ₱${widget.job['budgetMax']}",
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7EFF),
                          ), // Blue
                        ),
                      ],
                    ),
                  ),

                  // --- SECTION 2: SPECS (Grid) ---
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Owner Profile (If not me)
                        if (!isOwner) ...[
                          _buildEmployerCard(),
                          const SizedBox(height: 24),
                        ],

                        // STATS ROW (Clean Layout)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem(
                                Icons.location_on,
                                "Location",
                                widget.job['location'] ?? "Remote",
                              ),
                              _buildVerticalDivider(),
                              _buildStatItem(
                                Icons.calendar_today,
                                "Duration",
                                widget.job['duration'] ?? "N/A",
                              ),
                              _buildVerticalDivider(),
                              _buildStatItem(
                                Icons.people,
                                "Applicants",
                                "${widget.job['applicants'] ?? 0}",
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // DESCRIPTION HEADER
                        const Text(
                          "Job Description",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // DESCRIPTION TEXT (More Readable)
                        Text(
                          widget.job['description'] ??
                              "No description provided.",
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.6,
                            fontSize: 16,
                          ), // Better readability
                        ),

                        const SizedBox(height: 40), // Bottom padding
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- BOTTOM BAR ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      "Back",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2, // Action button takes more space
                  child: isOwner
                      ? ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JobApplicantsPage(
                                  jobId: widget.jobId,
                                  jobTitle: widget.job['title'],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.people_alt_outlined),
                          label: const Text("View Applicants"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7EFF),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed:
                              (_isApplying || _hasApplied || widget.isHired)
                              ? null
                              : _applyForJob,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _hasApplied
                                ? Colors.green
                                : const Color(0xFF2E7EFF),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isApplying
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _hasApplied
                                      ? "Applied"
                                      : (widget.isHired
                                            ? "Position Filled"
                                            : "Apply Now"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[400], size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey.shade300);
  }

  Widget _buildBanner(
    Color color,
    IconData icon,
    String title,
    String message,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployerCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.job['posterId'] != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(widget.job['posterId'])
                .snapshots()
          : null,
      builder: (context, snapshot) {
        String name = widget.job['user'] ?? "Employer";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          name = data?['fullName'] ?? data?['firstName'] ?? name;
        }
        String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "E";

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade300, Colors.purple.shade300],
                  ),
                ),
                child: Center(
                  child: Text(
                    firstLetter,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Posted by",
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  if (widget.job['posterId'] != null)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfilePage(
                          userId: widget.job['posterId'],
                          userName: name,
                        ),
                      ),
                    );
                },
                child: const Text(
                  "View Profile",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
