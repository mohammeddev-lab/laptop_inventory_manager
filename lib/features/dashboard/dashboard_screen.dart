import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'header_widget.dart';
import 'stat_card_widget.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen(this.repo, {super.key});

  final dynamic repo;

  @override
  Widget build(BuildContext context) {
    final statCards = [
      StatCard(
        label: 'إجمالي الحاسبات',
        value: '18',
        accent: const Color(0xff2d6df6),
        index: 0,
      ),
      StatCard(
        label: 'إجمالي الموديلات',
        value: '9',
        accent: const Color(0xffedf3ff),
        index: 1,
      ),
      StatCard(
        label: 'إجمالي الشركات',
        value: '5',
        accent: const Color(0xffedf3ff),
        index: 2,
      ),
      StatCard(
        label: 'الإضافات',
        value: '4',
        accent: const Color(0xffedf3ff),
        index: 3,
      ),
    ];

    final panels = [
      _ReportPanel(
        title: 'الجرد حسب الشركة',
        rows: const [
          _ReportRow(name: 'ThinkPad X1 Carbon', count: 10),
          _ReportRow(name: 'HP ProBook 450', count: 8),
          _ReportRow(name: 'Dell XPS 15', count: 3),
          _ReportRow(name: 'Asus ZenBook 14', count: 5),
        ],
      ),
      _ReportPanel(
        title: 'الجرد حسب المعالج',
        rows: const [
          _ReportRow(name: 'Intel Core i7', count: 12),
          _ReportRow(name: 'Ryzen 7', count: 9),
          _ReportRow(name: 'Intel Core i5', count: 7),
        ],
      ),
      _ReportPanel(
        title: 'الجرد حسب كرت الشاشة',
        rows: const [
          _ReportRow(name: 'RTX 4060', count: 5),
          _ReportRow(name: 'GTX 1650', count: 4),
          _ReportRow(name: 'Intel Iris Xe', count: 10),
        ],
      ),
      _ReportPanel(
        title: 'الجرد حسب الحجم',
        rows: const [
          _ReportRow(name: '15.6', count: 14),
          _ReportRow(name: '14', count: 9),
          _ReportRow(name: '13.3', count: 7),
        ],
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DashboardHeader(title: 'مكتب الشهد'),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => Row(
              children: statCards.asMap().entries.map((entry) {
                final index = entry.key;
                final card = entry.value;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: index < statCards.length - 1 ? AppSpacing.md : 0,
                    ),
                    child: card,
                  ),
                );
              }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Expanded(
              child: GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 1100 ? 2 : 1,
                mainAxisSpacing: AppSpacing.section,
                crossAxisSpacing: AppSpacing.section,
                childAspectRatio: 1.8,
                children: panels.asMap().entries.map((entry) {
                  final index = entry.key;
                  final panel = entry.value;
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 500 + index * 150),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: panel,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.title, required this.rows});

  final String title;
  final List<_ReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.largeAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTypography.cardTitle,
                ),
                Text(
                  '${rows.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.lightBlue,
                          borderRadius: AppRadius.smallAll,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: (row.count / 20).clamp(0.15, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: AppRadius.smallAll,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 28,
                      child: Text(
                        row.count.toString(),
                        textAlign: TextAlign.center,
                        style: AppTypography.tableHeader.copyWith(
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Text(
                        row.name,
                        textAlign: TextAlign.right,
                        style: AppTypography.tableBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow {
  const _ReportRow({required this.name, required this.count});

  final String name;
  final int count;
}
