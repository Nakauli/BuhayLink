import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final bool showStatus;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. DATA PREPARATION
    final String posterId = job['posterId'] ?? job['postedBy'] ?? "";
    final String rawStatus = (job['status'] ?? "open").toString().toLowerCase();

    // Status Checks
    final bool isOpen = rawStatus == 'open';
    final bool isCompleted = rawStatus == 'completed';
    // "Hired" means the job is now "Ongoing"
    final bool isOngoing = rawStatus == 'hired';

    // Applicant Count
    final int applicantCount = job['applicants'] ?? 0;

    // Visual Styles (Grey out if not open)
    final Color backgroundColor = isOpen ? Colors.white : Colors.grey.shade50;
    final Color titleColor = isOpen ? Colors.black : Colors.grey.shade600;
    final Color priceColor = isOpen ? Colors.blue : Colors.grey.shade500;
    final Color borderColor = isOpen
        ? Colors.grey.shade100
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isOpen ? 0.05 : 0.02),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER (Title & Status Badge) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? "",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: titleColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // --- NEW BADGE HIERARCHY ---
                // 1. If Completed -> Green "COMPLETED"
                if (isCompleted)
                  _buildBadge("COMPLETED", Colors.green)
                // 2. If Hired -> Orange "ONGOING" (Replaces Urgent)
                else if (isOngoing)
                  _buildBadge("ONGOING", Colors.orange.shade800)
                // 3. If Open & Urgent -> Red "URGENT"
                else if (job['isUrgent'] == true)
                  _buildBadge("URGENT", Colors.red),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              job['description'] ?? "",
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Category Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isOpen ? Colors.blue[50] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (job['tag'] ?? "General").toString().toUpperCase(),
                style: TextStyle(
                  color: isOpen ? Colors.blue[700] : Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Info Grid (Price | Location | Applicants)
            _buildInfoGrid(priceColor, applicantCount),

            const SizedBox(height: 16),

            // --- USER PROFILE SECTION ---
            StreamBuilder<DocumentSnapshot>(
              stream: posterId.isNotEmpty
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(posterId)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                // Default data
                String name = job['posterName'] ?? "Employer";
                String? profileUrl;
                String? rating;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  name =
                      userData['name'] ??
                      userData['fullName'] ??
                      userData['firstName'] ??
                      name;
                  profileUrl =
                      userData['photoUrl'] ??
                      userData['profileImage'] ??
                      userData['imageUrl'];

                  if (userData['rating'] != null) {
                    rating = (userData['rating'] as num)
                        .toDouble()
                        .toStringAsFixed(1);
                  }
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue[100],
                      backgroundImage:
                          (profileUrl != null && profileUrl.isNotEmpty)
                          ? NetworkImage(profileUrl)
                          : null,
                      child: (profileUrl == null || profileUrl.isEmpty)
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "E",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                rating ?? job['rating']?.toString() ?? "New",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper: Badge Builder ---
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // --- Helper: Info Grid ---
  Widget _buildInfoGrid(Color priceColor, int applicants) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Price
        Flexible(
          flex: 2,
          child: _buildInfoItem(
            Icons.payments_outlined,
            job['price'] ?? "",
            priceColor,
          ),
        ),

        // 2. Location
        Flexible(
          flex: 2,
          child: _buildInfoItem(
            Icons.location_on_outlined,
            job['location'] ?? "Remote",
            Colors.grey,
          ),
        ),

        // 3. Applicants
        Flexible(
          flex: 2,
          child: _buildInfoItem(
            Icons.people_alt_outlined,
            "$applicants Applied",
            Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
