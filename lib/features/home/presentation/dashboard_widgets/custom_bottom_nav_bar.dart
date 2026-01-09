import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Custom Bottom Navigation Bar
///
/// SOLID: Single Responsibility
/// Handles rendering tabs and listening to badge counts.
class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final bool showMyPosts;
  final Function(int) onTabSelected;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.showMyPosts,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              // Home Tab with Badge Logic
              _BadgeStreamWrapper(
                collection: 'notifications',
                filterField: 'recipientId',
                filterValue: [FirebaseAuth.instance.currentUser?.uid, 'all'],
                shouldCount: (data) {
                  final type = data['type'];
                  return (type == 'job_post' || type == 'new_post') &&
                      data['read'] == false;
                },
                child: (hasBadge) => _NavBarItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: "Home",
                  isSelected: selectedIndex == 0,
                  showBadge: hasBadge,
                  onTap: onTabSelected,
                ),
              ),
              // Search Tab
              _NavBarItem(
                index: 1,
                icon: Icons.search_rounded,
                label: "Search",
                isSelected: selectedIndex == 1,
                onTap: onTabSelected,
              ),
              // Middle Button (Context Aware)
              _MiddleNavBarItem(
                index: 2,
                icon: showMyPosts
                    ? Icons.add_rounded
                    : Icons.assignment_rounded,
                label: showMyPosts ? "Post" : "Applied",
                isSelected: selectedIndex == 2,
                onTap: onTabSelected,
              ),
              // Chat Tab
              _BadgeStreamWrapper(
                collection: 'chats',
                filterField: 'users',
                filterValue: FirebaseAuth.instance.currentUser?.uid,
                isArrayContains: true,
                shouldCount: (data) {
                  return data['lastSenderId'] !=
                          FirebaseAuth.instance.currentUser?.uid &&
                      data['isRead'] == false;
                },
                child: (hasBadge) => _NavBarItem(
                  index: 3,
                  icon: Icons.chat_bubble_rounded,
                  label: "Chat",
                  isSelected: selectedIndex == 3,
                  showBadge: hasBadge,
                  onTap: onTabSelected,
                ),
              ),
              // Profile Tab
              _BadgeStreamWrapper(
                collection: 'notifications',
                filterField: 'recipientId',
                filterValue: FirebaseAuth.instance.currentUser?.uid,
                shouldCount: (data) {
                  final type = data['type'];
                  return (type != 'job_post' && type != 'new_post') &&
                      data['read'] == false;
                },
                child: (hasBadge) => _NavBarItem(
                  index: 4,
                  icon: Icons.person_rounded,
                  label: "Profile",
                  isSelected: selectedIndex == 4,
                  showBadge: hasBadge,
                  onTap: onTabSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- HELPER WIDGETS (Private to this file) ---

class _NavBarItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool showBadge;
  final Function(int) onTap;

  const _NavBarItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    this.showBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF2E7EFF)
                      : Colors.grey[400],
                  size: 26,
                ),
                if (showBadge && !isSelected)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
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
}

class _MiddleNavBarItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final Function(int) onTap;

  const _MiddleNavBarItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
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

// GENERIC STREAM WRAPPER
// SOLID: Open/Closed Principle - This wrapper handles any collection type
// without changing the core UI logic.
class _BadgeStreamWrapper extends StatelessWidget {
  final String collection;
  final String filterField;
  final dynamic filterValue;
  final bool isArrayContains;
  final bool Function(Map<String, dynamic>) shouldCount;
  final Widget Function(bool) child;

  const _BadgeStreamWrapper({
    required this.collection,
    required this.filterField,
    required this.filterValue,
    required this.shouldCount,
    required this.child,
    this.isArrayContains = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filterValue == null) return child(false);

    Query query = FirebaseFirestore.instance.collection(collection);

    if (isArrayContains) {
      query = query.where(filterField, arrayContains: filterValue);
    } else if (filterValue is List) {
      query = query.where(filterField, whereIn: filterValue);
    } else {
      query = query.where(filterField, isEqualTo: filterValue);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            if (shouldCount(doc.data() as Map<String, dynamic>)) {
              count++;
            }
          }
        }
        return child(count > 0);
      },
    );
  }
}
