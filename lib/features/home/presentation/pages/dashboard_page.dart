import 'package:buhay_link/features/home/presentation/pages/applied_jobs_page.dart';
import 'package:buhay_link/widgets/custom_bottom_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- PAGE IMPORTS ---
import 'add_job_page.dart';
import 'profile_page.dart';
import 'messages_page.dart';
import 'search_page.dart';
import 'home_feed_page.dart';

// --- WIDGET IMPORTS ---

/// The Main Dashboard Controller.
///
/// SOLID Principle: Single Responsibility (SRP)
/// This widget is ONLY responsible for Top-Level Navigation.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // Navigation State
  int _selectedIndex = 0;
  final List<int> _navigationHistory = [0];

  // Shared state for the Middle Button (Post vs Applied) logic
  bool _showMyPosts = false;

  /// Handles Bottom Navigation Taps
  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;

    // Trigger side-effects (Marking read) here or delegate to a Controller
    if (index == 0) _markNotificationsAsRead(['job_post', 'new_post']);
    if (index == 3) _markChatsAsRead();

    setState(() {
      _selectedIndex = index;
      _navigationHistory.add(index);
    });
  }

  /// Toggles between "Find Jobs" and "My Posts" modes.
  /// Passed down to HomeFeedPage to update the UI state.
  void _toggleJobMode(bool showMyPosts) {
    setState(() {
      _showMyPosts = showMyPosts;
    });
  }

  // --- HELPER LOGIC (Can be moved to a Repository/Service later) ---

  /// Marks specific notification types as read in Firestore
  Future<void> _markNotificationsAsRead(List<String> types) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Batch update for performance
    final batch = FirebaseFirestore.instance.batch();
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', whereIn: [uid, 'all'])
        .where('read', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      if (types.contains(doc['type'])) {
        batch.update(doc.reference, {'read': true});
      }
    }
    await batch.commit();
  }

  /// Marks all messages in active chats as read
  Future<void> _markChatsAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('users', arrayContains: uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      // Only mark read if I was NOT the last sender
      if (doc['lastSenderId'] != uid) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope handles the Android "Back" button to go back through tabs
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

        // The Body switches based on index
        body: _getBodyContent(),

        // Extracted Bottom Navigation Bar
        bottomNavigationBar: CustomBottomNavBar(
          selectedIndex: _selectedIndex,
          showMyPosts: _showMyPosts,
          onTabSelected: _onTabTapped,
        ),
      ),
    );
  }

  /// Returns the widget for the current tab
  Widget _getBodyContent() {
    switch (_selectedIndex) {
      case 0:
        return HomeFeedPage(
          showMyPosts: _showMyPosts,
          onModeChanged: _toggleJobMode,
          onMarkRead: _markNotificationsAsRead,
        );
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
}
