import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardRepository {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // 1. Get All Jobs Stream (For "Find Jobs")
  Stream<QuerySnapshot> getAllJobsStream() {
    return _firestore.collection('jobs').orderBy('postedAt', descending: true).snapshots();
  }

  // 2. Get My Posts Stream (For "My Posts")
  Stream<QuerySnapshot> getMyPostsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    
    return _firestore
        .collection('jobs')
        .where('postedBy', isEqualTo: uid)
        .orderBy('postedAt', descending: true)
        .snapshots();
  }

  // 3. Get User Stats Stream (For the 4 boxes)
  Stream<DocumentSnapshot> getUserStatsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    
    return _firestore.collection('users').doc(uid).snapshots();
  }
}