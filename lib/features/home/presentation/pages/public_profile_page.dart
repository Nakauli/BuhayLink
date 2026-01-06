import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// SOLID: Import Repositories
import '../../../jobs/data/repositories/job_repository.dart';
import '../../../jobs/data/repositories/chat_repository.dart';
import 'hired_jobs_page.dart';

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
        widget.jobId!,
        widget.userId,
        widget.jobTitle ?? '',
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- REJECT LOGIC ---
  Future<void> _handleReject() async {
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
      await _jobRepository.rejectApplicant(widget.jobId!, widget.userId);

      setState(() => _decisionStatus = 'rejected');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Applicant Rejected.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey[50], // Match the grey background of ProfilePage
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(
          color: Colors.white,
        ), // White arrow for gradient
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _jobRepository.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

          // --- DATA FETCHING ---
          final String name =
              data['name'] ??
              data['fullName'] ??
              data['firstName'] ??
              widget.userName;

          final String photoUrl =
              data['photoUrl'] ??
              data['profileImage'] ??
              data['imageUrl'] ??
              "";

          final String location =
              data['location'] ?? data['address'] ?? "Philippines";

          final String about =
              data['about'] ??
              data['bio'] ??
              data['description'] ??
              "No about info provided.";

          // Verification Status
          final bool isVerified = data['isVerified'] == true;

          List<dynamic> skills = [];
          if (data['skills'] is List) {
            skills = data['skills'];
          }

          double rating = (data['rating'] is num)
              ? (data['rating'] as num).toDouble()
              : 0.0;

          // Resume Data Logic
          final bool hasResume = data['hasResume'] == true;
          final Map<String, dynamic>? resumeData = hasResume
              ? (data['resume'] as Map<String, dynamic>?)
              : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(
              bottom: 100,
            ), // Extra space for content
            child: Column(
              children: [
                // 1. EPIC HEADER SECTION (Matches ProfilePage)
                SizedBox(
                  height: 300,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Gradient Background
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 250,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(40),
                              bottomRight: Radius.circular(40),
                            ),
                          ),
                        ),
                      ),
                      // Decorative Shapes
                      Positioned(
                        top: -60,
                        left: -40,
                        child: Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 80,
                        right: -30,
                        child: Container(
                          height: 150,
                          width: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      // Floating Avatar
                      Positioned(
                        top: 170,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "U",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10), // Shadow spacing
                // 2. NAME & LOCATION
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  location,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 12),

                // DYNAMIC VERIFIED BADGE
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Verified User",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // 3. STATS ROW
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        "Rating",
                        rating.toStringAsFixed(1),
                        Icons.star_rounded,
                        Colors.amber,
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        "Applied",
                        data['appliedCount']?.toString() ?? "0",
                        Icons.work_rounded,
                        Colors.blue,
                      ),
                      _buildVerticalDivider(),
                      _buildStatItem(
                        "Hired",
                        data['hiredCompleted']?.toString() ?? "0",
                        Icons.handshake_rounded,
                        Colors.green,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 4. ACTION BUTTONS (Hire/Reject/Contact)
                if (_decisionStatus != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildDecisionBanner(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Only show Hire/Reject if viewing as an applicant (jobId exists)
                        if (widget.jobId != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isLoading ? null : _handleReject,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    "Reject",
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleHire,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                      : const Text(
                                          "Hire Now",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Contact Button (Always visible)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _chatRepository.startChat(
                                context,
                                widget.userId,
                                name,
                                photoUrl,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7EFF),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Send Message",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                // 5. INFO SECTION
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Resume Section (Only if Resume exists)
                      if (hasResume && resumeData != null) ...[
                        _buildResumeCard(resumeData),
                        const SizedBox(height: 16),
                      ],

                      _buildInfoCard(
                        "About",
                        about,
                        Icons.person_outline,
                        Colors.orange,
                      ),

                      if (skills.isNotEmpty) _buildSkillsCard(skills),

                      const SizedBox(height: 16),
                      _buildReviewsList(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildResumeCard(Map<String, dynamic> resume) {
    List<dynamic> experience = resume['experience'] ?? [];
    List<dynamic> education = resume['education'] ?? [];
    String summary = resume['summary'] ?? "No summary provided.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF2E7EFF).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description, color: Color(0xFF2E7EFF)),
              SizedBox(width: 8),
              Text(
                "Resume Highlights",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),

          Text(summary, style: TextStyle(color: Colors.grey[700], height: 1.4)),
          const SizedBox(height: 16),

          if (experience.isNotEmpty) ...[
            const Text(
              "Experience",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...experience
                .take(2)
                .map(
                  (exp) => Padding(
                    // Show only top 2
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 6, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: "${exp['title']} ",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              children: [
                                TextSpan(
                                  text: "at ${exp['company']}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],

          if (education.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "Education",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            ...education
                .take(1)
                .map(
                  (edu) => Row(
                    // Show only top 1
                    children: [
                      const Icon(Icons.school, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${edu['degree']} - ${edu['school']}",
                          style: TextStyle(color: Colors.grey[700]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: TextStyle(color: Colors.grey[700], height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSkillsCard(List<dynamic> skills) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Skills",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7EFF).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2E7EFF).withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      s.toString(),
                      style: const TextStyle(
                        color: Color(0xFF2E7EFF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Recent Reviews",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('ratings')
              .orderBy('timestamp', descending: true)
              .limit(3)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    "No reviews yet.",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              );
            }

            return Column(
              children: snapshot.data!.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['raterName'] ?? "Anonymous",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (data['rating'] ?? 0.0).toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['review'] ?? "",
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 30, width: 1, color: Colors.grey[300]);
  }

  Widget _buildDecisionBanner() {
    bool isHired = _decisionStatus == 'hired';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
}
