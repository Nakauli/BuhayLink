import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// SOLID: Import Repositories
import '../../../jobs/data/repositories/job_repository.dart';
import '../../../jobs/data/repositories/chat_repository.dart'; // Ensure you have this file created
import 'hired_jobs_page.dart'; // Ensure this file exists

class PublicProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? jobId; // Optional: Only passed if viewing an applicant
  final String? jobTitle; // Optional: Only passed if viewing an applicant

  const PublicProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    this.jobId,
    this.jobTitle,
  });

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final JobRepository _jobRepository = JobRepository();
  final ChatRepository _chatRepository = ChatRepository();

  bool _isLoading = false;
  String? _decisionStatus; // 'hired', 'rejected', or null

  @override
  void initState() {
    super.initState();
    // Only check for decision if we are viewing this person as an applicant
    if (widget.jobId != null) {
      _loadDecision();
    }
  }

  Future<void> _loadDecision() async {
    final status = await _jobRepository.checkExistingDecision(
      widget.jobId!,
      widget.userId,
    );
    if (mounted) setState(() => _decisionStatus = status);
  }

  // --- HIRE LOGIC ---
  Future<void> _handleHire() async {
    setState(() => _isLoading = true);
    try {
      await _jobRepository.hireApplicant(
        widget.jobId!, // 1. Job ID
        widget.userId, // 2. Applicant ID
        widget.jobTitle ?? '', // 3. Title
      );

      setState(() => _decisionStatus = 'hired');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Applicant Hired!"),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REJECT LOGIC (Fixed) ---
  Future<void> _handleReject() async {
    // 1. Confirmation Dialog
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Applicant?"),
        content: const Text(
          "Are you sure? They will be removed from the list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // 2. Call Repository (FIXED ARGUMENT ORDER)
      await _jobRepository.rejectApplicant(
        widget.jobId!, // Job ID First!
        widget.userId, // Applicant ID Second!
      );

      // 3. Update UI instantly
      setState(() => _decisionStatus = 'rejected');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Applicant Rejected.")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          widget.userName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _jobRepository.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // --- ROBUST DATA FETCHING ---

          // 1. Name: Check 'name', then 'fullName', then 'firstName'
          final String name =
              data['name'] ??
              data['fullName'] ??
              data['firstName'] ??
              widget.userName;

          // 2. Photo: Check 'photoUrl', then 'profileImage', then 'imageUrl'
          final String photoUrl =
              data['photoUrl'] ??
              data['profileImage'] ??
              data['imageUrl'] ??
              "";

          // 3. Location: Check 'location', then 'address'
          final String location =
              data['location'] ?? data['address'] ?? "Philippines";

          // 4. About: Check 'about', then 'bio', then 'description'
          final String about =
              data['about'] ??
              data['bio'] ??
              data['description'] ??
              "No about info provided.";

          // 5. Skills: Ensure it's a list
          List<dynamic> skills = [];
          if (data['skills'] is List) {
            skills = data['skills'];
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Pass the correctly fetched photoUrl here
                _buildAvatar(name, photoUrl),

                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  location, // Using the fetched location
                  style: TextStyle(color: Colors.grey[600]),
                ),

                const SizedBox(height: 24),
                _buildTrustBadges(),

                const SizedBox(height: 32),
                _buildStatsRow(data),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // Using the fetched about text
                _buildAboutSection(about),

                const SizedBox(height: 24),

                // --- NEW: SKILLS SECTION ---
                if (skills.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Skills",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills
                        .map(
                          (s) => Chip(
                            label: Text(s.toString()),
                            backgroundColor: Colors.blue[50],
                            labelStyle: TextStyle(color: Colors.blue[800]),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                ],

                // ... (Rest of your buttons logic) ...
                // --- DECISION BUTTONS ---
                // Shows Hire/Reject ONLY if we came from a Job context AND no decision exists
                if (_decisionStatus != null)
                  _buildDecisionBanner()
                else if (widget.jobId != null)
                  _buildActionButtons(),

                const SizedBox(height: 16),

                // --- CONTACT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // FIX: Pass 4 arguments (Context, ID, Name, Current User Name)
                      _chatRepository.startChat(
                        context,
                        widget.userId,
                        name,
                        photoUrl,
                      );
                    },
                    icon: const Icon(Icons.message_outlined),
                    label: const Text("Contact"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI HELPER WIDGETS ---

  Widget _buildAvatar(String name, String photoUrl) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.blue[100],
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const Icon(Icons.verified, color: Colors.blue, size: 28),
      ],
    );
  }

  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text(
            "Verified Professional",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(data['appliedCount']?.toString() ?? "0", "Applied"),
        _buildStatItem(
          data['hiredCompleted']?.toString() ?? "0",
          "Hired",
          isClickable: true,
        ),
        _buildStatItem(data['rating']?.toString() ?? "0.0", "Rating"),
      ],
    );
  }

  Widget _buildStatItem(
    String value,
    String label, {
    bool isClickable = false,
  }) {
    return InkWell(
      onTap: isClickable
          ? () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HiredJobsPage(userId: widget.userId),
              ),
            )
          : null,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String bio) {
    return Align(
      // Aligns text to start properly
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(bio, style: const TextStyle(height: 1.5, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildDecisionBanner() {
    bool isHired = _decisionStatus == 'hired';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isHired ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHired ? Colors.green : Colors.red),
      ),
      child: Center(
        child: Text(
          isHired ? "APPLICANT HIRED" : "APPLICANT REJECTED",
          style: TextStyle(
            color: isHired ? Colors.green[800] : Colors.red[800],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading ? null : _handleReject, // Uses new handler
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Reject"),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleHire,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("Hire"),
            ),
          ),
        ],
      ),
    );
  }
}
