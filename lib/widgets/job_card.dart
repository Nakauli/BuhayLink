import 'package:flutter/material.dart';

class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final bool showStatus; // Optional: to show "Open/Hired" tags for employers

  const JobCard({
    super.key, 
    required this.job, 
    required this.onTap,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    // Safety check for null values
    final String title = job['title'] ?? "Untitled Job";
    final bool isUrgent = job['isUrgent'] ?? false;
    final String description = job['description'] ?? "No description.";
    final String tag = job['tag'] ?? job['category'] ?? "General";
    final String price = job['price'] ?? "₱${job['budgetMin'] ?? 0} - ₱${job['budgetMax'] ?? 0}";
    final String location = job['location'] ?? "Remote";
    final String duration = job['duration'] ?? "3 days";
    final String applicants = (job['applicants'] ?? 0).toString().replaceAll(" applicants", "");
    final String status = (job['status'] ?? "Open").toString().toUpperCase();
    final bool isClosed = status == 'CLOSED' || status == 'HIRED';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5)
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ROW 1: Title and Urgent/Status Tag
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, height: 1.3, color: Colors.black87),
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                ),
                if (showStatus)
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isClosed ? Colors.grey[200] : Colors.green[50],
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Text(status, style: TextStyle(color: isClosed ? Colors.grey : Colors.green[700], fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (isUrgent)
                  Container(
                    margin: const EdgeInsets.only(left: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Icon(Icons.access_time_filled, size: 14, color: Colors.red[400]),
                      const SizedBox(width: 6),
                      Text("Urgent", style: TextStyle(color: Colors.red[400], fontSize: 11, fontWeight: FontWeight.w700))
                    ]),
                  ),
              ],
            ),

            const SizedBox(height: 12),
            
            // ROW 2: Description
            Text(
              description,
              style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 16),
            
            // ROW 3: Category Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
              child: Text(tag, style: TextStyle(color: Colors.blue[700], fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            
            const SizedBox(height: 20),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 16),
            
            // ROW 4: Info Grid
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoItem(Icons.payments_outlined, price, isPrimary: true),
                      const SizedBox(height: 12),
                      _buildInfoItem(Icons.location_on_outlined, location),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoItem(Icons.schedule_outlined, duration),
                      const SizedBox(height: 12),
                      _buildInfoItem(Icons.people_outline_rounded, "$applicants Applicants"),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, {bool isPrimary = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: isPrimary ? const Color(0xFF2E7EFF) : Colors.grey[400]),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: isPrimary ? Colors.black87 : Colors.grey[600],
              fontSize: 13,
              fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500
            ),
            overflow: TextOverflow.ellipsis
          )
        )
      ]
    );
  }
}