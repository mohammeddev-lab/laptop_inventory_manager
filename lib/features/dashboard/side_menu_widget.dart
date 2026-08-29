import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class SideMenuWidget extends StatelessWidget {
  const SideMenuWidget({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (Icons.grid_view_rounded, 'لوحة التحكم'),
      (Icons.inventory_2_outlined, 'الجرد'),
      (Icons.bar_chart_outlined, 'التقارير'),
      (Icons.settings_outlined, 'الإعدادات'),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 228,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(left: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Text(
              'مكتب الشهد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ...List.generate(destinations.length, (index) {
              final item = destinations[index];
              final isSelected = index == selected;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: AppRadius.mediumAll,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: AppRadius.mediumAll,
                      onTap: () => onSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              item.$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.surface
                                    : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              item.$1,
                              color: isSelected
                                  ? AppColors.surface
                                  : AppColors.primary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text('تحديث البيانات', style: AppTypography.caption),
            ),
          ],
        ),
      ),
    );
  }
}
