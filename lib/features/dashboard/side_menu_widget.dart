import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

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
        width: 220,
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'مكتب الشهد',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            ...List.generate(destinations.length, (index) {
              final item = destinations[index];
              final isSelected = index == selected;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const SizedBox(width: 8),
                            Text(
                              item.$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              item.$1,
                              color: isSelected ? Colors.white : AppColors.primary,
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
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'تحديث البيانات',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
