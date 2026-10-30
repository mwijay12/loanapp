import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../motion/motion.dart';
import '../motion/motion_widgets.dart';

class LoadingState extends StatelessWidget {
  final String? message;

  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Entrance(
        // A brief fade, not a rise: this widget is a promise that data is coming, and
        // an entrance animation on a placeholder invites the eye to wait for it.
        duration: Motion.state,
        rise: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primaryColor),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
