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

          // --- SKILLS ---
          List<dynamic> skills = [];
          if (data['skills'] is List) {
            skills = data['skills'];
          }

          // --- RATING DATA (FIXED) ---
          // Safely convert any number type (int or double) to double
          double rating = (data['rating'] is num)
              ? (data['rating'] as num).toDouble()
              : 0.0;

          int reviewCount = (data['reviewCount'] is num)
              ? (data['reviewCount'] as num).toInt()
              : 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildAvatar(name, photoUrl),

                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(location, style: TextStyle(color: Colors.grey[600])),

                // --- ADDED: VISUAL STAR RATING ROW ---
                const SizedBox(height: 8),
                if (reviewCount > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "($reviewCount reviews)",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  )
                else
                  Text(
                    "No ratings yet",
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),

                // -------------------------------------
                const SizedBox(height: 24),
                _buildTrustBadges(),

                const SizedBox(height: 32),
                _buildStatsRow(data, rating), // Pass the fixed rating

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                _buildAboutSection(about),

                const SizedBox(height: 24),

                if (skills.isNotEmpty) ...[
                  const Align(
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

                // --- INSERTED REVIEWS LIST HERE ---
                const Divider(),
                const SizedBox(height: 24),
                _buildReviewsList(),
                const SizedBox(height: 40),

                // ----------------------------------
                if (_decisionStatus != null)
                  _buildDecisionBanner()
                else if (widget.jobId != null)
                  _buildActionButtons(),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
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

  // Updated to accept the parsed rating double
  Widget _buildStatsRow(Map<String, dynamic> data, double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(data['appliedCount']?.toString() ?? "0", "Applied"),
        _buildStatItem(
          data['hiredCompleted']?.toString() ?? "0",
          "Hired",
          isClickable: true,
        ),
        // Format rating to 1 decimal place (e.g. "4.5")
        _buildStatItem(rating.toStringAsFixed(1), "Rating"),
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

  // --- NEW: REVIEWS LIST WIDGET ---
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
              .limit(5) // Show last 5 reviews
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text("Could not load reviews.");
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rate_review_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 12),
                    Text(
                      "No reviews yet.",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final double rating = (data['rating'] ?? 0.0).toDouble();
                final String review = data['review'] ?? "";
                final String raterName = data['raterName'] ?? "Anonymous";
                final String raterPhoto = data['raterPhoto'] ?? "";
                final Timestamp? time = data['timestamp'];

                // Format Date
                String dateStr = "";
                if (time != null) {
                  final dt = time.toDate();
                  dateStr = "${dt.month}/${dt.day}/${dt.year}";
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade200),
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
                      // Header: Avatar, Name, Date
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundImage: raterPhoto.isNotEmpty
                                ? NetworkImage(raterPhoto)
                                : null,
                            child: raterPhoto.isEmpty
                                ? Text(
                                    raterName.isNotEmpty
                                        ? raterName[0].toUpperCase()
                                        : "U",
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  raterName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Star Display
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[900],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Review Text
                      if (review.isNotEmpty)
                        Text(
                          review,
                          style: TextStyle(
                            color: Colors.grey[800],
                            height: 1.4,
                          ),
                        )
                      else
                        Text(
                          "No written review.",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
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
              onPressed: _isLoading ? null : _handleReject,
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
