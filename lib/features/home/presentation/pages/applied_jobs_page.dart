import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../jobs/data/repositories/job_repository.dart'; 
import 'job_details_page.dart'; 

class AppliedJobsPage extends StatefulWidget {
  final bool showBackButton; 

  const AppliedJobsPage({super.key, this.showBackButton = true});

  @override
  State<AppliedJobsPage> createState() => _AppliedJobsPageState();
}

class _AppliedJobsPageState extends State<AppliedJobsPage> {
  // SOLID: DIP - UI depends on Repository
  final JobRepository _jobRepository = JobRepository();

  @override
  void initState() {
    super.initState();
    _jobRepository.syncApplicationCount();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: widget.showBackButton,
        leading: widget.showBackButton 
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            )
          : null,
        title: const Text(
          "Applied Jobs", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
      ),
      body: uid == null
          ? const Center(child: Text("Please login."))
          : StreamBuilder<QuerySnapshot>(
              stream: _jobRepository.getApplicationsStream(), // SOLID: Logic delegated
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined, size: 60, color: Colors.grey),
                        SizedBox(height: 16),
                        Text("No applications found.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    return Dismissible(
                      key: Key(doc.id), 
                      direction: DismissDirection.endToStart, 
                      confirmDismiss: (direction) => _showWithdrawDialog(context),
                      background: _buildDismissBackground(),
                      onDismissed: (direction) => _jobRepository.withdrawApplication(doc.id),
                      child: _buildApplicationCard(context, data),
                    );
                  },
                );
              },
            ),
    );
  }

  // --- UI COMPONENTS (CLEAN CODE) ---

  Future<bool?> _showWithdrawDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Withdraw Application?"),
        content: const Text("Are you sure you want to remove this job?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Withdraw", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16)),
      child: Icon(Icons.delete_outline, color: Colors.red[700]),
    );
  }

  Widget _buildApplicationCard(BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.work, color: Color(0xFF2E7EFF)),
          const SizedBox(width: 16),
          Expanded(child: Text(data['title'] ?? "Job", style: const TextStyle(fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () => _navigateToJob(context, data['jobId']),
            child: const Text("View"),
          ),
        ],
      ),
    );
  }

  void _navigateToJob(BuildContext context, String? jobId) async {
    if (jobId == null) return;
    try {
      DocumentSnapshot jobDoc = await FirebaseFirestore.instance.collection('jobs').doc(jobId).get();
      if (jobDoc.exists && context.mounted) {
          final jobData = jobDoc.data() as Map<String, dynamic>;
          final Map<String, dynamic> jobMap = {
            "title": jobData['title'],
            "tag": jobData['category'],
            "price": "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}",
            "location": jobData['location'],
            "user": jobData['posterName'],
            "posterId": jobData['postedBy'],
            "applicants": "${jobData['applicants']} applicants",
            "description": jobData['description'],
          };

          Navigator.push(context, MaterialPageRoute(builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId)));
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }
}