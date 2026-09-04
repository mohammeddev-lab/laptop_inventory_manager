import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.index,
  });

  final String label;
  final String value;
  final Color accent;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isPrimary = accent == AppColors.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 450 + index * 120),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.largeAll,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPrimary ? AppColors.surface : AppColors.lightBlue,
                borderRadius: AppRadius.mediumAll,
              ),
              alignment: Alignment.center,
              child: Text(
                value,
                style: TextStyle(
                  color: isPrimary ? AppColors.primary : AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: isPrimary ? AppColors.surface : AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
