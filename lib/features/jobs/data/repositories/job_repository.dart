import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/firebase_job_service.dart';
import '../models/job_model.dart';

class JobRepository {
  // 1. Dependencies (This defines _firestore so the functions can use it)
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseJobService _service;

  // 2. Constructor
  JobRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseJobService? service,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _service = service ?? FirebaseJobService();

  // --- DASHBOARD & GENERAL ---
  Stream<List<JobModel>> getJobs() => _service.getJobs();
  Future<void> addJob(JobModel job) => _service.addJob(job);

  // --- PROFILE STREAMS ---
  Stream<DocumentSnapshot> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
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
      posterName =
          data?['fullName'] ??
          data?['firstName'] ??
          data?['username'] ??
          user.email!.split('@')[0];
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

  // --- CORE FEATURES: APPLY, HIRE, REJECT ---

  // 1. APPLY FOR JOB
  Future<void> applyForJob(String jobId, Map<String, dynamic> jobData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final String employerId = jobData['posterId'] ?? jobData['postedBy'] ?? "";

    String applicantName =
        user.displayName ?? user.email?.split('@')[0] ?? "Applicant";
    String photoUrl = user.photoURL ?? "";

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data();
      if (data != null) {
        if (data['fullName'] != null) applicantName = data['fullName'];
        if (data['profileImage'] != null) photoUrl = data['profileImage'];
      }
    }

    WriteBatch batch = _firestore.batch();

    // A. Add to Job's 'applicants' subcollection (CRITICAL FIX)
    DocumentReference jobApplicantRef = _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('applicants')
        .doc(user.uid);
    batch.set(jobApplicantRef, {
      'applicantId': user.uid,
      'name': applicantName,
      'email': user.email,
      'photoUrl': photoUrl,
      'appliedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    // B. Add to User's 'applications' subcollection
    DocumentReference userAppRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('applications')
        .doc(jobId);
    batch.set(userAppRef, {
      'jobId': jobId,
      'title': jobData['title'],
      'price': jobData['price'] ?? "0",
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Applied',
      'employerId': employerId,
    });

    // C. Notification for Employer
    DocumentReference notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'recipientId': employerId,
      'title': 'New Applicant',
      'message': "$applicantName has applied for: ${jobData['title']}",
      'applicantId': user.uid,
      'jobId': jobId,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'application',
    });

    // D. Increment Counters
    batch.update(_firestore.collection('users').doc(user.uid), {
      'appliedCount': FieldValue.increment(1),
    });
    batch.update(_firestore.collection('jobs').doc(jobId), {
      'applicants': FieldValue.increment(1),
    });

    await batch.commit();
  }

  // 2. HIRE APPLICANT (Fixed: Accepts 3 arguments)
  Future<void> hireApplicant(
    String jobId,
    String applicantId,
    String jobTitle,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    WriteBatch batch = _firestore.batch();

    // A. Mark Job as Hired
    batch.update(_firestore.collection('jobs').doc(jobId), {
      'status': 'hired',
      'hiredApplicantId': applicantId,
    });

    // B. Mark Applicant as Hired in the Job List
    batch.update(
      _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('applicants')
          .doc(applicantId),
      {'status': 'hired'},
    );

    // C. Update Applicant's Personal List
    DocumentReference userAppRef = _firestore
        .collection('users')
        .doc(applicantId)
        .collection('applications')
        .doc(jobId);
    batch.update(userAppRef, {'status': 'Hired'});

    // D. Increment Stats
    batch.update(_firestore.collection('users').doc(applicantId), {
      'hiredCompleted': FieldValue.increment(1),
    });

    // E. Send Notification
    DocumentReference notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'recipientId': applicantId,
      'title': 'You are Hired!',
      'message': "Congratulations! You have been hired for $jobTitle.",
      'type': 'hired',
      'jobId': jobId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    await batch.commit();
  }

  // 3. REJECT APPLICANT
  Future<void> rejectApplicant(String jobId, String applicantId) async {
    await _firestore
        .collection('jobs')
        .doc(jobId)
        .collection('applicants')
        .doc(applicantId)
        .update({'status': 'rejected'});

    await _firestore.collection('notifications').add({
      'recipientId': applicantId,
      'title': 'Application Update',
      'message': "Your application was not selected at this time.",
      'type': 'rejected',
      'jobId': jobId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // --- HELPERS (Save, Sync, Withdraw) ---

  Future<void> toggleSaveJob(
    String jobId,
    Map<String, dynamic> jobData,
    bool isCurrentlySaved,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final savedJobRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved')
        .doc(jobId);
    final userRef = _firestore.collection('users').doc(user.uid);

    if (isCurrentlySaved) {
      await savedJobRef.delete();
      await userRef.set({
        'savedCount': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    } else {
      await savedJobRef.set({
        'jobId': jobId,
        'title': jobData['title'],
        'price':
            jobData['price'] ??
            "₱${jobData['budgetMin']} - ₱${jobData['budgetMax']}",
        'category': jobData['tag'] ?? "General",
        'location': jobData['location'],
        'savedAt': FieldValue.serverTimestamp(),
      });
      await userRef.set({
        'savedCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }
  }

  Future<bool> isJobSaved(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved')
        .doc(jobId)
        .get();
    return doc.exists;
  }

  Future<bool> hasApplied(String jobId) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final query = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('applications')
        .where('jobId', isEqualTo: jobId)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> withdrawApplication(String docId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in");

    WriteBatch batch = _firestore.batch();
    DocumentReference appDoc = _firestore
        .collection('users')
        .doc(uid)
        .collection('applications')
        .doc(docId);
    DocumentReference userDoc = _firestore.collection('users').doc(uid);

    batch.delete(appDoc);
    batch.set(userDoc, {
      'appliedCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));
    await batch.commit();
  }

  // --- SYNC HELPER (This fixes the 'Applied Jobs' error) ---
  Future<void> syncApplicationCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('applications')
        .count()
        .get();
    final int actualCount = query.count ?? 0;

    await _firestore.collection('users').doc(uid).set({
      'appliedCount': actualCount,
    }, SetOptions(merge: true));
  }

  Future<void> deleteJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).delete();
    } catch (e) {
      throw Exception("Failed to delete job: $e");
    }
  }

  Future<void> updateJob(String jobId, Map<String, dynamic> newValues) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update(newValues);
    } catch (e) {
      throw Exception("Failed to update job: $e");
    }
  }

  // --- CHECK EXISTING DECISION (Restored & Upgraded) ---
  Future<String?> checkExistingDecision(String jobId, String userId) async {
    try {
      // We check the specific applicant document inside the job
      final doc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('applicants')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // If status is 'hired' or 'rejected', return it.
        // If it's 'pending', we return null so the buttons still show.
        final status = data['status'];
        if (status == 'hired' || status == 'rejected') {
          return status;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
