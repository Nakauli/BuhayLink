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
    // --- DATA PARSING ---
    final String title = job['title'] ?? "Untitled";
    final String description = job['description'] ?? "";
    final String category = (job['tag'] ?? "General").toString().toUpperCase();
    final String price = job['price'] ?? "₱0";
    final String location = job['location'] ?? "Remote";
    final int applicantCount = job['applicants'] ?? 0;

    // --- STATUS LOGIC (Matches JobDetailsPage) ---
    final String rawStatus = (job['status'] ?? "open").toString().toLowerCase();
    final bool isCompleted = rawStatus == 'completed';
    // "Hired" status is displayed as "Ongoing" to the user
    final bool isOngoing = rawStatus == 'hired';
    final bool isUrgent = job['isUrgent'] == true;

    // User Data
    final String posterId = job['posterId'] ?? job['postedBy'] ?? "";

    // Visual Styles (Dim card if not open)
    final bool isOpen = rawStatus == 'open';
    final Color cardBg = isOpen ? Colors.white : const Color(0xFFFAFAFA);
    final Color textColor = isOpen ? Colors.black87 : Colors.grey.shade600;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          // Modern soft shadow
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isOpen ? 0.06 : 0.02),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. TOP ROW: Title & Badges ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TITLE
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800, // Extra bold
                      fontSize: 18,
                      color: textColor,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // BADGE HIERARCHY
                if (isCompleted)
                  _buildBadge("COMPLETED", Colors.green)
                else if (isOngoing)
                  _buildBadge("ONGOING", Colors.orange.shade800)
                else if (isUrgent)
                  _buildBadge("URGENT", Colors.red),
              ],
            ),

            const SizedBox(height: 10),

            // --- 2. CATEGORY PILL ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isOpen ? Colors.blue.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isOpen ? Colors.blue.shade700 : Colors.grey.shade600,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // --- 3. DESCRIPTION ---
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // --- 4. PRICE & LOCATION GRID ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // A. PRICE (Wrapped in FittedBox to prevent overflow)
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      price,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        // Grey out price if job is closed
                        color: isOpen ? const Color(0xFF2E7EFF) : Colors.grey,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Vertical Divider
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                const SizedBox(width: 16),

                // B. LOCATION & APPLICANTS
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location Row
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Applicants Row
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$applicantCount Applied",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 14),

            // --- 5. FOOTER: POSTER PROFILE ---
            StreamBuilder<DocumentSnapshot>(
              stream: posterId.isNotEmpty
                  ? FirebaseFirestore.instance
                        .collection('users')
                        .doc(posterId)
                        .snapshots()
                  : null,
              builder: (context, snapshot) {
                String name = job['posterName'] ?? "Employer";
                String? profileUrl;
                String rating = "New";

                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData =
                      snapshot.data!.data() as Map<String, dynamic>;
                  name = userData['name'] ?? userData['fullName'] ?? name;
                  profileUrl = userData['photoUrl'] ?? userData['profileImage'];
                  if (userData['rating'] != null) {
                    rating = (userData['rating'] as num)
                        .toDouble()
                        .toStringAsFixed(1);
                  }
                }

                // Fallback for current user
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                // if (posterId == currentUid) name = "Me"; // Optional

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF2E7EFF).withOpacity(0.1),
                      backgroundImage:
                          (profileUrl != null && profileUrl.isNotEmpty)
                          ? NetworkImage(profileUrl)
                          : null,
                      child: (profileUrl == null || profileUrl.isEmpty)
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : "E",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7EFF),
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Colors.amber,
                              ),
                              Text(
                                " $rating",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Optional: View Profile Text
                    if (showStatus) // Reusing showStatus param to maybe show "View"
                      Text(
                        "View",
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)), // Subtle border
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
