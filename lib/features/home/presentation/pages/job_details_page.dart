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
  bool _hasApplied = false; // Tracks if the user has already applied

  @override
  void initState() {
    super.initState();
    _checkIfApplied();
  }

  /// 1. Check if the user has already applied to this job on load
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
        setState(() {
          _hasApplied = true; // Updates button to "Applied"
        });
      }
    } catch (e) {
      debugPrint("Error checking application status: $e");
    }
  }

  /// 2. Handle the Application Process
  Future<void> _applyForJob() async {
    setState(() => _isApplying = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Safety Check: Ensure there is an employer to notify
    final String employerId = widget.job['posterId'] ?? "";
    if (employerId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Employer information missing.")));
      setState(() => _isApplying = false);
      return;
    }

    try {
      // Get Applicant Name (Fallback to email username if profile name missing)
      String applicantName = user.email?.split('@')[0] ?? "Someone";
      
      // OPTIONAL: Fetch the real name from your profile to make the notification nicer
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        applicantName = userData['fullName'] ?? userData['firstName'] ?? applicantName;
      }

      // A. SAVE TO USER'S HISTORY (For the "Applied" Dashboard Box)
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
        'employerId': employerId,
      });

      // B. SEND NOTIFICATION TO EMPLOYER (So they see "Who Applied")
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': employerId,
        'title': 'New Applicant',
        'message': "$applicantName has applied for: ${widget.job['title']}",
        'applicantId': user.uid, // Saves ID so employer can click to view profile
        'jobId': widget.jobId,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'application',
      });

      // C. UPDATE STATISTICS (Counters)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'appliedCount': FieldValue.increment(1),
      });
      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
        'applicants': FieldValue.increment(1),
      });

      // Update UI state
      setState(() {
        _hasApplied = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Application Sent! Employer notified."), backgroundColor: Colors.green),
        );
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
                  // Job Title
                  Text(
                    widget.job['title'],
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 12),
                  // Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.job['tag'].toString(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  
                  const SizedBox(height: 24),

                  // Profile Section (With Real-Time Name Fetching)
                  StreamBuilder<DocumentSnapshot>(
                    stream: widget.job['posterId'] != null
                        ? FirebaseFirestore.instance.collection('users').doc(widget.job['posterId']).snapshots()
                        : null,
                    builder: (context, snapshot) {
                      String name = widget.job['user'] ?? "Employer";
                      final currentUser = FirebaseAuth.instance.currentUser;
                      
                      // Handle "Me" case
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
                  // Info Grid
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
                  // Description
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

          // Bottom Action Bar
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
                    // Disable button if loading OR already applied
                    onPressed: (_isApplying || _hasApplied) ? null : _applyForJob,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      // Turn Green if Applied, Blue if available
                      backgroundColor: _hasApplied ? Colors.green : const Color(0xFF2E7EFF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      // Ensure disabled state is visible/readable
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