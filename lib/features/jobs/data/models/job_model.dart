class JobModel {
  final String id;
  final String title;
  final String company;
  final String status;

  JobModel({required this.id, required this.title, required this.company, required this.status}); //

  factory JobModel.fromMap(String id, Map<String, dynamic> map) {
    return JobModel(
      id: id,
      title: map['title'] ?? '',
      company: map['company'] ?? '',
      status: map['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {'title': title, 'company': company, 'status': status};
}