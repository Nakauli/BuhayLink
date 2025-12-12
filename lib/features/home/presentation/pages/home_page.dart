import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../jobs/presentation/providers/job_provider.dart'; //
import '../../../jobs/presentation/widgets/job_list_item.dart';
import '../../../jobs/data/models/job_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<JobProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Jobs")),
      body: StreamBuilder<List<JobModel>>(
        stream: provider.jobs,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final jobs = snapshot.data!;
          return ListView(children: jobs.map((j) => JobListItem(job: j)).toList());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-job'),
        child: const Icon(Icons.add),
      ),
    );
  }
}