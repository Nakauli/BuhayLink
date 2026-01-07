import 'package:flutter/material.dart';

class RateUserDialog extends StatefulWidget {
  final String targetUserId;
  final String jobId;
  final Function(double, String) onSubmit; // Callback

  const RateUserDialog({
    super.key,
    required this.targetUserId,
    required this.jobId,
    required this.onSubmit,
  });

  @override
  State<RateUserDialog> createState() => _RateUserDialogState();
}

class _RateUserDialogState extends State<RateUserDialog> {
  double _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Rate Experience"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("How was working with this person?"),
          const SizedBox(height: 20),

          // --- STAR RATING ROW (FIXED) ---
          // Wrapped in FittedBox to prevent "Right overflowed" error
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: () {
                    setState(() => _rating = index + 1.0);
                  },
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 20),

          // --- REVIEW TEXT FIELD ---
          TextField(
            controller: _reviewController,
            decoration: const InputDecoration(
              hintText: "Write a review (optional)...",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: (_rating == 0 || _isSubmitting)
              ? null
              : () async {
                  setState(() => _isSubmitting = true);
                  // Call the submit function passed from parent
                  await widget.onSubmit(_rating, _reviewController.text);
                  if (mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7EFF),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : const Text("Submit"),
        ),
      ],
    );
  }
}
