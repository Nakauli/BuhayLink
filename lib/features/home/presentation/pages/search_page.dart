import 'package:flutter/material.dart';

// 1. UPDATED DATA MODEL
// Added 'posterId' so we can distinguish who posted what.
class JobPost {
  final String id;
  final String posterId; // NEW: The ID of the user who posted the job
  final String title;
  final String description;
  final String category;
  final double minPrice;
  final double maxPrice;
  final bool isUrgent;
  final bool isHighPay;
  final bool isNearby;
  final String posterName;
  final double posterRating;
  final Color posterColor;

  JobPost({
    required this.id,
    required this.posterId,
    required this.title,
    required this.description,
    required this.category,
    required this.minPrice,
    required this.maxPrice,
    required this.isUrgent,
    required this.isHighPay,
    required this.isNearby,
    required this.posterName,
    required this.posterRating,
    required this.posterColor,
  });
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // 2. SIMULATE LOGGED-IN USER
  // In your real app, this comes from FirebaseAuth.instance.currentUser!.uid
  final String currentUserId = 'my_user_id_123'; 

  // 3. MOCK DATA
  // I added one job posted by 'currentUserId' to test that it gets HIDDEN.
  final List<JobPost> _allJobs = [
    JobPost(
      id: '1',
      posterId: 'other_user_001', // NOT ME
      title: 'Plumbing Repair',
      description: 'Need someone to fix a leaking pipe in the kitchen...',
      category: 'General',
      minPrice: 12122121,
      maxPrice: 211121221,
      isUrgent: true,
      isHighPay: false,
      isNearby: false,
      posterName: 'kym bogani',
      posterRating: 0.0,
      posterColor: Colors.blue.shade100,
    ),
    JobPost(
      id: '2',
      posterId: 'other_user_002', // NOT ME
      title: 'Garden Cleaning',
      description: 'Remove weeds and cut grass in a 50sqm backyard.',
      category: 'General',
      minPrice: 500,
      maxPrice: 1000,
      isUrgent: true,
      isHighPay: true,
      isNearby: true,
      posterName: 'John Doe',
      posterRating: 4.8,
      posterColor: Colors.green.shade100,
    ),
    JobPost(
      id: '3',
      posterId: 'my_user_id_123', // THIS IS ME (Should be hidden)
      title: 'My Own Job Post',
      description: 'This shouldn not appear in the search results.',
      category: 'Personal',
      minPrice: 0,
      maxPrice: 0,
      isUrgent: false,
      isHighPay: false,
      isNearby: true,
      posterName: 'Me',
      posterRating: 5.0,
      posterColor: Colors.red.shade100,
    ),
  ];

  // Search & Filter State
  String _searchQuery = '';
  String _selectedFilter = 'All'; 

  // 4. UPDATED FILTER LOGIC
  List<JobPost> get _filteredJobs {
    return _allJobs.where((job) {
      
      // RULE 1: HIDE MY OWN POSTS
      // If the job's posterId matches my ID, skip it immediately.
      if (job.posterId == currentUserId) {
        return false; 
      }

      // RULE 2: Search Text Match
      final matchesSearch = job.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          job.description.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      // RULE 3: Filter Buttons
      if (_selectedFilter == 'All') return true;
      if (_selectedFilter == 'Nearby') return job.isNearby;
      if (_selectedFilter == 'Urgent') return job.isUrgent;
      if (_selectedFilter == 'High Pay') return job.isHighPay;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // --- SEARCH BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- FILTER CHIPS ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('All', icon: null),
                  const SizedBox(width: 8),
                  _buildFilterChip('Nearby', icon: Icons.location_on_outlined),
                  const SizedBox(width: 8),
                  _buildFilterChip('Urgent', icon: Icons.access_time),
                  const SizedBox(width: 8),
                  _buildFilterChip('High Pay', icon: Icons.attach_money),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --- JOB LIST ---
            Expanded(
              child: _filteredJobs.isEmpty 
              ? Center(child: Text("No jobs found", style: TextStyle(color: Colors.grey))) 
              : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredJobs.length,
                itemBuilder: (context, index) {
                  final job = _filteredJobs[index];
                  return _buildJobCard(job);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, {IconData? icon}) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(JobPost job) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  job.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (job.isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB), 
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(
                      color: Color(0xFFFF5C5C), 
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 8),

          Text(
            job.description,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD), 
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              job.category,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    '₱${job.minPrice.toStringAsFixed(0)} - ₱${job.maxPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: job.posterColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      job.posterName.isNotEmpty ? job.posterName[0].toUpperCase() : "?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        job.posterName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            job.posterRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}