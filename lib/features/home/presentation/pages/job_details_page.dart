import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_page.dart'; 

class JobDetailsPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final String jobId;
  final bool isHired;    
  final bool isRejected; 

  const JobDetailsPage({
    super.key, 
    required this.job, 
    required this.jobId,
    this.isHired = false,
    this.isRejected = false,
  });

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  bool _isApplying = false;
  bool _hasApplied = false;

  @override
  void initState() {
    super.initState();
    _checkIfApplied();
  }

  Future<void> _checkIfApplied() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('applications')
          .where('jobId', isEqualTo: widget.jobId)
          .get();

      if (query.docs.isNotEmpty && mounted) {
        setState(() => _hasApplied = true);
      }
    } catch (e) {
      debugPrint("Error checking status: $e");
    }
  }

  Future<void> _applyForJob() async {
    setState(() => _isApplying = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String employerId = widget.job['posterId'] ?? "";
    if (employerId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Employer info missing.")));
      setState(() => _isApplying = false);
      return;
    }

    try {
      String applicantName = user.email?.split('@')[0] ?? "Applicant";
      
      // 1. Try to get applicant name safely
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data['fullName'] != null && data['fullName'].toString().isNotEmpty) {
            applicantName = data['fullName'];
          } else if (data['firstName'] != null) {
            applicantName = "${data['firstName']} ${data['lastName'] ?? ''}".trim();
          }
        }
      } catch (e) {
        debugPrint("Could not fetch user profile, using email name.");
      }

      // 2. Add Notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': employerId,
        'title': 'New Applicant',
        'message': "$applicantName has applied for: ${widget.job['title']}",
        'applicantId': user.uid,
        'jobId': widget.jobId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'application',
      });

      // 3. Add to My Applications
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('applications').add({
        'jobId': widget.jobId,
        'title': widget.job['title'],
        'price': widget.job['price'] ?? "₱${widget.job['budgetMin']} - ₱${widget.job['budgetMax']}",
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Applied',
        'employerId': employerId,
      });

      // 4. FIX: Use SET with MERGE to update counter (Prevents "Not Found" error)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'appliedCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
        'applicants': FieldValue.increment(1),
      });

      setState(() => _hasApplied = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application Sent!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isApplying = false);
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
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Job Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.bookmark_border, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share_outlined, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- 1. HIRED / REJECTED BANNERS ---
                  if (widget.isHired)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 40),
                          const SizedBox(height: 8),
                          const Text("Congratulations!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 4),
                          Text("You have been hired for this project. Please contact the employer to discuss the details.", textAlign: TextAlign.center, style: TextStyle(color: Colors.green[800], fontSize: 13)),
                        ],
                      ),
                    ),

                  if (widget.isRejected)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel, color: Colors.red, size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Application Update", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text("Unfortunately, you were not selected for this position.", style: TextStyle(color: Colors.red[800], fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // --- 2. JOB HEADER ---
                  Text(
                    widget.job['title'] ?? "Job Title",
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.job['tag'].toString(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),

                  // --- 3. EMPLOYER CARD ---
                  StreamBuilder<DocumentSnapshot>(
                    stream: widget.job['posterId'] != null
                        ? FirebaseFirestore.instance.collection('users').doc(widget.job['posterId']).snapshots()
                        : null,
                    builder: (context, snapshot) {
                      String name = widget.job['user'] ?? "Employer";
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (name == "Employer" && widget.job['posterId'] == currentUser?.uid) {
                          name = currentUser?.email?.split('@')[0] ?? "Me";
                      }
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() as Map<String, dynamic>?;
                        final fetchedName = data?['fullName'] ?? data?['firstName'] ?? data?['username'];
                        if (fetchedName != null && fetchedName.isNotEmpty) {
                          name = fetchedName;
                        }
                      }
                      String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "E";

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.purple.shade300])),
                              child: Center(child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(widget.job['rating'] == "New" ? "New Member" : "${widget.job['rating']} (24 reviews)", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  ]),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                if (widget.job['posterId'] != null) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: widget.job['posterId'], userName: name)));
                                }
                              },
                              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide(color: Colors.grey.shade300)),
                              child: const Text("View Profile", style: TextStyle(color: Colors.black87, fontSize: 12)),
                            )
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  
                  // --- 4. DETAILS GRID ---
                  Row(children: [
                    Expanded(child: _buildInfoCard(Icons.attach_money, "Budget", widget.job['price'] ?? "₱${widget.job['budgetMin']} - ₱${widget.job['budgetMax']}")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoCard(Icons.people_outline, "Applicants", widget.job['applicants'].toString().replaceAll(" applicants", ""))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _buildInfoCard(Icons.location_on_outlined, "Location", widget.job['location'] ?? "Remote")),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoCard(Icons.access_time, "Deadline", widget.job['duration'] ?? "3 days")),
                  ]),
                  
                  const SizedBox(height: 30),
                  
                  // --- 5. DESCRIPTION ---
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    widget.job['description'] ?? 
                    "Looking for a skilled professional to help with complete ${widget.job['title'].toLowerCase()}. "
                    "Must have experience with modern techniques. The job includes initial assessment, execution, and cleanup.",
                    style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // --- 6. BOTTOM ACTION BUTTON ---
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text("Close", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                
                // CONDITIONAL BUTTON LOGIC
                Expanded(
                  child: widget.isHired
                    // CASE A: HIRED -> "Message Employer"
                    ? ElevatedButton.icon(
                        onPressed: () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chat feature coming soon!")));
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text("Message"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7EFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    : widget.isRejected
                        // CASE B: REJECTED -> DISABLED "Rejected" (RED COLOR)
                        ? ElevatedButton(
                            onPressed: null, // Disabled
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: Colors.red[50], // Light Red Background
                              disabledForegroundColor: Colors.red,     // Red Text
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text("Rejected", style: TextStyle(fontWeight: FontWeight.bold)), 
                          )
                        // CASE C: DEFAULT -> "Apply Now" or "Applied"
                        : ElevatedButton(
                            onPressed: (_isApplying || _hasApplied) ? null : _applyForJob,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: _hasApplied ? Colors.green : const Color(0xFF2E7EFF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              disabledBackgroundColor: _hasApplied ? Colors.green.withOpacity(0.8) : Colors.grey[300],
                              disabledForegroundColor: Colors.white,
                            ),
                            child: _isApplying
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(_hasApplied ? "Applied" : "Apply Now", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: Colors.grey[500]), const SizedBox(width: 6), Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12))]),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}