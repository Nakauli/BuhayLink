import 'dart:async'; // Needed for the animation timer
import 'package:buhay_link/widgets/notification_badge.dart';
import 'package:buhay_link/features/jobs/data/repositories/dashboard_repository.dart';
import 'package:buhay_link/widgets/job_card.dart';
import 'package:buhay_link/widgets/stat_card.dart';
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
import 'hired_jobs_page.dart';
import 'saved_jobs_page.dart';
import 'my_posted_jobs_page.dart';
import 'public_profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // 1. Initialize Repository
  final _repository = DashboardRepository();

  int _selectedIndex = 0;
  bool _showMyPosts = false;
  String _selectedFilter = "All";
  String _searchQuery = "";

  // Navigation History Stack
  final List<int> _navigationHistory = [0];

  // --- HELPER: Mark specific notification types as read ---
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
      print("Error marking as read: $e");
    }
  }

  // Custom Tab Switch Logic
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

        // FIX: Changed to false. This prevents content from scrolling BEHIND the navbar.
        extendBody: false,

        body: _selectedIndex == 0 ? _buildHomeWithHeader() : _getBodyContent(),

        // ---------------------------------------------------------
        // FLOATING ISLAND NAVIGATION BAR
        // ---------------------------------------------------------
        bottomNavigationBar: Container(
          // FIX: Added background color to block scrolling text
          color: Colors.grey[50],
          child: SafeArea(
            child: Container(
              height: 70,
              // FIX: Adjusted margin to sit nicely in the solid block
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

                  // Special Middle Button
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
  // UI HELPER: Standard Nav Item
  // ---------------------------------------------------------
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

  // ---------------------------------------------------------
  // UI HELPER: Middle "Epic" Button
  // ---------------------------------------------------------
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

  // ---------------------------------------------------------
  // HOME CONTENT
  // ---------------------------------------------------------
  Widget _buildHomeWithHeader() {
    return Column(
      children: [
        // A. ISOLATED ALIVE HEADER
        _AnimatedHeader(
          repository: _repository,
          showMyPosts: _showMyPosts,
          onToggleView: (bool isMyPosts) {
            setState(() {
              _showMyPosts = isMyPosts;
              _selectedFilter = "All";
              _searchQuery = "";
            });
          },
          onMarkRead: _markAsRead,
        ),

        // B. SEARCH BAR
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: TextField(
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: _showMyPosts
                  ? "Search my posts..."
                  : "Search for jobs...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF2E7EFF)),
              ),
            ),
          ),
        ),

        // C. IMPROVED UI FILTERS
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

        // D. JOB LIST STREAM
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _showMyPosts
                ? _repository.getMyPostsStream()
                : _repository.getAllJobsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    _showMyPosts
                        ? "You haven't posted any jobs."
                        : "No jobs found.",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              var docs = snapshot.data!.docs;
              final currentUid = FirebaseAuth.instance.currentUser?.uid;

              if (!_showMyPosts && currentUid != null) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['postedBy'] != currentUid;
                }).toList();
              }

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['title'] ?? "")
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      (data['category'] ?? "")
                          .toString()
                          .toLowerCase()
                          .contains(_searchQuery);
                }).toList();
              }

              if (!_showMyPosts) {
                if (_selectedFilter == "Urgent") {
                  docs = docs
                      .where(
                        (doc) =>
                            (doc.data() as Map<String, dynamic>)['isUrgent'] ==
                            true,
                      )
                      .toList();
                } else if (_selectedFilter == "₱ High Pay") {
                  docs = docs
                      .where(
                        (doc) =>
                            ((doc.data()
                                    as Map<String, dynamic>)['budgetMax'] ??
                                0) >=
                            20000,
                      )
                      .toList();
                } else if (_selectedFilter == "Nearby") {
                  docs = docs
                      .where(
                        (doc) =>
                            (doc.data() as Map<String, dynamic>)['location']
                                .toString()
                                .toLowerCase()
                                .contains("santo tomas"),
                      )
                      .toList();
                }
              }

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    "No matches found.",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final doc = docs[index];
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
              );
            },
          ),
        ),
      ],
    );
  }

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

  // ---------------------------------------------------------
  // IMPROVED FILTER CHIP UI
  // ---------------------------------------------------------
  Widget _buildFilterChip(String label, {IconData? icon}) {
    bool isActive = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
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
}

