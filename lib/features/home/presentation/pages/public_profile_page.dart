import 'package:buhay_link/features/jobs/data/repositories/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// SOLID: Import Repositories
import '../../../jobs/data/repositories/job_repository.dart';

import 'hired_jobs_page.dart';

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
  // SOLID: DIP - Depend on Repositories
  final JobRepository _jobRepository = JobRepository();
  final ChatRepository _chatRepository = ChatRepository();

  bool _isLoading = false;
  String? _decisionStatus; 

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      _loadDecision();
    }
  }

  Future<void> _loadDecision() async {
    final status = await _jobRepository.checkExistingDecision(widget.jobId!, widget.userId);
    if (mounted) setState(() => _decisionStatus = status);
  }

  Future<void> _handleHire() async {
    setState(() => _isLoading = true);
    try {
      await _jobRepository.hireApplicant(widget.userId, widget.jobId!, widget.jobTitle);
      setState(() => _decisionStatus = 'hired');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Applicant Hired!"), backgroundColor: Colors.green));
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
        leading: const BackButton(color: Colors.black),
        title: const Text("Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _jobRepository.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name = data['fullName'] ?? data['firstName'] ?? widget.userName;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildAvatar(name),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(data['location'] ?? "Philippines", style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 24),
                _buildTrustBadges(),
                const SizedBox(height: 32),
                _buildStatsRow(data),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 24),
                _buildAboutSection(data['bio'] ?? "No bio available."),
                const SizedBox(height: 40),
                
                // --- DECISION BUTTONS ---
                if (_decisionStatus != null)
                  _buildDecisionBanner()
                else if (widget.jobId != null)
                  _buildActionButtons(),

                // --- CONTACT BUTTON (Functional via ChatRepository) ---
                SizedBox(
                  width: double.infinity, 
                  height: 50, 
                  child: OutlinedButton.icon(
                    onPressed: () => _chatRepository.startChat(context, widget.userId, name), 
                    icon: const Icon(Icons.message_outlined), 
                    label: const Text("Contact"),
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))
                  )
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- UI HELPER WIDGETS (SRP for UI) ---

  Widget _buildAvatar(String name) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.blue[700],
          child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.bold)),
        ),
        const Icon(Icons.verified, color: Colors.blue, size: 28),
      ],
    );
  }

  Widget _buildTrustBadges() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Text("Verified Professional", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(data['appliedCount']?.toString() ?? "0", "Applied"),
        _buildStatItem(data['hiredCompleted']?.toString() ?? "0", "Hired", isClickable: true),
        _buildStatItem(data['rating']?.toString() ?? "0.0", "Rating"),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, {bool isClickable = false}) {
    return InkWell(
      onTap: isClickable ? () => Navigator.push(context, MaterialPageRoute(builder: (context) => HiredJobsPage(userId: widget.userId))) : null,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAboutSection(String bio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(bio, style: const TextStyle(height: 1.5)),
      ],
    );
  }

  Widget _buildDecisionBanner() {
    bool isHired = _decisionStatus == 'hired';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isHired ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isHired ? Colors.green : Colors.red),
      ),
      child: Center(
        child: Text(
          isHired ? "APPLICANT HIRED" : "APPLICANT REJECTED",
          style: TextStyle(color: isHired ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: () => _jobRepository.rejectApplicant(widget.userId, widget.jobId!, widget.jobTitle), child: const Text("Reject"))),
          const SizedBox(width: 16),
          Expanded(child: ElevatedButton(onPressed: _handleHire, child: const Text("Hire"))),
        ],
      ),
    );
  }
}