import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/firebase_job_service.dart';
import '../models/job_model.dart';

class JobRepository {
  // 1. Dependencies
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseJobService _service;

  // 2. Dependency Injection
  JobRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseJobService? service,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _service = service ?? FirebaseJobService();

  // --- DASHBOARD & GENERAL ---
  Stream<List<JobModel>> getJobs() => _service.getJobs();
  Future<void> addJob(JobModel job) => _service.addJob(job);

  // --- PROFILE & DECISION LOGIC (Fixes your errors!) ---

  // 1. Get User Profile Stream
  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // 2. Check for Existing Decision
  Future<String?> checkExistingDecision(String jobId, String userId) async {
    final query = await _firestore
        .collection('notifications')
        .where('jobId', isEqualTo: jobId)
        .where('recipientId', isEqualTo: userId)
        .where('type', whereIn: ['hired', 'rejected'])
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data()['type'];
    }
    return null;
  }

  // 3. Hire Applicant (Atomic Transaction)
  Future<void> hireApplicant(String userId, String jobId, String? jobTitle) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String employerName = "Employer";
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      employerName = data['fullName'] ?? data['firstName'] ?? data['username'] ?? currentUser.email?.split('@')[0] ?? "Employer";
    }

    WriteBatch batch = _firestore.batch();
    
    // Increment Hired Count
    batch.update(_firestore.collection('users').doc(userId), {
      'hiredCompleted': FieldValue.increment(1),
    });

    // Create Notification
    DocumentReference notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'recipientId': userId,
      'title': 'Congratulations! You are Hired',
      'message': "You have been hired by $employerName for the position: ${jobTitle ?? 'Job'}.",
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'hired', 
      'jobId': jobId,
    });

    await batch.commit();
  }

  // 4. Reject Applicant
  Future<void> rejectApplicant(String userId, String jobId, String? jobTitle) async {
    await _firestore.collection('notifications').add({
      'recipientId': userId,
      'title': 'Application Update',
      'message': "Your application for ${jobTitle ?? 'the position'} was not selected.",
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'rejected', 
      'jobId': jobId,
    });
  }

  // --- JOB POSTING & APPLICATIONS ---

  Stream<QuerySnapshot> getApplicationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('applications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> withdrawApplication(String docId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    WriteBatch batch = _firestore.batch();
    DocumentReference appDoc = _firestore.collection('users').doc(uid).collection('applications').doc(docId);
    DocumentReference userDoc = _firestore.collection('users').doc(uid);

    batch.delete(appDoc);
    batch.set(userDoc, {'appliedCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    await batch.commit();
  }

  Future<void> postJob({
    required String title,
    required String description,
    required String category,
    required int budgetMin,
    required int budgetMax,
    required String location,
    required String duration,
    required bool isUrgent,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    String posterName = "Employer";
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      posterName = data?['fullName'] ?? data?['firstName'] ?? data?['username'] ?? user.email!.split('@')[0];
    }

    DocumentReference jobRef = await _firestore.collection('jobs').add({
      'title': title,
      'description': description,
      'category': category,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'location': location,
      'duration': duration,
      'isUrgent': isUrgent,
      'postedBy': user.uid,
      'posterName': posterName,
      'posterRating': 0.0,
      'applicants': 0,
      'postedAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });

    await _firestore.collection('notifications').add({
      'recipientId': 'all',
      'title': 'New Job Opportunity',
      'message': "New job posted: $title",
      'type': 'new_post',
      'jobId': jobRef.id,
      'posterId': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // --- HELPERS (Save, Apply, Sync) ---

  Future<void> toggleSaveJob(String jobId, Map<String, dynamic> jobData, bool isCurrentlySaved) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final savedJobRef = _firestore.collection('users').doc(user.uid).collection('saved').doc(jobId);
    final userRef = _firestore.collection('users').doc(user.uid);

    if (isCurrentlySaved) {
      await savedJobRef.delete();
      await userRef.set({'savedCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    } else {
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

  Future<bool> isJobSaved(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _firestore.collection('users').doc(user.uid).collection('saved').doc(jobId).get();
    return doc.exists;
  }

  Future<bool> hasApplied(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final query = await _firestore.collection('users').doc(user.uid).collection('applications').where('jobId', isEqualTo: jobId).limit(1).get();
    return query.docs.isNotEmpty;
  }

  Future<void> applyForJob(String jobId, Map<String, dynamic> jobData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final String employerId = jobData['posterId'] ?? "";
    String applicantName = user.email?.split('@')[0] ?? "Applicant";

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

    await _firestore.collection('users').doc(user.uid).collection('applications').add({
      'jobId': jobId,
      'title': jobData['title'],
      'price': jobData['price'] ?? "0",
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Applied',
      'employerId': employerId,
    });

    await _firestore.collection('users').doc(user.uid).update({'appliedCount': FieldValue.increment(1)});
    await _firestore.collection('jobs').doc(jobId).update({'applicants': FieldValue.increment(1)});
  }

  Future<void> syncApplicationCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final query = await _firestore.collection('users').doc(uid).collection('applications').count().get();
    final int actualCount = query.count ?? 0;
    await _firestore.collection('users').doc(uid).set({'appliedCount': actualCount}, SetOptions(merge: true));
  }
}