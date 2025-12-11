import 'package:cloud_firestore/cloud_firestore.dart'; //
import '../models/job_model.dart';

class FirebaseJobService {
  final _db = FirebaseFirestore.instance;

  Stream<List<JobModel>> getJobs() {
    return _db.collection('jobs').snapshots().map(
      (snap) => snap.docs.map((d) => JobModel.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<void> addJob(JobModel job) => _db.collection('jobs').add(job.toMap());
}