import 'package:flutter/material.dart';
import '../../data/models/job_model.dart'; //

class JobListItem extends StatelessWidget {
  final JobModel job;
  const JobListItem({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(job.title),
      subtitle: Text(job.company),
      trailing: Text(job.status),
    );
  }
}