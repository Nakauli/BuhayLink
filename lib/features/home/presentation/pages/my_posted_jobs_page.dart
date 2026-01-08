import 'package:buhay_link/features/jobs/data/repositories/job_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'job_details_page.dart';

class MyPostedJobsPage extends StatelessWidget {
  final String title;
  final List<String> statusFilter;
  final JobRepository _jobRepository = JobRepository();

  MyPostedJobsPage({
    super.key,
    required this.title,
    required this.statusFilter,
  });

  // --- 1. DELETE FUNCTION ---
  void _confirmDelete(BuildContext parentContext, String jobId) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Job?"),
        content: const Text(
          "Are you sure you want to remove this job post? This cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _jobRepository.deleteJob(jobId);

              if (!parentContext.mounted) return;

              ScaffoldMessenger.of(parentContext).showSnackBar(
                const SnackBar(content: Text("Job deleted successfully")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- 2. EDIT FUNCTION ---
  void _showEditDialog(
    BuildContext context,
    String jobId,
    Map<String, dynamic> currentData,
  ) {
    final titleCtrl = TextEditingController(text: currentData['title']);
    final descCtrl = TextEditingController(text: currentData['description']);
    final minBudgetCtrl = TextEditingController(
      text: currentData['budgetMin'].toString(),
    );
    final maxBudgetCtrl = TextEditingController(
      text: currentData['budgetMax'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Job Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: "Job Title"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minBudgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Min Budget",
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: maxBudgetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Max Budget",
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _jobRepository.updateJob(jobId, {
                'title': titleCtrl.text,
                'description': descCtrl.text,
                'budgetMin': double.tryParse(minBudgetCtrl.text) ?? 0,
                'budgetMax': double.tryParse(maxBudgetCtrl.text) ?? 0,
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Job updated successfully!")),
                );
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: uid == null
          ? const Center(child: Text("Please login"))
          : StreamBuilder<QuerySnapshot>(
              stream: _getJobStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text("No jobs found"));
                }

                // --- FIX: Filter Client Side to avoid Index Errors ---
                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  if (statusFilter.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'];

                  // [LOGIC UPDATE] If filtering for 'hired', also show 'in_progress' jobs
                  if (statusFilter.contains('hired') &&
                      status == 'in_progress') {
                    return true;
                  }

                  return statusFilter.contains(status);
                }).toList();
                // ----------------------------------------------------

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_off_outlined,
                          size: 60,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No $title found.",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String jobId = doc.id;

                    return _buildMyJobCard(context, data, jobId);
                  },
                );
              },
            ),
    );
  }

  Stream<QuerySnapshot> _getJobStream(String uid) {
    return FirebaseFirestore.instance
        .collection('jobs')
        .where('postedBy', isEqualTo: uid)
        .orderBy('postedAt', descending: true)
        .snapshots();
  }

  Widget _buildMyJobCard(
    BuildContext context,
    Map<String, dynamic> data,
    String jobId,
  ) {
    String status = data['status'] ?? 'open';
    // Logic for styling based on status
    bool isClosed = status == 'closed' || status == 'completed';
    Color statusColor = Colors.blue;
    if (status == 'hired') statusColor = Colors.orange;
    if (status == 'in_progress') statusColor = Colors.purple;
    if (status == 'completed') statusColor = Colors.green;
    if (status == 'closed') statusColor = Colors.grey;

    return GestureDetector(
      onTap: () {
        final Map<String, dynamic> jobMap = {
          "title": data['title'],
          "tag": data['category'],
          "price": "₱${data['budgetMin']} - ₱${data['budgetMax']}",
          "location": data['location'],
          "user": data['posterName'],
          "posterId": data['postedBy'],
          "hiredApplicantId": data['hiredApplicantId'],
          "hiredCount": data['hiredCount'], // Pass hired count
          "rating": "Me",
          "applicants": "${data['applicants'] ?? 0} applicants",
          "duration": data['duration'] ?? "N/A",
          "isUrgent": data['isUrgent'] ?? false,
          "description": data['description'] ?? "",
          "status": data['status'],
        };

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(
              job: jobMap,
              jobId: jobId,
              // [UPDATED LOGIC] Consider it 'isHired' mode if status is hired OR in_progress
              isHired: status == 'hired' || status == 'in_progress',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ROW 1: Title and Status Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    data['title'] ?? "Untitled",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ROW 2: Applicants and Duration
            Row(
              children: [
                Icon(Icons.people_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  "${data['applicants'] ?? 0} Applicants",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(width: 16),

                // Show Hired Count if > 0
                if (data['hiredCount'] != null &&
                    (data['hiredCount'] as int) > 0) ...[
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Colors.green[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${data['hiredCount']} Hired",
                    style: TextStyle(color: Colors.green[600], fontSize: 13),
                  ),
                  const SizedBox(width: 16),
                ],

                Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  data['duration'] ?? "N/A",
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),

            const Divider(height: 24), // Visual separator
            // ROW 3: ACTION BUTTONS (Edit & Delete)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // EDIT BUTTON
                TextButton.icon(
                  onPressed: () => _showEditDialog(context, jobId, data),
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                  label: const Text(
                    "Edit",
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                const SizedBox(width: 8),
                // DELETE BUTTON
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, jobId),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    "Delete",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
