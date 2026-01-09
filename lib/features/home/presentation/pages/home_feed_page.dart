import 'package:buhay_link/widgets/home_animated_header.dart';
import 'package:buhay_link/widgets/home_widgets.dart';
import 'package:buhay_link/features/jobs/data/repositories/dashboard_repository.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'job_details_page.dart';

// WIDGETS
import '../../../../widgets/job_card.dart';

/// The Home Feed Page.
///
/// SOLID Principle: Single Responsibility (SRP)
/// Responsible ONLY for fetching, filtering, and rendering the list of jobs.
class HomeFeedPage extends StatefulWidget {
  final bool showMyPosts;
  final Function(bool) onModeChanged;
  final Function(List<String>) onMarkRead;

  const HomeFeedPage({
    super.key,
    required this.showMyPosts,
    required this.onModeChanged,
    required this.onMarkRead,
  });

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  // Data Repository (Dependency)
  final DashboardRepository _repository = DashboardRepository();
  final ScrollController _scrollController = ScrollController();

  // --- PAGINATION & FILTER STATE ---
  final int _jobsPerPage = 20;
  List<DocumentSnapshot> _jobs = [];
  bool _isJobsLoading = false;
  int _currentPage = 1;
  final Map<int, DocumentSnapshot?> _pageCursors = {1: null};
  bool _hasNextPage = true;
  String _selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    _fetchJobs(page: 1);
  }

  // Reloads data if the parent (Dashboard) switches modes
  @override
  void didUpdateWidget(covariant HomeFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showMyPosts != widget.showMyPosts) {
      _resetAndFetch();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Resets pagination and re-fetches
  void _resetAndFetch() {
    setState(() {
      _selectedFilter = "All";
      _pageCursors.clear();
      _pageCursors[1] = null;
    });
    _fetchJobs(page: 1);
  }

  /// Main Data Fetching Logic
  Future<void> _fetchJobs({required int page}) async {
    setState(() => _isJobsLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      Query query = FirebaseFirestore.instance
          .collection('jobs')
          .orderBy('postedAt', descending: true);

      // Filter: Show only my posts if enabled
      if (widget.showMyPosts && user != null) {
        query = query.where('postedBy', isEqualTo: user.uid);
      }

      // Pagination Cursor
      if (_pageCursors[page] != null) {
        query = query.startAfterDocument(_pageCursors[page]!);
      }

      QuerySnapshot snapshot = await query.limit(_jobsPerPage).get();

      if (snapshot.docs.isNotEmpty) {
        var newJobs = snapshot.docs;

        // Client-side filtering
        if (!widget.showMyPosts && user != null) {
          // Hide my own posts from the public feed
          newJobs = newJobs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['postedBy'] != user.uid;
          }).toList();
        }

        // Apply Tag Filters
        if (!widget.showMyPosts) {
          if (_selectedFilter == "Urgent") {
            newJobs = newJobs
                .where((doc) => (doc.data() as Map)['isUrgent'] == true)
                .toList();
          } else if (_selectedFilter == "₱ High Pay") {
            newJobs = newJobs
                .where(
                  (doc) => ((doc.data() as Map)['budgetMax'] ?? 0) >= 20000,
                )
                .toList();
          } else if (_selectedFilter == "Nearby") {
            // Hardcoded example location
            newJobs = newJobs
                .where(
                  (doc) => (doc.data() as Map)['location']
                      .toString()
                      .toLowerCase()
                      .contains("santo tomas"),
                )
                .toList();
          }
        }

        if (mounted) {
          setState(() {
            _jobs = newJobs;
            _currentPage = page;
            _hasNextPage = snapshot.docs.length == _jobsPerPage;
            if (snapshot.docs.isNotEmpty) {
              _pageCursors[page + 1] = snapshot.docs.last;
            }
            _isJobsLoading = false;
          });

          // Scroll to top on refresh/filter change
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      } else {
        if (mounted)
          setState(() {
            _jobs = [];
            _hasNextPage = false;
            _isJobsLoading = false;
          });
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
      if (mounted) setState(() => _isJobsLoading = false);
    }
  }

  void _nextPage() {
    if (_hasNextPage) _fetchJobs(page: _currentPage + 1);
  }

  void _prevPage() {
    if (_currentPage > 1) _fetchJobs(page: _currentPage - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Animated Header
        HomeAnimatedHeader(
          repository: _repository,
          showMyPosts: widget.showMyPosts,
          onMarkRead: widget.onMarkRead,
        ),

        // 2. Toggle Mode Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: ModeToggleButton(
                    text: "Find Jobs",
                    isActive: !widget.showMyPosts,
                    onTap: () => widget.onModeChanged(false),
                  ),
                ),
                Expanded(
                  child: ModeToggleButton(
                    text: "My Posts",
                    isActive: widget.showMyPosts,
                    onTap: () => widget.onModeChanged(true),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 3. Filter Chips (Only in Find Jobs mode)
        if (!widget.showMyPosts)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              children: [
                FilterChipButton(
                  label: "All",
                  icon: Icons.grid_view_rounded,
                  isSelected: _selectedFilter == "All",
                  onTap: () => setState(() {
                    _selectedFilter = "All";
                    _fetchJobs(page: 1);
                  }),
                ),
                const SizedBox(width: 12),
                FilterChipButton(
                  label: "Nearby",
                  icon: Icons.near_me_rounded,
                  isSelected: _selectedFilter == "Nearby",
                  onTap: () => setState(() {
                    _selectedFilter = "Nearby";
                    _fetchJobs(page: 1);
                  }),
                ),
                const SizedBox(width: 12),
                FilterChipButton(
                  label: "Urgent",
                  icon: Icons.timer_rounded,
                  isSelected: _selectedFilter == "Urgent",
                  onTap: () => setState(() {
                    _selectedFilter = "Urgent";
                    _fetchJobs(page: 1);
                  }),
                ),
                const SizedBox(width: 12),
                FilterChipButton(
                  label: "₱ High Pay",
                  icon: Icons.account_balance_wallet_rounded,
                  isSelected: _selectedFilter == "₱ High Pay",
                  onTap: () => setState(() {
                    _selectedFilter = "₱ High Pay";
                    _fetchJobs(page: 1);
                  }),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // 4. Job List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _pageCursors.clear();
              _pageCursors[1] = null;
              await _fetchJobs(page: 1);
            },
            child: _isJobsLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                ? EmptyStateWidget(showMyPosts: widget.showMyPosts)
                : ListView.separated(
                    controller: _scrollController,
                    // Performance Optimizations
                    cacheExtent: 2000.0,
                    addRepaintBoundaries: true,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                    itemCount: _jobs.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == _jobs.length) {
                        return PaginationControls(
                          currentPage: _currentPage,
                          hasNextPage: _hasNextPage,
                          onPrev: _prevPage,
                          onNext: _nextPage,
                        );
                      }
                      return _buildJobCard(_jobs[index]);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String jobId = doc.id;
    // Map data safely
    final Map<String, dynamic> jobMap = {
      "jobId": jobId,
      "title": data['title'] ?? "Untitled",
      "description": data['description'] ?? "No description",
      "tag": data['category'] ?? "General",
      "price": "₱${data['budgetMin'] ?? 0} - ₱${data['budgetMax'] ?? 0}",
      "location": data['location'] ?? "Remote",
      "duration": data['duration'] ?? "3 days",
      "applicants": data['applicants'] ?? 0,
      "isUrgent": data['isUrgent'] ?? false,
      "status": data['status'] ?? "open",
      "posterId": data['postedBy'] ?? "",
      "rating": data['posterRating']?.toString() ?? "New",
      "posterName": data['posterName'] ?? "Employer",
      "posterPhoto": data['posterPhoto'],
      "postedBy": data['postedBy'],
      "hiredApplicantId": data['hiredApplicantId'],
    };

    return JobCard(
      job: jobMap,
      showStatus: true,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(job: jobMap, jobId: jobId),
          ),
        );
      },
    );
  }
}
