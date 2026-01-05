import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/firebase_job_service.dart';
import '../models/job_model.dart';

class JobRepository {
  // --- RATING SYSTEM ---

  // 1. Add a Rating & Update Average (Updated with Duplicate Check)
  Future<void> rateUser({
    required String targetUserId,
    required double rating,
    required String review,
    required String jobId,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // --- CHECK FOR DUPLICATES FIRST ---
    // This prevents the user from submitting twice even if the UI lags
    bool alreadyRated = await hasUserRated(targetUserId, jobId);
    if (alreadyRated) {
      throw Exception("You have already rated this user for this job.");
    }
    // ---------------------------------

    // 1. Get Rater's Info (Name/Photo)
    String raterName = currentUser.displayName ?? "User";
    String raterPhoto = currentUser.photoURL ?? "";

    final raterDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    if (raterDoc.exists) {
      final data = raterDoc.data();
      if (data != null) {
        raterName = data['fullName'] ?? raterName;
        raterPhoto = data['profileImage'] ?? raterPhoto;
      }
    }

    WriteBatch batch = _firestore.batch();

    // 2. Add Review
    DocumentReference ratingRef = _firestore
        .collection('users')
        .doc(targetUserId)
        .collection('ratings')
        .doc();

    batch.set(ratingRef, {
      'raterId': currentUser.uid,
      'raterName': raterName,
      'raterPhoto': raterPhoto,
      'rating': rating,
      'review': review,
      'jobId': jobId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // 5. Calculate New Average
    await _recalculateAverage(targetUserId);
  }

  // --- CHECK IF ALREADY RATED (Existing) ---
  Future<bool> hasUserRated(String targetUserId, String jobId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;

    try {
      final query = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('ratings')
          .where('jobId', isEqualTo: jobId)
          .where('raterId', isEqualTo: uid)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print("Error checking rating status: $e");
      return false;
    }
  }

  // Helper: Recalculate Average
  Future<void> _recalculateAverage(String userId) async {
    final snapshots = await _firestore
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .get();

    if (snapshots.docs.isEmpty) return;

    double total = 0;
    for (var doc in snapshots.docs) {
      total += (doc.data()['rating'] ?? 0.0) as double;
    }

    double newAverage = total / snapshots.docs.length;

    await _firestore.collection('users').doc(userId).update({
      'rating': newAverage,
      'reviewCount': snapshots.docs.length,
    });
  }

  // 1. Dependencies
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

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
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

    String rawName =
        user.displayName ?? user.email?.split('@')[0] ?? "Employer";
    String posterPhoto = user.photoURL ?? "";

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final dbName =
              data['name'] ??
              data['fullName'] ??
              data['firstName'] ??
              data['username'];
          if (dbName != null && dbName.toString().isNotEmpty) rawName = dbName;

          final dbPhoto =
              data['photoUrl'] ?? data['profileImage'] ?? data['imageUrl'];
          if (dbPhoto != null && dbPhoto.toString().isNotEmpty)
            posterPhoto = dbPhoto;
        }
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }

    String finalPosterName = _capitalize(rawName);

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
      'posterName': finalPosterName,
      'posterPhoto': posterPhoto,
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

  Future<void> applyForJob(String jobId, Map<String, dynamic> jobData) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final String employerId = jobData['posterId'] ?? jobData['postedBy'] ?? "";
    String applicantName =
        user.displayName ?? user.email?.split('@')[0] ?? "Applicant";
    String photoUrl = user.photoURL ?? "";

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          if (data['fullName'] != null) applicantName = data['fullName'];
          if (data['profileImage'] != null) photoUrl = data['profileImage'];
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }

    WriteBatch batch = _firestore.batch();

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

    if (employerId.isNotEmpty && employerId != user.uid) {
      DocumentReference notifRef = _firestore.collection('notifications').doc();
      batch.set(notifRef, {
        'type': 'application',
        'recipientId': employerId,
        'posterId': user.uid,
        'jobId': jobId,
        'title': 'New Applicant',
        'body': "$applicantName applied for: ${jobData['title']}",
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'applicantId': user.uid,
        'applicantName': applicantName,
      });
    }

    batch.update(_firestore.collection('users').doc(user.uid), {
      'appliedCount': FieldValue.increment(1),
    });
    batch.update(_firestore.collection('jobs').doc(jobId), {
      'applicants': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> hireApplicant(
    String jobId,
    String applicantId,
    String jobTitle,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    WriteBatch batch = _firestore.batch();

    batch.update(_firestore.collection('jobs').doc(jobId), {
      'status': 'hired',
      'hiredApplicantId': applicantId,
    });

    batch.update(
      _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('applicants')
          .doc(applicantId),
      {'status': 'hired'},
    );

    DocumentReference userAppRef = _firestore
        .collection('users')
        .doc(applicantId)
        .collection('applications')
        .doc(jobId);
    batch.update(userAppRef, {'status': 'Hired'});

    batch.update(_firestore.collection('users').doc(applicantId), {
      'hiredCompleted': FieldValue.increment(1),
    });

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

  // --- MARK JOB COMPLETE ---
  Future<void> markJobComplete(String jobId, String workerId) async {
    WriteBatch batch = _firestore.batch();

    batch.update(_firestore.collection('jobs').doc(jobId), {
      'status': 'completed',
    });

    batch.update(
      _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('applicants')
          .doc(workerId),
      {'status': 'completed'},
    );

    batch.update(
      _firestore
          .collection('users')
          .doc(workerId)
          .collection('applications')
          .doc(jobId),
      {'status': 'Completed'},
    );

    DocumentReference notifRef = _firestore.collection('notifications').doc();
    batch.set(notifRef, {
      'recipientId': workerId,
      'title': 'Job Completed',
      'message':
          'The employer has marked the job as completed. You can now leave a rating.',
      'type': 'completed',
      'jobId': jobId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });

    await batch.commit();
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

  Future<void> syncApplicationCount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('applications')
        .count()
        .get();
    await _firestore.collection('users').doc(uid).set({
      'appliedCount': query.count ?? 0,
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

  Future<String?> checkExistingDecision(String jobId, String userId) async {
    try {
      final doc = await _firestore
          .collection('jobs')
          .doc(jobId)
          .collection('applicants')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];
        if (status == 'hired' || status == 'rejected') return status;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
