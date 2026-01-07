import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===========================================================================
  // EXISTING METHODS (KEPT AS REQUESTED)
  // ===========================================================================

  /// Stream of ALL jobs (Used in Search Page)
  Stream<QuerySnapshot> getAllJobsStream() {
    return _firestore
        .collection('jobs')
        .orderBy('postedAt', descending: true)
        .snapshots();
  }

  /// Stream of MY posted jobs
  Stream<QuerySnapshot> getMyPostsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection('jobs')
        .where('postedBy', isEqualTo: uid)
        .orderBy('postedAt', descending: true)
        .snapshots();
  }

  /// Stream of User Stats (Header data)
  Stream<DocumentSnapshot> getUserStatsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore.collection('users').doc(uid).snapshots();
  }

  // ===========================================================================
  // 🚀 NEW METHOD: PAGINATED FETCH FOR ENDLESS SCROLLING
  // ===========================================================================

  /// Fetches jobs in chunks (pages) instead of all at once.
  Future<QuerySnapshot> getJobsPaged({
    required int limit,
    DocumentSnapshot? lastDoc,
    bool isMyPosts = false,
  }) async {
    final uid = _auth.currentUser?.uid;

    // Start building the query
    Query query = _firestore
        .collection('jobs')
        .orderBy('postedAt', descending: true);

    // 1. FILTER: "My Posts" vs "Find Jobs"
    if (uid != null) {
      if (isMyPosts) {
        // Show ONLY my posts
        query = query.where('postedBy', isEqualTo: uid);
      } else {
        // Show everything EXCEPT my posts (so I don't apply to my own job)
        query = query.where('postedBy', isNotEqualTo: uid);
      }
    }

    // 2. PAGINATION: Start after the last document we saw
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    // 3. LIMIT: Fetch only 'x' amount
    return query.limit(limit).get();
  }
}
