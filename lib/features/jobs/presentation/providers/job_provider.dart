import 'package:flutter/material.dart';
import '../../data/models/job_model.dart';
import '../../data/repositories/job_repository.dart'; //

class JobProvider extends ChangeNotifier {
  final _repo = JobRepository();

  Stream<List<JobModel>> get jobs => _repo.getJobs();
  Future<void> addJob(JobModel job) => _repo.addJob(job);
}