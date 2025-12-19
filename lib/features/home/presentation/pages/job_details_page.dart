import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_page.dart'; 

class JobDetailsPage extends StatefulWidget {
  final Map<String, dynamic> job;
  final String jobId;

  const JobDetailsPage({super.key, required this.job, required this.jobId});

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  bool _isApplying = false;
  bool _hasApplied = false; // New state variable

  @override
  void initState() {
    super.initState();
    _checkIfApplied(); // Check status when page loads
  }

  /// Checks Firestore to see if the current user already applied to this job
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

      if (query.docs.isNotEmpty) {
        setState(() {
          _hasApplied = true; // User has already applied
        });
      }
    } catch (e) {
      debugPrint("Error checking application status: $e");
    }
  }

  Future<void> _applyForJob() async {
    setState(() => _isApplying = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. SAVE TO USER'S "APPLIED" LIST
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('applications')
          .add({
        'jobId': widget.jobId,
        'title': widget.job['title'],
        'price': widget.job['price'] ?? "₱${widget.job['budgetMin']} - ₱${widget.job['budgetMax']}",
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Applied',
        'employerId': widget.job['posterId'],
      });

      // 2. NOTIFY THE EMPLOYER
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': widget.job['posterId'],
        'message': "${user.email?.split('@')[0] ?? 'Someone'} applied for: ${widget.job['title']}",
        'applicantId': user.uid,
        'jobId': widget.jobId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'application',
      });

      // 3. UPDATE STATS
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'appliedCount': FieldValue.increment(1),
      });
      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
        'applicants': FieldValue.increment(1),
      });

      setState(() {
        _hasApplied = true; // Update UI immediately to "Applied"
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Application Sent!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
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
        centerTitle: false,
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
                  Text(widget.job['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.job['tag'].toString(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),

                  // Profile Section
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
                        name = data?['fullName'] ?? data?['firstName'] ?? name;
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
                  const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    "Looking for a skilled professional to help with complete ${widget.job['title'].toLowerCase()}. "
                    "Must have experience with modern techniques. The job includes initial assessment, execution, and cleanup. "
                    "Please apply if you are available immediately.",
                    style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // BOTTOM BUTTONS
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
                Expanded(
                  child: ElevatedButton(
                    // IF APPLIED: onPressed is null (not clickable)
                    onPressed: (_isApplying || _hasApplied) ? null : _applyForJob,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      // Change color if applied (Greenish or Grey)
                      backgroundColor: _hasApplied ? Colors.green[400] : const Color(0xFF2E7EFF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      // Ensure disabled color looks good
                      disabledBackgroundColor: _hasApplied ? Colors.green[100] : Colors.grey[300], 
                    ),
                    child: _isApplying
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _hasApplied ? "Applied" : "Apply Now", // Change text
                            style: TextStyle(color: _hasApplied ? Colors.white : Colors.white, fontWeight: FontWeight.bold),
                          ),
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