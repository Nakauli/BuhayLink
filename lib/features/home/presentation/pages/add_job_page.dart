import 'package:buhay_link/features/jobs/data/models/job_model.dart';
import 'package:buhay_link/features/jobs/presentation/providers/job_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/presentation/widgets/text_input_field.dart';
import '../../../../core/presentation/widgets/primary_button.dart';

class AddJobPage extends StatelessWidget {
  const AddJobPage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleCtrl = TextEditingController();
    final companyCtrl = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text("Add Job")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextInputField(controller: titleCtrl, label: "Job Title"),
            TextInputField(controller: companyCtrl, label: "Company"),
            const SizedBox(height: 20),
            PrimaryButton(
              text: "Add",
              onPressed: () async {
                final provider = Provider.of<JobProvider>(context, listen: false);
                final job = JobModel(id: "", title: titleCtrl.text, company: companyCtrl.text, status: "open");
                await provider.addJob(job);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}