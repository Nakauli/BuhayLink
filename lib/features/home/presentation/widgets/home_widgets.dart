import 'package:flutter/material.dart';

/// Toggle Button for "Find Jobs" vs "My Posts"
class ModeToggleButton extends StatelessWidget {
  final String text;
  final bool isActive;
  final VoidCallback onTap;

  const ModeToggleButton({
    super.key,
    required this.text,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
}

/// Filter Chip (Nearby, Urgent, High Pay)
class FilterChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF2E7EFF), Color(0xFF9C27B0)],
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
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

/// Pagination Controls at the bottom of the list
class PaginationControls extends StatelessWidget {
  final int currentPage;
  final bool hasNextPage;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.hasNextPage,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: currentPage > 1 ? onPrev : null,
            icon: const Icon(Icons.arrow_back_ios_rounded),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Page $currentPage",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: hasNextPage ? onNext : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded),
          ),
        ],
      ),
    );
  }
}

/// Empty State Display
class EmptyStateWidget extends StatelessWidget {
  final bool showMyPosts;
  const EmptyStateWidget({super.key, required this.showMyPosts});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            showMyPosts ? "You haven't posted any jobs." : "No jobs found.",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
