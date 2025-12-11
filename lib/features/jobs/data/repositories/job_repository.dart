import '../datasources/firebase_job_service.dart'; //
import '../models/job_model.dart';

class JobRepository {
  final _service = FirebaseJobService();

  Stream<List<JobModel>> getJobs() => _service.getJobs();
  Future<void> addJob(JobModel job) => _service.addJob(job);
}