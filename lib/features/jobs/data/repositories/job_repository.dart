import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/firebase_job_service.dart';
import '../models/job_model.dart';

class JobRepository {
  // 1. Keep your existing Service for fetching jobs
  final _service = FirebaseJobService();
  
  // 2. Add Firestore/Auth instances for the new logic
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- EXISTING METHODS (Don't touch these, they work!) ---
  Stream<List<JobModel>> getJobs() => _service.getJobs();
  Future<void> addJob(JobModel job) => _service.addJob(job);

  // --- NEW METHODS (For JobDetailsPage & SOLID Compliance) ---

  // 3. TOGGLE SAVE (Save/Unsave Logic)
  Future<void> toggleSaveJob(String jobId, Map<String, dynamic> jobData, bool isCurrentlySaved) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final savedJobRef = _firestore.collection('users').doc(user.uid).collection('saved').doc(jobId);
    final userRef = _firestore.collection('users').doc(user.uid);

    if (isCurrentlySaved) {
      // Unsave
      await savedJobRef.delete();
      await userRef.set({'savedCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    } else {
      // Save
      await savedJobRef.set({
        'jobId': jobId,
        'title': jobData['title'],
        'price': jobData['price'] ?? "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}",
        'category': jobData['tag'] ?? "General",
        'location': jobData['location'],
        'savedAt': FieldValue.serverTimestamp(),
      });
      await userRef.set({'savedCount': FieldValue.increment(1)}, SetOptions(merge: true));
    }
  }

  // 4. CHECK IF SAVED
  Future<bool> isJobSaved(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('users').doc(user.uid).collection('saved').doc(jobId).get();
    return doc.exists;
  }

  // 5. APPLY FOR JOB
  Future<void> applyForJob(String jobId, Map<String, dynamic> jobData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final String employerId = jobData['posterId'] ?? "";
    String applicantName = user.email?.split('@')[0] ?? "Applicant";

    // A. Create Notification for Employer
    await _firestore.collection('notifications').add({
      'recipientId': employerId,
      'title': 'New Applicant',
      'message': "$applicantName has applied for: ${jobData['title']}",
      'applicantId': user.uid,
      'jobId': jobId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'application',
    });

    // B. Create Application Record
    await _firestore.collection('users').doc(user.uid).collection('applications').add({
      'jobId': jobId,
      'title': jobData['title'],
      'price': jobData['price'] ?? "0",
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Applied',
      'employerId': employerId,
    });

    // C. Update Counters
    await _firestore.collection('users').doc(user.uid).set({'appliedCount': FieldValue.increment(1)}, SetOptions(merge: true));
    await _firestore.collection('jobs').doc(jobId).update({'applicants': FieldValue.increment(1)});
  }

  // 6. CHECK IF APPLIED
  Future<bool> hasApplied(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final query = await _firestore.collection('users').doc(user.uid).collection('applications')
        .where('jobId', isEqualTo: jobId).limit(1).get();
    return query.docs.isNotEmpty;
  }
}