import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final bool
  showStatus; // If true, shows "OPEN/COMPLETED". If false, shows nothing (since Applied is now in middle).

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.showStatus =
        true, // Default to true so we always see the status button
  });

  @override
  Widget build(BuildContext context) {
    // 1. DATA PARSING
    final String title = job['title'] ?? "Untitled";
    final String description = job['description'] ?? "No description";
    final String category = (job['tag'] ?? "General").toString().toUpperCase();
    final String price = job['price'] ?? "₱0";
    final String location = job['location'] ?? "Remote";
    final int applicantCount = job['applicants'] ?? 0;

    // Status Logic
    final String rawStatus = (job['status'] ?? "open").toString().toLowerCase();
    final bool isCompleted = rawStatus == 'completed' || rawStatus == 'closed';
    final bool isOngoing = rawStatus == 'hired';
    final bool isUrgent = job['isUrgent'] == true;

    // User Data
    final String posterId = job['posterId'] ?? job['postedBy'] ?? "";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HEADER: Title & Badges ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isUrgent && !isCompleted && !isOngoing) ...[
                  const SizedBox(width: 8),
                  _buildBadge("URGENT", Colors.red),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // --- 2. CATEGORY & DESCRIPTION ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // --- 3. MIDDLE: Price | Location & Applied (Stacked) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Big Blue Price
                Text(
                  price,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF2E7EFF),
                  ),
                ),

                const SizedBox(width: 16),
                Container(
                  width: 1,
                  height: 35,
                  color: Colors.grey.shade200,
                ), // Vertical Divider
                const SizedBox(width: 16),

                // STACK: Location on top, Applied on bottom
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
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
                      const SizedBox(height: 6),
                      // Applied Count (Directly under location)
                      Row(
                        children: [
                          Icon(
                            Icons.people_alt,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$applicantCount Applied",
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
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),

            // --- 4. FOOTER: Profile & Status Button ---
            Row(
              children: [
                // Profile Section
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
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
                        profileUrl =
                            userData['photoUrl'] ?? userData['profileImage'];
                        if (userData['rating'] != null) {
                          rating = (userData['rating'] as num)
                              .toDouble()
                              .toStringAsFixed(1);
                        }
                      }

                      return Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(
                              0xFF2E7EFF,
                            ).withOpacity(0.1),
                            backgroundImage:
                                (profileUrl != null && profileUrl.isNotEmpty)
                                ? NetworkImage(profileUrl)
                                : null,
                            child: (profileUrl == null || profileUrl.isEmpty)
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "E",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2E7EFF),
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Status Button (Always visible if showStatus is true)
                if (showStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : (isOngoing
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.blue.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCompleted
                          ? "COMPLETED"
                          : (isOngoing ? "ONGOING" : "OPEN"),
                      style: TextStyle(
                        color: isCompleted
                            ? Colors.green
                            : (isOngoing
                                  ? Colors.orange.shade800
                                  : Colors.blue),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_filled, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
