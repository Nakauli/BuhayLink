import 'dart:async';
import 'package:buhay_link/widgets/notification_badge.dart';
import 'package:buhay_link/features/jobs/data/repositories/dashboard_repository.dart';
import 'package:buhay_link/widgets/job_card.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTS ---
import 'add_job_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';
import 'search_page.dart';
import 'notifications_page.dart';
import 'job_details_page.dart';
import 'applied_jobs_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _repository = DashboardRepository();

  int _selectedIndex = 0;
  final List<int> _navigationHistory = [0];

  // --- PAGINATION STATE ---
  final int _jobsPerPage = 20; // Changed to 20 as requested
  List<DocumentSnapshot> _jobs = [];
  bool _isJobsLoading = false;

  // Page Tracking
  int _currentPage = 1;
  // Stores the "startAfter" document for each page so we can go back accurately
  // Key: Page Number, Value: The DocumentSnapshot to start AFTER
  final Map<int, DocumentSnapshot?> _pageCursors = {1: null};
  bool _hasNextPage = true; // Assumes true until we fetch less than limit

  final ScrollController _scrollController = ScrollController();

  bool _showMyPosts = false;
  String _selectedFilter = "All";

  @override
  void initState() {
    super.initState();
    _fetchJobs(page: 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- CORE: FETCH JOBS BY PAGE ---
  Future<void> _fetchJobs({required int page}) async {
    setState(() {
      _isJobsLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      Query query = FirebaseFirestore.instance
          .collection('jobs')
          .orderBy('postedAt', descending: true);

      if (_showMyPosts && user != null) {
        query = query.where('postedBy', isEqualTo: user.uid);
      }

      // Get the cursor for this specific page
      DocumentSnapshot? startAfterDoc = _pageCursors[page];

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      // Fetch 1 extra item to check if a "Next Page" exists, then remove it from display
      QuerySnapshot snapshot = await query.limit(_jobsPerPage).get();

      if (snapshot.docs.isNotEmpty) {
        var newJobs = snapshot.docs;

        // Client-Side Filtering (Hide My Posts in "Find Jobs")
        if (!_showMyPosts && user != null) {
          newJobs = newJobs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['postedBy'] != user.uid;
          }).toList();
        }

        // Quick Filters
        if (!_showMyPosts) {
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

        setState(() {
          _jobs = newJobs;
          _currentPage = page;

          // Determine if Next Page is possible
          // If we got full limit, we assume there might be more
          _hasNextPage = snapshot.docs.length == _jobsPerPage;

          // Save the cursor for the NEXT page (Page + 1)
          if (snapshot.docs.isNotEmpty) {
            _pageCursors[page + 1] = snapshot.docs.last;
          }
        });

        // Scroll to top when page changes
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } else {
        setState(() {
          _jobs = [];
          _hasNextPage = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isJobsLoading = false;
        });
      }
    }
  }

  void _nextPage() {
    if (_hasNextPage) {
      _fetchJobs(page: _currentPage + 1);
    }
  }

  void _prevPage() {
    if (_currentPage > 1) {
      _fetchJobs(page: _currentPage - 1);
    }
  }

  // ... (Keep existing helpers: _markAsRead, _onTabTapped, _buildNavBarItem, etc.) ...
  Future<void> _markAsRead(List<String> types) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', whereIn: [uid, 'all'])
          .where('read', isEqualTo: false)
          .get();
      final docsToUpdate = snapshot.docs.where((doc) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        return types.contains(type);
      }).toList();
      if (docsToUpdate.isEmpty) return;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in docsToUpdate) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      _navigationHistory.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _navigationHistory.length <= 1,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() {
          _navigationHistory.removeLast();
          _selectedIndex = _navigationHistory.last;
        });
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        extendBody: false,
        body: _selectedIndex == 0 ? _buildHomeWithHeader() : _getBodyContent(),
        bottomNavigationBar: Container(
          color: Colors.grey[50],
          child: SafeArea(
            child: Container(
              height: 70,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavBarItem(0, Icons.home_rounded, "Home"),
                  _buildNavBarItem(1, Icons.search_rounded, "Search"),
                  _buildMiddleNavBarItem(
                    2,
                    _showMyPosts ? Icons.add_rounded : Icons.assignment_rounded,
                    _showMyPosts ? "Post" : "Applied",
                  ),
                  _buildNavBarItem(3, Icons.chat_bubble_rounded, "Chat"),
                  _buildNavBarItem(4, Icons.person_rounded, "Profile"),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // HOME CONTENT
  // ---------------------------------------------------------
  Widget _buildHomeWithHeader() {
    return Column(
      children: [
        _AnimatedHeader(
          repository: _repository,
          showMyPosts: _showMyPosts,
          onMarkRead: _markAsRead,
        ),
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
                Expanded(child: _buildToggleButton("Find Jobs", !_showMyPosts)),
                Expanded(child: _buildToggleButton("My Posts", _showMyPosts)),
              ],
            ),
          ),
        ),
        if (!_showMyPosts)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              children: [
                _buildFilterChip("All", icon: Icons.grid_view_rounded),
                const SizedBox(width: 12),
                _buildFilterChip("Nearby", icon: Icons.near_me_rounded),
                const SizedBox(width: 12),
                _buildFilterChip("Urgent", icon: Icons.timer_rounded),
                const SizedBox(width: 12),
                _buildFilterChip(
                  "₱ High Pay",
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        // --- JOB LIST ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Reset pagination on pull-to-refresh
              _pageCursors.clear();
              _pageCursors[1] = null;
              await _fetchJobs(page: 1);
            },
            child: _isJobsLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 60,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showMyPosts
                              ? "You haven't posted any jobs."
                              : "No jobs found.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                    // Add +1 for the Pagination Controls at the bottom
                    itemCount: _jobs.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      // --- PAGINATION CONTROLS (At Bottom) ---
                      if (index == _jobs.length) {
                        // Don't show controls if list is empty or very short and no next page
                        if (_jobs.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // LEFT ARROW (Previous)
                              IconButton(
                                onPressed: _currentPage > 1 ? _prevPage : null,
                                icon: const Icon(Icons.arrow_back_ios_rounded),
                                color: _currentPage > 1
                                    ? const Color(0xFF2E7EFF)
                                    : Colors.grey[300],
                              ),

                              const SizedBox(width: 20),

                              // PAGE NUMBER
                              Text(
                                "Page $_currentPage",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(width: 20),

                              // RIGHT ARROW (Next)
                              IconButton(
                                onPressed: _hasNextPage ? _nextPage : null,
                                icon: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                ),
                                color: _hasNextPage
                                    ? const Color(0xFF2E7EFF)
                                    : Colors.grey[300],
                              ),
                            ],
                          ),
                        );
                      }

                      // --- JOB CARD ---
                      final doc = _jobs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final String jobId = doc.id;

                      final Map<String, dynamic> jobMap = {
                        "jobId": jobId,
                        "title": data['title'] ?? "Untitled",
                        "description": data['description'] ?? "No description",
                        "tag": data['category'] ?? "General",
                        "price":
                            "₱${data['budgetMin'] ?? 0} - ₱${data['budgetMax'] ?? 0}",
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
                              builder: (context) =>
                                  JobDetailsPage(job: jobMap, jobId: jobId),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ... (Rest of existing methods unchanged: _getBodyContent, _buildFilterChip, _buildToggleButton, _buildNavBarItem, _buildMiddleNavBarItem, _AnimatedHeader) ...

  Widget _getBodyContent() {
    switch (_selectedIndex) {
      case 1:
        return SearchPage(isEmployerMode: _showMyPosts);
      case 2:
        return _showMyPosts
            ? const AddJobPage(showBackButton: false)
            : const AppliedJobsPage(showBackButton: false);
      case 3:
        return const MessagesPage();
      case 4:
        return const ProfilePage();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildFilterChip(String label, {IconData? icon}) {
    bool isActive = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          // Reset to page 1 on filter change
          _pageCursors.clear();
          _pageCursors[1] = null;
          _fetchJobs(page: 1);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? const Color(0xFF2E7EFF).withOpacity(0.4)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: isActive ? 10 : 5,
              offset: const Offset(0, 4),
            ),
          ],
          border: isActive ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (text == "My Posts" && !_showMyPosts) {
          setState(() {
            _showMyPosts = true;
            _selectedFilter = "All";
            // Reset to page 1
            _pageCursors.clear();
            _pageCursors[1] = null;
            _fetchJobs(page: 1);
          });
        } else if (text == "Find Jobs" && _showMyPosts) {
          setState(() {
            _showMyPosts = false;
            _selectedFilter = "All";
            // Reset to page 1
            _pageCursors.clear();
            _pageCursors[1] = null;
            _fetchJobs(page: 1);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2E7EFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.identity()..scale(isSelected ? 1.1 : 1.0),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF2E7EFF) : Colors.grey[400],
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2E7EFF) : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiddleNavBarItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isSelected
                      ? [const Color(0xFF2E7EFF), const Color(0xFF9C27B0)]
                      : [
                          const Color(0xFF2E7EFF).withOpacity(0.8),
                          const Color(0xFF9C27B0).withOpacity(0.8),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7EFF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF9C27B0) : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHeader extends StatefulWidget {
  final DashboardRepository repository;
  final bool showMyPosts;
  final Function(List<String>) onMarkRead;

  const _AnimatedHeader({
    required this.repository,
    required this.showMyPosts,
    required this.onMarkRead,
  });

  @override
  State<_AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<_AnimatedHeader> {
  List<Color> _gradientColors = [
    const Color(0xFF2E7EFF),
    const Color(0xFF9C27B0),
  ];
  Alignment _beginAlignment = Alignment.topLeft;
  Alignment _endAlignment = Alignment.bottomRight;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          if (_beginAlignment == Alignment.topLeft) {
            _beginAlignment = Alignment.topRight;
            _endAlignment = Alignment.bottomLeft;
            _gradientColors = [
              const Color(0xFF9C27B0),
              const Color(0xFF2E7EFF),
            ];
          } else {
            _beginAlignment = Alignment.topLeft;
            _endAlignment = Alignment.bottomRight;
            _gradientColors = [
              const Color(0xFF2E7EFF),
              const Color(0xFF9C27B0),
            ];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final emailName = user?.email?.split('@')[0] ?? "Guest";

    return AnimatedContainer(
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.only(top: 50, left: 24, right: 24, bottom: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: _beginAlignment,
          end: _endAlignment,
          colors: _gradientColors,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7EFF).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome back,",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (uid != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: widget.repository.getUserStatsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data =
                          snapshot.data!.data() as Map<String, dynamic>?;
                      final String realName =
                          data?['fullName'] ??
                          data?['firstName'] ??
                          data?['username'] ??
                          emailName;
                      return Text(
                        realName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }
                    return Text(
                      emailName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                )
              else
                const Text(
                  "Guest",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          GestureDetector(
            onTap: () {
              if (widget.showMyPosts) {
                widget.onMarkRead(['application']);
              } else {
                widget.onMarkRead([
                  'new_post',
                  'post',
                  'job_post',
                  'created',
                  'hired',
                  'rejected',
                ]);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NotificationsPage(isEmployerMode: widget.showMyPosts),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: NotificationBadge(
                icon: Icons.notifications,
                color: Colors.white,
                isEmployerMode: widget.showMyPosts,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
