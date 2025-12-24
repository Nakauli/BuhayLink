import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobApplicantsPage extends StatelessWidget {
  final String jobId;
  final String jobTitle;

  const JobApplicantsPage({super.key, required this.jobId, required this.jobTitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Applicants", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 1. Find all notifications that are 'applications' for THIS job
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('jobId', isEqualTo: jobId)
            .where('type', isEqualTo: 'application')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No applicants yet.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final String applicantId = data['applicantId'];
              final String applicantName = (data['message'] ?? "Unknown").split(' has applied')[0]; 
              // (Ideally, we fetch the real user profile here, but using the message is faster for now)

              return _buildApplicantCard(context, applicantId, applicantName);
            },
          );
        },
      ),
    );
  }

  Widget _buildApplicantCard(BuildContext context, String applicantId, String name) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue[50],
              child: Text(name[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text("Applied just now", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _hireApplicant(context, applicantId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text("Hire", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _hireApplicant(BuildContext context, String applicantId) async {
    // 1. CONFIRMATION DIALOG
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hire this applicant?"),
        content: const Text("This will mark the job as Hired and notify the user."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes, Hire", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 2. Update JOB Status to 'hired'
      await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
        'status': 'hired',
      });

      // 3. Update APPLICANT'S Application Status (So it shows in their HiredJobsPage)
      // We have to find their specific application doc first
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(applicantId)
          .collection('applications')
          .where('jobId', isEqualTo: jobId)
          .get();

      for (var doc in query.docs) {
        await doc.reference.update({'status': 'Hired'});
      }

      // 4. Send NOTIFICATION to Applicant
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': applicantId,
        'title': 'You are Hired!',
        'message': "You have been hired for the job: $jobTitle",
        'type': 'hired',
        'jobId': jobId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Applicant Hired Successfully!")));
        Navigator.pop(context); // Close list
        Navigator.pop(context); // Close details (optional)
      }

    } catch (e) {
      debugPrint("Error hiring: $e");
    }
  }
}