import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PublicProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? jobId; // Optional: Only exists if reviewing a specific application
  final String? jobTitle; // <--- NEW: The title of the job they applied for

  const PublicProfilePage({
    super.key,
    required this.userId,
    required this.userName,
    this.jobId,
    this.jobTitle, // <--- Add to constructor
  });

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _isLoading = false;

  // --- ACTION: HIRE APPLICANT ---
  Future<void> _hireApplicant() async {
    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;

    try {
      // 1. Update Applicant Stats
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'hiredCompleted': FieldValue.increment(1),
      });

      // 2. Notify Applicant
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': widget.userId,
        'title': 'Congratulations! You are Hired',
        'message': "You have been hired by ${currentUser?.email?.split('@')[0] ?? 'Employer'} for the position: ${widget.jobTitle ?? 'Job'}.",
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'hired',
        'jobId': widget.jobId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Applicant Hired Successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ACTION: REJECT APPLICANT ---
  Future<void> _rejectApplicant() async {
    setState(() => _isLoading = true);

    try {
      // 1. Notify Applicant
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': widget.userId,
        'title': 'Application Update',
        'message': "Your application for ${widget.jobTitle ?? 'the position'} was not selected.",
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'rejected',
        'jobId': widget.jobId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Applicant Rejected."), backgroundColor: Colors.black87),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Default Data
          String displayName = widget.userName;
          String location = "Philippines";
          String bio = "Skilled professional looking for opportunities.";
          String memberSince = "2024";
          
          String stat1 = "0"; // Applied
          String stat2 = "0"; // Hired
          String stat3 = "0.0"; // Rating

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            displayName = data['fullName'] ?? data['firstName'] ?? widget.userName;
            location = data['location'] ?? location;
            bio = data['bio'] ?? bio;

            stat1 = data['appliedCount']?.toString() ?? "0";
            stat2 = data['hiredCompleted']?.toString() ?? "0";
            stat3 = data['rating']?.toString() ?? "0.0";
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 1. Avatar
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
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                          style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, color: Colors.blue, size: 28),
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

                // 3. Trust Badges
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
                
                // 4. Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(stat1, "Applied"),
                    _buildContainerDivider(),
                    _buildStatItem(stat2, "Hired"),
                    _buildContainerDivider(),
                    _buildStatItem(stat3, "Rating"),
                  ],
                ),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                // 5. About
                Align(alignment: Alignment.centerLeft, child: Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]))),
                const SizedBox(height: 12),
                Text(bio, style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 15)),
                
                const SizedBox(height: 24),

                // 6. Member Since
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
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

                // --- 7. JOB CONTEXT SECTION (NEW) ---
                if (widget.jobTitle != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Applying for:", style: TextStyle(color: Colors.blue, fontSize: 12)),
                              Text(widget.jobTitle!, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // --- 8. ACTION BUTTONS ---
                
                // A. SHOW HIRE/REJECT (Only if reviewing an application)
                if (widget.jobId != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _rejectApplicant,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _hireApplicant,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text("Hire", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16), // Spacing between Hire/Reject and Contact
                ],

                // B. CONTACT BUTTON (ALWAYS VISIBLE)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Logic to chat/message
                    },
                    icon: const Icon(Icons.message_outlined),
                    label: const Text("Contact"),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20), // Bottom padding
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