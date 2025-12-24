import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// IMPORT YOUR EXISTING DETAILS PAGE
import '../features/home/presentation/pages/job_details_page.dart'; 

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job; // Accepts Map to match Dashboard & Search logic
  final bool showStatus; // Optional, defaults to false

  const JobCard({
    super.key, 
    required this.job, 
    this.showStatus = false,
    // We don't need to pass onTap manually anymore
    VoidCallback? onTap, 
  });

  @override
  Widget build(BuildContext context) {
    // 1. Safe Data Extraction
    final String title = job['title'] ?? "Untitled";
    final String description = job['description'] ?? "";
    final String category = job['tag'] ?? job['category'] ?? "General";
    // Handle budget display
    String price = job['price'] ?? "";
    if (price.isEmpty) {
       price = "₱${job['budgetMin'] ?? 0} - ₱${job['budgetMax'] ?? 0}";
    }
    
    final bool isUrgent = job['isUrgent'] == true;
    final String posterId = job['posterId'] ?? job['postedBy'] ?? "";
    final String jobId = job['jobId'] ?? job['id'] ?? "";

    return GestureDetector(
      onTap: () {
        // NAVIGATE TO YOUR EXISTING DETAILS PAGE
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(
              job: job, 
              jobId: jobId, 
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isUrgent)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB), 
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "URGENT",
                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // --- DESCRIPTION ---
            Text(
              description,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // --- CATEGORY CHIP ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                category,
                style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),

            // --- FOOTER ---
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue)),
                const Spacer(),
                
                // Employer Info Stream
                StreamBuilder<DocumentSnapshot>(
                  stream: posterId.isNotEmpty 
                      ? FirebaseFirestore.instance.collection('users').doc(posterId).snapshots()
                      : null,
                  builder: (context, snapshot) {
                    String name = "Employer";
                    String? photoUrl;
                    
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      name = data['fullName'] ?? data['username'] ?? "Employer";
                      photoUrl = data['profileImageUrl'];
                    }

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue[100],
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null 
                            ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue))
                            : null,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const Row(children: [
                               Icon(Icons.star, size: 10, color: Colors.amber),
                               Text(" 0.0", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ]),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}