// =========================================================================
// ISOLATED HEADER WIDGET
// =========================================================================
class _AnimatedHeader extends StatefulWidget {
  final DashboardRepository repository;
  final bool showMyPosts;
  final Function(bool) onToggleView;
  final Function(List<String>) onMarkRead;

  const _AnimatedHeader({
    required this.repository,
    required this.showMyPosts,
    required this.onToggleView,
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
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildToggleButton("Find Jobs", !widget.showMyPosts),
                ),
                Expanded(
                  child: _buildToggleButton("My Posts", widget.showMyPosts),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (widget.showMyPosts)
            StreamBuilder<QuerySnapshot>(
              stream: widget.repository.getMyPostsStream(),
              builder: (context, snapshot) {
                int active = 0;
                int hired = 0;
                int total = 0;
                if (snapshot.hasData) {
                  total = snapshot.data!.docs.length;
                  active = snapshot.data!.docs
                      .where((doc) => doc['status'] == 'open')
                      .length;
                  hired = snapshot.data!.docs
                      .where(
                        (doc) =>
                            doc['status'] == 'hired' ||
                            doc['status'] == 'closed',
                      )
                      .length;
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatCard(
                      value: active.toString(),
                      label: "Active",
                      icon: Icons.work_outline,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyPostedJobsPage(
                            title: "Active Jobs",
                            statusFilter: ['open'],
                          ),
                        ),
                      ),
                    ),
                    StatCard(
                      value: hired.toString(),
                      label: "Hired",
                      icon: Icons.handshake_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyPostedJobsPage(
                            title: "Hired History",
                            statusFilter: ['hired', 'closed'],
                          ),
                        ),
                      ),
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: widget.repository.getUserStatsStream(),
                      builder: (context, userSnapshot) {
                        String rating = "0.0";
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData =
                              userSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                          double r = (userData?['rating'] is num)
                              ? (userData?['rating'] as num).toDouble()
                              : 0.0;
                          rating = r.toStringAsFixed(1);
                        }
                        return StatCard(
                          value: rating,
                          label: "Ratings",
                          icon: Icons.star_rounded,
                          onTap: uid != null
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PublicProfilePage(
                                      userId: uid,
                                      userName: "Me",
                                    ),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                    StatCard(
                      value: total.toString(),
                      label: "Total Posts",
                      icon: Icons.list_alt_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MyPostedJobsPage(
                            title: "All Posts",
                            statusFilter: [],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            )
          else
            StreamBuilder<DocumentSnapshot>(
              stream: widget.repository.getUserStatsStream(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final String appliedCount =
                    data?['appliedCount']?.toString() ?? "0";
                final String savedCount =
                    data?['savedCount']?.toString() ?? "0";
                final String hiredCount =
                    data?['hiredCompleted']?.toString() ?? "0";
                double rating = (data?['rating'] is num)
                    ? (data?['rating'] as num).toDouble()
                    : 0.0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatCard(
                      value: appliedCount,
                      label: "Applied",
                      icon: Icons.assignment_turned_in_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppliedJobsPage(),
                        ),
                      ),
                    ),
                    StatCard(
                      value: hiredCount,
                      label: "Hired",
                      icon: Icons.check_circle_outline,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HiredJobsPage(),
                        ),
                      ),
                    ),
                    StatCard(
                      value: rating.toStringAsFixed(1),
                      label: "Ratings",
                      icon: Icons.star_rounded,
                      onTap: uid != null
                          ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PublicProfilePage(
                                  userId: uid,
                                  userName: "Me",
                                ),
                              ),
                            )
                          : null,
                    ),
                    StatCard(
                      value: savedCount,
                      label: "Saved",
                      icon: Icons.bookmark_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedJobsPage(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isActive) {
    return GestureDetector(
      onTap: () => widget.onToggleView(text == "My Posts"),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? const Color(0xFF2E7EFF) : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
