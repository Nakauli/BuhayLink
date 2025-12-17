import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PublicProfilePage extends StatelessWidget {
  final String userId;
  final String userName;

  const PublicProfilePage({super.key, required this.userId, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Employer Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Default Data
          String displayName = userName;
          String bio = "We are looking for skilled professionals for home renovation projects.";
          String location = "Quezon City, Philippines";
          String memberSince = "2024";

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            displayName = data['fullName'] ?? data['firstName'] ?? userName;
            bio = data['bio'] ?? bio;
            location = data['location'] ?? location;
            // You can add a 'createdAt' field to your users later for real date
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 1. Avatar & Verification Badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]),
                        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))],
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : "E",
                          style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, color: Colors.blue, size: 28), // The "Blue Check"
                    )
                  ],
                ),
               
                const SizedBox(height: 16),
               
                // 2. Name & Location
                Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, color: Colors.grey, size: 16),
                    const SizedBox(width: 4),
                    Text(location, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
               
                const SizedBox(height: 24),

                // 3. Trust Badges Row (Static for now, builds trust)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text("Payment Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 16),
                      Container(width: 1, height: 20, color: Colors.green.shade200),
                      const SizedBox(width: 16),
                      const Icon(Icons.badge_outlined, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      const Text("Identity Verified", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
               
                // 4. Employer Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem("12", "Jobs Posted"),
                    _buildContainerDivider(),
                    _buildStatItem("8", "Hires Made"),
                    _buildContainerDivider(),
                    _buildStatItem("4.8", "Rating"),
                  ],
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // 5. About Section
                Align(alignment: Alignment.centerLeft, child: Text("About the Employer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]))),
                const SizedBox(height: 12),
                Text(
                  bio,
                  style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 15),
                ),
               
                const SizedBox(height: 24),

                // 6. Member Since
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Member Since", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                          Text(memberSince, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // 7. Action Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Logic to message employer could go here
                    },
                    icon: const Icon(Icons.message_outlined),
                    label: const Text("Contact Employer"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildContainerDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[200]);
  }
}