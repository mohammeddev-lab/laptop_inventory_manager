import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../inventory/data/inventory_repository.dart';
import 'header_widget.dart';
import 'stat_card_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen(this.repo, {super.key});

  final InventoryRepository repo;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final currentSession = widget.repo.currentSession();
    final summary = widget.repo.summary(sessionId: currentSession?.id);
    final companyReport = widget.repo.report('b.name', sessionId: currentSession?.id);
    final cpuReport = widget.repo.report('c.name', sessionId: currentSession?.id);
    final gpuReport = widget.repo.report('g.name', sessionId: currentSession?.id);
    final screenReport = widget.repo.report('s.name', sessionId: currentSession?.id);
    final sessions = widget.repo.listSessions();
    final completedSessions = sessions.where((s) => s.status == 'مكتمل').length;

    final statCards = [
      StatCard(
        label: 'إجمالي الحاسبات',
        value: '${summary.totalQuantity}',
        accent: AppColors.primary,
        index: 0,
      ),
      StatCard(
        label: 'عدد الموديلات',
        value: '${summary.modelCount}',
        accent: AppColors.lightBlue,
        index: 1,
      ),
      StatCard(
        label: 'عدد الشركات',
        value: '${summary.companyCount}',
        accent: AppColors.lightBlue,
        index: 2,
      ),
      StatCard(
        label: 'اكتملت الجرود',
        value: '$completedSessions',
        accent: AppColors.lightBlue,
        index: 3,
      ),
    ];

    final panels = [
      _ReportPanel(
        title: 'الجرد حسب الشركة',
        rows: companyReport
            .map((r) => _ReportRow(
                name: r['name'] as String, count: (r['quantity'] as int?) ?? 0))
            .toList(),
      ),
      _ReportPanel(
        title: 'الجرد حسب المعالج',
        rows: cpuReport
            .map((r) => _ReportRow(
                name: r['name'] as String, count: (r['quantity'] as int?) ?? 0))
            .toList(),
      ),
      _ReportPanel(
        title: 'الجرد حسب كرت الشاشة',
        rows: gpuReport
            .map((r) => _ReportRow(
                name: r['name'] as String, count: (r['quantity'] as int?) ?? 0))
            .toList(),
      ),
      _ReportPanel(
        title: 'الجرد حسب حجم الشاشة',
        rows: screenReport
            .map((r) => _ReportRow(
                name: r['name'] as String, count: (r['quantity'] as int?) ?? 0))
            .toList(),
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DashboardHeader(title: 'لوحة التحكم${currentSession != null ? ' — ${currentSession.name}' : ''}'),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => Row(
                children: statCards.asMap().entries.map((entry) {
                  final index = entry.key;
                  final card = entry.value;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: index < statCards.length - 1 ? AppSpacing.md : 0,
                      ),
                      child: card,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            Expanded(
              child: panels.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد بيانات جرد حالياً',
                        style: TextStyle(color: AppColors.secondary, fontSize: 14),
                      ),
                    )
                  : GridView.count(
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
              children: [
                Text(title, style: AppTypography.cardTitle),
                const SizedBox(width: 8),
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
                      flex: 2,
                      child: Text(
                        row.name,
                        textAlign: TextAlign.right,
                        style: AppTypography.tableBody,
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
