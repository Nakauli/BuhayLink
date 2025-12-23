import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'public_profile_page.dart'; 
import 'job_applicants_page.dart'; 

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
  bool _isSaved = false; 

  @override
  void initState() {
    super.initState();
    _checkIfApplied();
    _checkIfSaved();
  }

  // --- LOGIC: CHECK IF SAVED ---
  Future<void> _checkIfSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('saved').doc(widget.jobId).get();
      if (doc.exists && mounted) setState(() => _isSaved = true);
    } catch (e) { debugPrint("$e"); }
  }

  // --- LOGIC: TOGGLE SAVE ---
  Future<void> _toggleSaveJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isSaved = !_isSaved);
    final savedJobRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('saved').doc(widget.jobId);
    try {
      if (_isSaved) {
        await savedJobRef.set({
          'jobId': widget.jobId,
          'title': widget.job['title'],
          'price': widget.job['price'] ?? "₱${widget.job['budgetMin']} - ₱${widget.job['budgetMax']}",
          'category': widget.job['tag'] ?? "General",
          'location': widget.job['location'],
          'savedAt': FieldValue.serverTimestamp(),
        });
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'savedCount': FieldValue.increment(1)}, SetOptions(merge: true));
      } else {
        await savedJobRef.delete();
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'savedCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      }
    } catch (e) { setState(() => _isSaved = !_isSaved); }
  }

  // --- LOGIC: CHECK IF ALREADY APPLIED ---
  Future<void> _checkIfApplied() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final query = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('applications').where('jobId', isEqualTo: widget.jobId).get();
      if (query.docs.isNotEmpty && mounted) setState(() => _hasApplied = true);
    } catch (e) {}
  }

  // --- LOGIC: APPLY FOR JOB ---
  Future<void> _applyForJob() async {
    setState(() => _isApplying = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String employerId = widget.job['posterId'] ?? "";
    
    try {
      String applicantName = user.email?.split('@')[0] ?? "Applicant";
      
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('applications').add({
        'jobId': widget.jobId,
        'title': widget.job['title'],
        'price': widget.job['price'] ?? "0",
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'Applied',
        'employerId': employerId,
      });
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'appliedCount': FieldValue.increment(1)}, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({'applicants': FieldValue.increment(1)});
      
      setState(() => _hasApplied = true);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application Sent!"), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. ROBUST OWNER CHECK (Converts to String to be safe)
    final currentUser = FirebaseAuth.instance.currentUser;
    final String currentUid = currentUser?.uid ?? "";
    final String posterId = (widget.job['posterId'] ?? "").toString();
    
    final bool isOwner = currentUid.isNotEmpty && currentUid == posterId;

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
          // Hide bookmark button if I am the owner
          if (!isOwner) 
            IconButton(
              icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, color: _isSaved ? const Color(0xFF2E7EFF) : Colors.black),
              onPressed: _toggleSaveJob,
            ),
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
                  
                  // HIRED / REJECTED BANNERS
                  if (widget.isHired && !isOwner)
                    _buildBanner(Colors.green, Icons.check_circle, "Congratulations!", "You have been hired for this project."),
                  
                  if (widget.isRejected && !isOwner)
                    _buildBanner(Colors.red, Icons.cancel, "Application Update", "Unfortunately, you were not selected."),

                  Text(widget.job['title'] ?? "Job Title", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(20)),
                    child: Text(widget.job['tag'].toString(), style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  
                  // ONLY SHOW EMPLOYER CARD IF NOT OWNER
                  if (!isOwner) 
                     _buildEmployerCard(),

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
                  Text(widget.job['description'] ?? "No description.", style: TextStyle(color: Colors.grey[600], height: 1.6, fontSize: 14)),
                ],
              ),
            ),
          ),

          // --- DYNAMIC BOTTOM BAR ---
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
                
                // --- THE FIX: OWNER SEES "APPLICANTS", USER SEES "APPLY" ---
                Expanded(
                  child: isOwner
                    // A. OWNER VIEW
                    ? ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => JobApplicantsPage(
                            jobId: widget.jobId,
                            jobTitle: widget.job['title'],
                          )));
                        },
                        icon: const Icon(Icons.people),
                        label: const Text("View Applicants"), // Explicit Label
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7EFF),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    // B. APPLICANT VIEW
                    : widget.isHired
                        ? ElevatedButton(onPressed: null, style: ElevatedButton.styleFrom(disabledBackgroundColor: Colors.green[50]), child: const Text("Hired", style: TextStyle(color: Colors.green))) 
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

  Widget _buildBanner(Color color, IconData icon, String title, String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [Icon(icon, color: color, size: 40), const SizedBox(height: 8), Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 4), Text(message, textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.8), fontSize: 13))]),
    );
  }
  
  // --- EMPLOYER CARD HELPER ---
  Widget _buildEmployerCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.job['posterId'] != null ? FirebaseFirestore.instance.collection('users').doc(widget.job['posterId']).snapshots() : null,
      builder: (context, snapshot) {
        String name = widget.job['user'] ?? "Employer";
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          name = data?['fullName'] ?? data?['firstName'] ?? data?['username'] ?? name;
        }
        String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : "E";
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.blue.shade300, Colors.purple.shade300])), child: Center(child: Text(firstLetter, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), Row(children: [const Icon(Icons.star, color: Colors.amber, size: 14), const SizedBox(width: 4), Text(widget.job['rating'] == "New" ? "New Member" : "${widget.job['rating']} (24 reviews)", style: TextStyle(color: Colors.grey[600], fontSize: 12))])]),
              ),
              OutlinedButton(
                onPressed: () {
                  if (widget.job['posterId'] != null) Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(userId: widget.job['posterId'], userName: name)));
                },
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), side: BorderSide(color: Colors.grey.shade300)),
                child: const Text("View Profile", style: TextStyle(color: Colors.black87, fontSize: 12)),
              )
            ],
          ),
        );
      },
    );
  }
}