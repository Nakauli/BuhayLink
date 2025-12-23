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
    final String posterId = job['posterId'] ?? "";
    final String status = (job['status'] ?? "Open").toString().toUpperCase();
    final bool isClosed = status == 'CLOSED' || status == 'HIRED';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row (Title and Urgent Tag)
            _buildHeader(status, isClosed),
            const SizedBox(height: 8),
            Text(job['description'] ?? "", style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            
            // Category Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
              child: Text(job['tag'] ?? "General", style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Info Items (Price, Location, etc.)
            _buildInfoGrid(),
            const SizedBox(height: 16),

            // --- THE FIX: DYNAMIC USER PROFILE SECTION ---
            StreamBuilder<DocumentSnapshot>(
              stream: posterId.isNotEmpty 
                  ? FirebaseFirestore.instance.collection('users').doc(posterId).snapshots()
                  : null,
              builder: (context, snapshot) {
                String name = "Employer";
                String? profileUrl;
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  name = userData['fullName'] ?? userData['firstName'] ?? userData['username'] ?? "Employer";
                  profileUrl = userData['profileImageUrl']; // Ensure this field exists in your DB
                }

                // Fallback for current user's own posts
                final currentUid = FirebaseAuth.instance.currentUser?.uid;
                if (posterId == currentUid && name == "Employer") {
                  name = "Me";
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue[100],
                      backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                      child: profileUrl == null 
                          ? Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)) 
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 12),
                            const SizedBox(width: 4),
                            Text(job['rating'] ?? "New", style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Optional Status Badge
                    if (showStatus)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isClosed ? Colors.grey[100] : Colors.green[50],
                          borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text(status, style: TextStyle(color: isClosed ? Colors.grey : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
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

  // --- Helper UI Methods ---
  Widget _buildHeader(String status, bool isClosed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(job['title'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
        if (job['isUrgent'] == true)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
            child: const Text("URGENT", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    return Row(
      children: [
        Expanded(child: _buildInfoItem(Icons.payments_outlined, job['price'] ?? "", Colors.blue)),
        Expanded(child: _buildInfoItem(Icons.location_on_outlined, job['location'] ?? "", Colors.grey)),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, Color iconColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}