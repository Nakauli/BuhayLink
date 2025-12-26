import 'models/job_model.dart';

class JobSearchService {
  /// Pure logic: Filters a given list of jobs based on criteria.
  /// It doesn't care where the jobs come from (Provider/API), it just filters them.
  List<JobModel> filterJobs({
    required List<JobModel> jobs,
    String query = "",
    String category = "All Categories",
    double? minBudget,
    double? maxBudget,
    String status = "All",
  }) {
    return jobs.where((job) {
      // 1. Text Search (Title OR Description)
      final matchesSearch = job.title.toLowerCase().contains(query.toLowerCase()) || 
                            job.description.toLowerCase().contains(query.toLowerCase());
      
      // 2. Category Filter
      final matchesCategory = category == "All Categories" || 
                              job.category == category;

      // 3. Budget Filter
      final matchesMinBudget = minBudget == null || job.budgetMin >= minBudget;
      final matchesMaxBudget = maxBudget == null || job.budgetMax <= maxBudget;
      
      // 4. Status Filter (Case insensitive)
      final matchesStatus = status == "All" || job.status.toLowerCase() == status.toLowerCase();

      return matchesSearch && matchesCategory && matchesMinBudget && matchesMaxBudget && matchesStatus;
    }).toList();
  }
}