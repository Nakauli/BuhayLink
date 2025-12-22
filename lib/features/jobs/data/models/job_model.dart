class JobModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String postedBy;    // Needed for the Filter
  final String status;
  final int budgetMin;
  final int budgetMax;
  final String company;     // Added back to fix your error!

  JobModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.postedBy,
    required this.status,
    required this.budgetMin,
    required this.budgetMax,
    required this.company,
  });

  factory JobModel.fromMap(String id, Map<String, dynamic> map) {
    return JobModel(
      id: id,
      title: map['title'] ?? map['jobTitle'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'General',
      // This maps your database's 'postedBy' to our model so we can filter it
      postedBy: map['postedBy'] ?? map['recruiterId'] ?? '', 
      status: map['status'] ?? 'open',
      budgetMin: map['budgetMin'] ?? 0,
      budgetMax: map['budgetMax'] ?? 0,
      // Fixes the "company" error by using the poster's name
      company: map['posterName'] ?? map['company'] ?? 'Employer', 
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'category': category,
    'postedBy': postedBy,
    'status': status,
    'budgetMin': budgetMin,
    'budgetMax': budgetMax,
    'company': company,
  };
}