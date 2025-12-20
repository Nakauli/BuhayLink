import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'hired_jobs_page.dart'; // Ensure this file exists and is imported

class PublicProfilePage extends StatefulWidget {
  final String userId;
  final String userName;
  final String? jobId; 
  final String? jobTitle; 

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
  bool _isLoading = false;
  String? _decisionStatus; 

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      _checkExistingDecision();
    }
  }

  Future<void> _checkExistingDecision() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('notifications')
          .where('jobId', isEqualTo: widget.jobId)
          .where('recipientId', isEqualTo: widget.userId)
          .where('type', whereIn: ['hired', 'rejected'])
          .get();

      if (query.docs.isNotEmpty && mounted) {
        final data = query.docs.first.data();
        setState(() {
          _decisionStatus = data['type']; 
        });
      }
    } catch (e) {
      debugPrint("Error checking decision: $e");
    }
  }

  Future<void> _hireApplicant() async {
    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      String employerName = "Employer";
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
            employerName = data['fullName'];
          } else if (data['firstName'] != null) {
            employerName = "${data['firstName']} ${data['lastName'] ?? ''}".trim();
          } else if (data['username'] != null) {
            employerName = data['username'];
          } else {
             employerName = currentUser.email?.split('@')[0] ?? "Employer";
          }
        }
      } catch (e) {
        employerName = currentUser.email?.split('@')[0] ?? "Employer";
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'hiredCompleted': FieldValue.increment(1),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': widget.userId,
        'title': 'Congratulations! You are Hired',
        'message': "You have been hired by $employerName for the position: ${widget.jobTitle ?? 'Job'}.",
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'hired', 
        'jobId': widget.jobId,
      });

      if (mounted) {
        setState(() => _decisionStatus = 'hired');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Applicant Hired!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectApplicant() async {
    setState(() => _isLoading = true);
    try {
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
        setState(() => _decisionStatus = 'rejected');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Applicant Rejected."), backgroundColor: Colors.black87));
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
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          String displayName = widget.userName;
          String location = "Philippines";
          String bio = "Skilled professional looking for opportunities.";
          String memberSince = "2024";
          String stat1 = "0"; String stat2 = "0"; String stat3 = "0.0"; 

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
                // Avatar Section
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
                      child: Center(child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "U", style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold))),
                    ),
                    Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.verified, color: Colors.blue, size: 28))
                  ],
                ),
                const SizedBox(height: 16),
                Text(displayName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.location_on, color: Colors.grey, size: 16), const SizedBox(width: 4), Text(location, style: TextStyle(color: Colors.grey[600]))]),
                const SizedBox(height: 24),

                // Trust Badges
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade100)),
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
                
                // --- CLICKABLE STATS ROW ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Applied (Not Clickable)
                    _buildStatItem(stat1, "Applied"),
                    
                    _buildContainerDivider(),
                    
                    // --- HIRED (CLICKABLE) ---
                    Expanded(
                      child: GestureDetector(
                        // Important: Ensures the tap works on the entire expanded area, including white space
                        behavior: HitTestBehavior.translucent, 
                        onTap: () {
                          debugPrint("Hired Clicked");
                          Navigator.push(context, MaterialPageRoute(builder: (context) => HiredJobsPage(userId: widget.userId)));
                        },
                        child: Column(
                          children: [
                            Text(stat2, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text("Hired", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    // -------------------------

                    _buildContainerDivider(),
                    
                    // Rating (Not Clickable)
                    _buildStatItem(stat3, "Rating"),
                  ],
                ),
                // ---------------------------
                
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),

                Align(alignment: Alignment.centerLeft, child: Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]))),
                const SizedBox(height: 12),
                Text(bio, style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 15)),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Member Since", style: TextStyle(color: Colors.grey[500], fontSize: 12)), Text(memberSince, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                if (widget.jobTitle != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                    child: Row(
                      children: [
                        const Icon(Icons.work_outline, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Applying for:", style: TextStyle(color: Colors.blue, fontSize: 12)), Text(widget.jobTitle!, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15))])),
                      ],
                    ),
                  ),

                if (_decisionStatus != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: _decisionStatus == 'hired' ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: _decisionStatus == 'hired' ? Colors.green : Colors.red, width: 1.5)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_decisionStatus == 'hired' ? Icons.check_circle : Icons.cancel, color: _decisionStatus == 'hired' ? Colors.green : Colors.red), const SizedBox(width: 8), Text(_decisionStatus == 'hired' ? "Applicant Hired" : "Applicant Rejected", style: TextStyle(color: _decisionStatus == 'hired' ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold, fontSize: 16))]),
                  )
                else if (widget.jobId != null) ...[
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: _isLoading ? null : _rejectApplicant, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("Reject", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 16),
                      Expanded(child: ElevatedButton(onPressed: _isLoading ? null : _hireApplicant, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Hire", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.message_outlined), label: const Text("Contact"), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
                const SizedBox(height: 20), 
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper for Non-clickable Stat Items ---
  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildContainerDivider() {
    return Container(width: 1, height: 40, color: Colors.grey[200]);
  }
}  