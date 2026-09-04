import 'dart:io';

import 'package:excel/excel.dart' as excel_pkg;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/database/database_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_radius.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'core/validators/validators.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/side_menu_widget.dart';
import 'features/inventory/data/import_service.dart';
import 'features/inventory/data/inventory_repository.dart';

late final InventoryRepository repository;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await DatabaseService.open();
  repository = InventoryRepository(db);
  runApp(const ProviderScope(child: InventoryApp()));
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'نظام جرد الحاسبات المحمولة',
    theme: AppTheme.light(),
    builder: (context, child) => Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: Row(
      children: [
        SideMenuWidget(
          selected: selected,
          onSelected: (value) => setState(() => selected = value),
        ),
        Expanded(child: _screen()),
      ],
    ),
  );

  Widget _screen() => switch (selected) {
    0 => DashboardScreen(repository),
    1 => InventoryPage(repository),
    2 => ReportsPage(repository),
    _ => SettingsPage(repository),
  };
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.action,
  });
  final String title, description;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.page),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.right,
                    style: AppTypography.pageTitle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    description,
                    textAlign: TextAlign.right,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.md),
              action!,
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.section),
        Expanded(child: child),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      minimumSize: const Size(0, 44),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mediumAll),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 12),
        Text('جارٍ تحميل البيانات...'),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 52,
          color: AppColors.secondary,
        ),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, style: const TextStyle(color: AppColors.secondary)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class InventoryPage extends StatefulWidget {
  const InventoryPage(this.repo, {super.key});
  final InventoryRepository repo;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String query = '';
  int? sessionId;
  int? filterBrandId;
  int? filterModelId;
  int? filterCpuId;
  int? filterGpuId;
  int? filterScreenId;

  @override
  void initState() {
    super.initState();
    final active = widget.repo.currentSession();
    sessionId = active?.id;
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.repo.currentSession();
    final availableSessions = widget.repo.listSessions();
    final selectedSession = (sessionId != null)
        ? availableSessions.firstWhere(
            (s) => s.id == sessionId,
            orElse: () => current ?? availableSessions.first,
          )
        : current ?? availableSessions.firstOrNull;

    final items = widget.repo.list(
      search: query,
      sessionId: selectedSession?.id ?? current?.id,
      brandId: filterBrandId,
    );

    final filteredItems = items.where((item) {
      if (filterModelId != null && item.modelId != filterModelId) return false;
      if (filterCpuId != null && item.cpuId != filterCpuId) return false;
      if (filterGpuId != null) {
        final gpuModels = widget.repo.choices('gpu_models', gpuId: filterGpuId);
        final gpuModelIds = gpuModels.map((m) => m.id).toSet();
        if (!gpuModelIds.contains(item.gpuModelId)) return false;
      }
      if (filterScreenId != null && item.screenId != filterScreenId) return false;
      return true;
    }).toList();

    return PageFrame(
      title: 'الجرد',
      description: 'إدارة ومتابعة مخزون الحاسبات المحمولة',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'إضافة حاسبة',
            icon: Icons.add,
            onPressed: () => _openForm(),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _startNewSession,
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text('جرد جديد'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _exportCurrentSession,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('تصدير إلى Excel'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _importFromExcel,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('استيراد من Excel'),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('session-${selectedSession?.id ?? 0}'),
                    initialValue: selectedSession?.id,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الجرد الحالي',
                    ),
                    items: widget.repo.listSessions().map((session) {
                      final dateStr =
                          '${session.date.day}/${session.date.month}/${session.date.year}';
                      final statusIcon = session.status == 'جاري'
                          ? Icons.radio_button_checked
                          : Icons.check_circle_outline;
                      final statusColor = session.status == 'جاري'
                          ? AppColors.primary
                          : AppColors.success;
                      return DropdownMenuItem<int>(
                        value: session.id,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${session.name} — $dateStr — ${session.status}',
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => sessionId = value);
                    },
                  ),
                ),
                if (selectedSession != null &&
                    selectedSession.status == 'جاري') ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _finishSession(selectedSession.id),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: const Text('إنهاء الجرد'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SearchField(onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 12),
          InventoryFilters(
            repo: widget.repo,
            filterBrandId: filterBrandId,
            filterModelId: filterModelId,
            filterCpuId: filterCpuId,
            filterGpuId: filterGpuId,
            filterScreenId: filterScreenId,
            onBrandChanged: (v) => setState(() {
              filterBrandId = v;
              filterModelId = null;
            }),
            onModelChanged: (v) => setState(() => filterModelId = v),
            onCpuChanged: (v) => setState(() => filterCpuId = v),
            onGpuChanged: (v) => setState(() => filterGpuId = v),
            onScreenChanged: (v) => setState(() => filterScreenId = v),
            onClear: () => setState(() {
              filterBrandId = null;
              filterModelId = null;
              filterCpuId = null;
              filterGpuId = null;
              filterScreenId = null;
            }),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredItems.isEmpty
                ? EmptyState(
                    title: query.isEmpty && filterBrandId == null && filterModelId == null && filterCpuId == null && filterGpuId == null && filterScreenId == null
                        ? 'لا توجد حاسبات في هذا الجرد'
                        : 'لا توجد سجلات جرد مطابقة لعملية البحث الحالية.',
                    message: query.isEmpty && filterBrandId == null && filterModelId == null && filterCpuId == null && filterGpuId == null && filterScreenId == null
                        ? 'أضف أول حاسبة إلى الجرد الحالي.'
                        : 'غيّر عبارة البحث أو أعد تعيين الفلاتر.',
                    action: PrimaryButton(
                      label: 'إضافة حاسبة',
                      icon: Icons.add,
                      onPressed: () => _openForm(),
                    ),
                  )
                : InventoryTable(
                    items: filteredItems,
                    onEdit: (item) => _openForm(item),
                    onDelete: _confirmDelete,
                    onView: (item) => _showDetailsDialog(item),
                    isCompletedSession: selectedSession?.status == 'مكتمل',
                  ),
          ),
        ],
      ),
    );
  }

  void _startNewSession() async {
    final date = DateTime.now();
    final controller = TextEditingController(
      text: 'جرد ${date.day}/${date.month}/${date.year}',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('جرد جديد', textAlign: TextAlign.right),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'اسم الجرد'),
              ),
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                controller: TextEditingController(
                  text: '${date.day}/${date.month}/${date.year}',
                ),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'تاريخ الجرد'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'name': controller.text.trim(),
                'date': date,
              }),
              child: const Text('بدء الجرد'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final session = widget.repo.createSession(
      name: result['name'] as String?,
      date: result['date'] as DateTime,
    );
    if (!mounted) return;
    setState(() => sessionId = session.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('تم إنشاء ${session.name} بنجاح')));
  }

  Future<void> _exportCurrentSession() async {
    final selectedSess = widget.repo.listSessions().firstWhere(
      (s) => s.id == sessionId,
      orElse: () => widget.repo.currentSession() ?? widget.repo.listSessions().first,
    );
    final messenger = ScaffoldMessenger.maybeOf(context);

    final rows = widget.repo.list(sessionId: selectedSess.id);
    final excel = excel_pkg.Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()!]!;
    final header = [
      'تسلسل',
      'الشركة',
      'الموديل',
      'المعالج',
      'كرت الشاشة',
      'حجم الشاشة',
      'اللمس',
      '2 في 1',
      'الكمية',
      'الحالة',
      'العطل / الملاحظات',
    ];
    for (var i = 0; i < header.length; i++) {
      sheet
          .cell(
            excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          )
          .value = excel_pkg.TextCellValue(header[i]);
    }
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final item = rows[rowIndex];
      final status = item.quantity > 0 ? 'مطابق' : 'غير مطابق';
      final values = [
        rowIndex + 1,
        item.brand,
        item.model,
        item.cpu,
        item.gpu,
        item.screen,
        item.touch ? 'نعم' : 'لا',
        item.convertible ? 'نعم' : 'لا',
        item.quantity,
        status,
        item.notes,
      ];
      for (var colIndex = 0; colIndex < values.length; colIndex++) {
        final value = values[colIndex];
        if (value is int) {
          sheet
              .cell(
                excel_pkg.CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex + 1,
                ),
              )
              .value = excel_pkg.IntCellValue(value);
        } else {
          sheet
              .cell(
                excel_pkg.CellIndex.indexByColumnRow(
                  columnIndex: colIndex,
                  rowIndex: rowIndex + 1,
                ),
              )
              .value = excel_pkg.TextCellValue(value.toString());
        }
      }
    }

    final fileName =
        'inventory_${selectedSess.date.year}-${selectedSess.date.month.toString().padLeft(2, '0')}-${selectedSess.date.day.toString().padLeft(2, '0')}.xlsx';
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    final bytes = excel.encode();
    if (bytes == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('تعذر إنشاء ملف Excel')),
      );
      return;
    }
    await file.writeAsBytes(bytes);
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(content: Text('تم تصدير الجرد إلى $fileName')),
    );
  }

  Future<void> _importFromExcel() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      final importService = ImportService(widget.repo);
      final preview = await importService.preview(filePath);

      if (!mounted) return;

      if (preview.hasErrors) {
        _showImportPreviewDialog(preview, importService);
      } else if (preview.rows.isEmpty) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على بيانات في الملف')),
        );
      } else {
        _showImportConfirmDialog(preview, importService);
      }
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('خطأ في استيراد الملف: $e')),
      );
    }
  }

  void _showImportPreviewDialog(ImportPreview preview, ImportService importService) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('معاينة الاستيراد'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('عدد الصفوف: ${preview.totalRows}'),
                const SizedBox(height: 8),
                Text(
                  'الأخطاء: ${preview.errors.length}',
                  style: TextStyle(
                    color: preview.errors.isNotEmpty ? AppColors.error : null,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: preview.errors.length,
                    itemBuilder: (context, index) {
                      final error = preview.errors[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.error,
                          child: Text(
                            '${error.row}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(error.column),
                        subtitle: Text(error.message),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            if (preview.rows.isNotEmpty)
              PrimaryButton(
                label: 'استيراد ${preview.rows.length} صفوف صحيحة',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showImportConfirmDialog(preview, importService);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showImportConfirmDialog(ImportPreview preview, ImportService importService) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد الاستيراد'),
          content: Text('هل تريد استيراد ${preview.rows.length} صف إلى الجرد الحالي؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            PrimaryButton(
              label: 'استيراد',
              onPressed: () {
                Navigator.pop(dialogContext);
                try {
                  final imported = importService.commit(preview, sessionId: sessionId);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم استيراد $imported سجل بنجاح')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في الاستيراد: $e')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _finishSession(int id) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إنهاء الجرد', textAlign: TextAlign.right),
          content: const Text(
            'هل أنت متأكد من إنهاء هذا الجرد؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () {
                widget.repo.finishSession(id);
                Navigator.pop(dialogContext);
                setState(() => sessionId = widget.repo.currentSession()?.id);
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => const _SuccessDialog(
                      title: 'تم إنهاء الجرد',
                      message: 'تم حفظ نتائج الجرد بنجاح',
                    ),
                  );
                }
              },
              child: const Text('إنهاء الجرد'),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm([InventoryItem? item]) => showDialog(
    context: context,
    builder: (_) => InventoryForm(
      repo: widget.repo,
      item: item,
      sessionId: sessionId ?? widget.repo.currentSession()?.id,
      onSaved: () => setState(() {}),
    ),
  );
  void _showDetailsDialog(InventoryItem item) => showDialog(
    context: context,
    builder: (dialog) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogAll),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تفاصيل الحاسبة',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'معلومات ومواصفات الحاسبة',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialog),
                        icon: const Icon(Icons.close_rounded, color: AppColors.secondary),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 18),
                  _detailSection('معلومات الحاسبة', [
                    _detailRow('الشركة', item.brand),
                    _detailRow('الموديل', item.model),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('المعالج', [
                    _detailRow('نوع المعالج', item.cpu),
                    _detailRow('جيل المعالج', item.cpuGeneration ?? '—'),
                    _detailRow('فئة المعالج', item.cpuClass ?? '—'),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('الشاشة والكرت', [
                    _detailRow('كرت الشاشة', item.gpu),
                    _detailRow('حجم الشاشة', item.screen),
                    _detailRow('شاشة لمس', item.touch ? 'نعم' : 'لا'),
                    _detailRow('حاسبة 2 في 1', item.convertible ? 'نعم' : 'لا'),
                  ]),
                  const SizedBox(height: 16),
                  _detailSection('المخزون', [
                    _detailRow('الكمية', '${item.quantity}'),
                    _detailRow(
                      'الحالة',
                      item.quantity > 0 ? 'مطابق' : 'غير مطابق',
                      valueColor: item.quantity > 0 ? AppColors.success : AppColors.warning,
                    ),
                  ]),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _detailSection('الملاحظات', [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          item.notes,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: 120,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialog),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('إغلاق'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _detailSection(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      const SizedBox(height: 10),
      ...children,
    ],
  );

  Widget _detailRow(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  void _confirmDelete(InventoryItem item) => showDialog(
    context: context,
    builder: (dialog) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('حذف سجل الجرد؟', textAlign: TextAlign.right),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف سجل الجرد هذا؟\nلا يمكن التراجع عن هذا الإجراء.',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              widget.repo.delete(item.id);
              Navigator.pop(dialog);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حذف الحاسبة بنجاح')),
              );
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    ),
  );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textDirection: TextDirection.rtl,
    decoration: const InputDecoration(
      labelText: 'بحث',
      hintText: 'البحث عن الشركة أو الموديل أو المعالج أو كرت الشاشة...',
      prefixIcon: Icon(Icons.search),
    ),
  );
}

class InventoryFilters extends StatelessWidget {
  const InventoryFilters({
    super.key,
    required this.repo,
    this.filterBrandId,
    this.filterModelId,
    this.filterCpuId,
    this.filterGpuId,
    this.filterScreenId,
    this.onBrandChanged,
    this.onModelChanged,
    this.onCpuChanged,
    this.onGpuChanged,
    this.onScreenChanged,
    this.onClear,
  });

  final InventoryRepository repo;
  final int? filterBrandId;
  final int? filterModelId;
  final int? filterCpuId;
  final int? filterGpuId;
  final int? filterScreenId;
  final ValueChanged<int?>? onBrandChanged;
  final ValueChanged<int?>? onModelChanged;
  final ValueChanged<int?>? onCpuChanged;
  final ValueChanged<int?>? onGpuChanged;
  final ValueChanged<int?>? onScreenChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final brands = repo.choices('brands');
    final models = repo.choices('models', brandId: filterBrandId);
    final cpus = repo.choices('cpus');
    final gpus = repo.choices('gpus');
    final screens = repo.choices('screen_sizes');

    final hasFilters = filterBrandId != null || filterModelId != null || filterCpuId != null || filterGpuId != null || filterScreenId != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown(
              label: 'الشركة',
              items: brands,
              selectedId: filterBrandId,
              onChanged: onBrandChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown(
              label: 'الموديل',
              items: models,
              selectedId: filterModelId,
              onChanged: onModelChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown(
              label: 'المعالج',
              items: cpus,
              selectedId: filterCpuId,
              onChanged: onCpuChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown(
              label: 'كرت الشاشة',
              items: gpus,
              selectedId: filterGpuId,
              onChanged: onGpuChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown(
              label: 'حجم الشاشة',
              items: screens,
              selectedId: filterScreenId,
              onChanged: onScreenChanged,
            ),
          ),
          if (hasFilters) ...[
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'مسح الفلاتر',
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 20, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.items,
    this.selectedId,
    this.onChanged,
  });

  final String label;
  final List<Choice> items;
  final int? selectedId;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final allLabel = 'جميع ${label == 'الشركة' ? 'الشركات' : label == 'الموديل' ? 'الموديلات' : label == 'المعالج' ? 'المعالجات' : label == 'كرت الشاشة' ? 'كروت الشاشة' : 'الأحجام'}';

    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      isExpanded: true,
      alignment: AlignmentDirectional.centerStart,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
      dropdownColor: AppColors.surface,
      menuMaxHeight: 220,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
        constraints: const BoxConstraints(minHeight: 42, maxHeight: 46),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      selectedItemBuilder: (context) {
        final displayText = selectedId == null
            ? allLabel
            : items.firstWhere((i) => i.id == selectedId, orElse: () => Choice(0, allLabel)).name;
        Widget buildItem(String text) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
        return [
          buildItem(displayText),
          ...items.map((i) => buildItem(i.name)),
        ];
      },
      items: [
        DropdownMenuItem<int>(
          value: null,
          alignment: AlignmentDirectional.centerStart,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              allLabel,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
        ...items.map((item) => DropdownMenuItem<int>(
          value: item.id,
          alignment: AlignmentDirectional.centerStart,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              item.name,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        )),
      ],
      onChanged: onChanged,
    );
  }
}

class InventoryTable extends StatelessWidget {
  const InventoryTable({
    super.key,
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
    this.isCompletedSession = false,
  });

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onEdit, onDelete, onView;
  final bool isCompletedSession;

  static const _columnHeaders = [
    'تسلسل',
    'الشركة',
    'الموديل',
    'المعالج',
    'كرت الشاشة',
    'حجم الشاشة',
    'لمس',
    '2 في 1',
    'الكمية',
    'الحالة',
    'الإجراءات',
  ];

  static const _minColumnWidths = [
    55.0,
    90.0,
    90.0,
    90.0,
    100.0,
    90.0,
    60.0,
    65.0,
    70.0,
    80.0,
    85.0,
  ];

  static const _flexWeights = [
    0,
    2,
    2,
    2,
    2,
    1,
    0,
    0,
    1,
    1,
    1,
  ];

  List<double> _computeColumnWidths(double availableWidth) {
    final horizontalMargin = 24.0;
    final columnSpacing = 10.0 * (_columnHeaders.length - 1);
    final usableWidth = availableWidth - horizontalMargin - columnSpacing;
    final totalMinWidth = _minColumnWidths.reduce((a, b) => a + b);
    final totalFlex = _flexWeights.fold(0, (a, b) => a + b);
    final extraSpace = usableWidth - totalMinWidth;
    if (extraSpace <= 0 || totalFlex == 0) {
      return List<double>.from(_minColumnWidths);
    }
    final flexUnit = extraSpace / totalFlex;
    return List<double>.generate(_columnHeaders.length, (i) {
      return _minColumnWidths[i] + _flexWeights[i] * flexUnit;
    });
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: Theme.of(context).copyWith(
            dataTableTheme: Theme.of(context).dataTableTheme.copyWith(
              headingTextStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12.5,
                color: AppColors.text,
              ),
              headingRowColor: const WidgetStatePropertyAll(
                AppColors.surfaceMuted,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final columnWidths = _computeColumnWidths(availableWidth);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: availableWidth,
                  child: DataTable(
                    columnSpacing: 10,
                    horizontalMargin: 12,
                    headingRowHeight: 46,
                    dataRowMinHeight: 54,
                    dataRowMaxHeight: 58,
                    dividerThickness: 1,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: AppColors.border),
                      verticalInside: BorderSide(
                        color: AppColors.border.withAlpha(120),
                      ),
                      top: BorderSide(color: AppColors.border),
                      left: BorderSide(color: AppColors.border),
                      right: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                    columns: [
                      for (var i = 0; i < _columnHeaders.length; i++)
                        DataColumn(
                          label: SizedBox(
                            width: columnWidths[i],
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                _columnHeaders[i],
                                textAlign: i == _columnHeaders.length - 1
                                    ? TextAlign.left
                                    : TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                    ],
                rows: items
                    .asMap()
                    .entries
                    .map(
                      (entry) => DataRow(
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppColors.lightBlue.withAlpha(80);
                          }
                          return Colors.white;
                        }),
                        cells: [
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          _textCell(entry.value.brand),
                          _textCell(entry.value.model),
                          _textCell(entry.value.cpu),
                          _textCell(entry.value.gpu),
                          _textCell(entry.value.screen),
                          _textCell(entry.value.touch ? 'نعم' : 'لا'),
                          _textCell(entry.value.convertible ? 'نعم' : 'لا'),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.lightBlue,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  '${entry.value.quantity}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: entry.value.quantity > 0
                                      ? AppColors.successLight
                                      : AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  entry.value.quantity > 0 ? 'مطابق' : 'غير مطابق',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: entry.value.quantity > 0
                                        ? AppColors.success
                                        : AppColors.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: isCompletedSession
                                  ? const Icon(
                                      Icons.lock_outline,
                                      size: 16,
                                      color: AppColors.secondary,
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'عرض التفاصيل',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          onPressed: () => onView(entry.value),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          tooltip: 'تعديل',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          onPressed: () => onEdit(entry.value),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          tooltip: 'حذف',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () => onDelete(entry.value),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );

  DataCell _textCell(String text) => DataCell(
    Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(text),
    ),
  );
}

List<Choice> filterModelChoicesByCpu(
  List<Choice> base, {
  String? generation,
  String? family,
}) {
  final g = (generation ?? '').trim().toLowerCase();
  final f = (family ?? '').trim().toLowerCase();

  if (g.isEmpty && f.isEmpty) return base;

  final filtered = base.where((entry) {
    final text = entry.name.toLowerCase();
    final matchesGeneration = g.isEmpty || text.contains(g);
    final matchesFamily = f.isEmpty || text.contains(f);
    return matchesGeneration && matchesFamily;
  }).toList();

  return filtered.isEmpty ? base : filtered;
}

class InventoryForm extends StatefulWidget {
  const InventoryForm({
    super.key,
    required this.repo,
    required this.onSaved,
    this.item,
    this.sessionId,
  });
  final InventoryRepository repo;
  final InventoryItem? item;
  final int? sessionId;
  final VoidCallback onSaved;
  @override
  State<InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<InventoryForm> {
  late int? brand, model, cpu, gpu, screen;
  int? gpuCategory;
  int? cpuGenerationId, cpuClassId;
  late bool touch, twoInOne;
  late final TextEditingController quantity, notes;
  String? ramSize;
  String? storageSize;

  final List<String> ramOptions = ['8 GB', '16 GB', '32 GB', '64 GB'];
  final List<String> storageOptions = ['256 GB', '512 GB', '1 TB', '2 TB'];

  @override
  void initState() {
    super.initState();
    final x = widget.item;
    brand = x?.brandId;
    model = x?.modelId;
    cpu = x?.cpuId;
    cpuGenerationId = x?.cpuGenerationId;
    cpuClassId = x?.cpuClassId;
    gpu = x?.gpuModelId;
    screen = x?.screenId;
    touch = x?.touch ?? false;
    twoInOne = x?.convertible ?? false;
    quantity = TextEditingController(text: '${x?.quantity ?? 1}');
    notes = TextEditingController(text: x?.notes ?? '');
    ramSize = ramOptions.first;
    storageSize = storageOptions.first;
  }

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> addCustomValue({
    required String title,
    required List<String> values,
    required ValueChanged<String> onAdded,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إضافة $title', textAlign: TextAlign.right),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: InputDecoration(hintText: 'أدخل $title'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  Navigator.pop(dialogContext);
                  return;
                }
                if (!values.contains(value)) {
                  values.add(value);
                  onAdded(value);
                }
                Navigator.pop(dialogContext);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      final value = result.trim();
      if (!values.contains(value)) {
        values.add(value);
        onAdded(value);
      }
    }
  }

  String get selectedGpuCategoryName {
    if (gpuCategory == null) return '';
    final match = widget.repo
        .choices('gpus')
        .firstWhere(
          (entry) => entry.id == gpuCategory,
          orElse: () => const Choice(-1, ''),
        );
    return match.name.toLowerCase();
  }

  List<Choice> get modelOptions {
    final base = widget.repo.choices('models', brandId: brand);
    if (cpu == null) return base;
    final genName = cpuGenerationId != null
        ? widget.repo.choices('cpu_generations').where((c) => c.id == cpuGenerationId).map((c) => c.name).firstOrNull
        : null;
    final className = cpuClassId != null
        ? widget.repo.choices('cpu_classes').where((c) => c.id == cpuClassId).map((c) => c.name).firstOrNull
        : null;
    return filterModelChoicesByCpu(
      base,
      generation: genName,
      family: className,
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      widget.item != null ? 'تعديل حاسبة' : 'إضافة حاسبة',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.text,
                      ),
                      tooltip: 'إغلاق',
                      splashRadius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 18),
                const Text(
                  'معلومات أساسية',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'الشركة',
                  child: field(
                    'الشركة',
                    'brands',
                    brand,
                    (v) => setState(() {
                      brand = v;
                      model = null;
                    }),
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'الموديل',
                  child: field(
                    'الموديل',
                    'models',
                    model,
                    (v) => setState(() => model = v),
                    brandId: brand,
                    choices: modelOptions,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'المواصفات',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'المعالج',
                  child: field(
                    'المعالج',
                    'cpus',
                    cpu,
                    (v) => setState(() => cpu = v),
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'جيل المعالج',
                  child: SearchableStringDropdown(
                    label: 'جيل المعالج',
                    value: cpuGenerationId != null
                        ? widget.repo.choices('cpu_generations').where((c) => c.id == cpuGenerationId).map((c) => c.name).firstOrNull
                        : null,
                    options: widget.repo.choices('cpu_generations').map((c) => c.name).toList(),
                    onChanged: (name) {
                      if (name == null) {
                        setState(() => cpuGenerationId = null);
                        return;
                      }
                      final match = widget.repo.choices('cpu_generations').where((c) => c.name == name);
                      setState(() => cpuGenerationId = match.isNotEmpty ? match.first.id : null);
                    },
                    onAddNew: (newValue) async {
                      final id = widget.repo.addChoice('cpu_generations', newValue);
                      setState(() => cpuGenerationId = id);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'فئة المعالج',
                  child: SearchableStringDropdown(
                    label: 'فئة المعالج',
                    value: cpuClassId != null
                        ? widget.repo.choices('cpu_classes').where((c) => c.id == cpuClassId).map((c) => c.name).firstOrNull
                        : null,
                    options: widget.repo.choices('cpu_classes').map((c) => c.name).toList(),
                    onChanged: (name) {
                      if (name == null) {
                        setState(() => cpuClassId = null);
                        return;
                      }
                      final match = widget.repo.choices('cpu_classes').where((c) => c.name == name);
                      setState(() => cpuClassId = match.isNotEmpty ? match.first.id : null);
                    },
                    onAddNew: (newValue) async {
                      final id = widget.repo.addChoice('cpu_classes', newValue);
                      setState(() => cpuClassId = id);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'حجم الرام',
                  child: SizedBox(
                    width: double.infinity,
                    child: DropdownMenu<String>(
                      initialSelection: ramSize ?? ramOptions.first,
                      width: double.infinity,
                      enableFilter: false,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                      hintText: 'اختر حجم الرام',
                      menuStyle: const MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
                        minimumSize: WidgetStatePropertyAll(Size(260, 180)),
                        maximumSize: WidgetStatePropertyAll(Size(320, 260)),
                      ),
                      dropdownMenuEntries: [
                        ...ramOptions.map(
                          (value) =>
                              DropdownMenuEntry(value: value, label: value),
                        ),
                        const DropdownMenuEntry(
                          value: '__add__',
                          label: '+ إضافة قيمة جديدة',
                        ),
                      ],
                      onSelected: (value) {
                        if (value == '__add__') {
                          addCustomValue(
                            title: 'حجم الرام',
                            values: ramOptions,
                            onAdded: (newValue) =>
                                setState(() => ramSize = newValue),
                          );
                          return;
                        }
                        setState(() => ramSize = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'حجم الذاكرة',
                  child: SizedBox(
                    width: double.infinity,
                    child: DropdownMenu<String>(
                      initialSelection: storageSize ?? storageOptions.first,
                      width: double.infinity,
                      enableFilter: false,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.text,
                      ),
                      hintText: 'اختر حجم الذاكرة',
                      menuStyle: const MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
                        minimumSize: WidgetStatePropertyAll(Size(260, 180)),
                        maximumSize: WidgetStatePropertyAll(Size(320, 260)),
                      ),
                      dropdownMenuEntries: [
                        ...storageOptions.map(
                          (value) =>
                              DropdownMenuEntry(value: value, label: value),
                        ),
                        const DropdownMenuEntry(
                          value: '__add__',
                          label: '+ إضافة قيمة جديدة',
                        ),
                      ],
                      onSelected: (value) {
                        if (value == '__add__') {
                          addCustomValue(
                            title: 'حجم الذاكرة',
                            values: storageOptions,
                            onAdded: (newValue) =>
                                setState(() => storageSize = newValue),
                          );
                          return;
                        }
                        setState(() => storageSize = value);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'فئة كرت الشاشة',
                  child: field(
                    'فئة كرت الشاشة',
                    'gpus',
                    gpuCategory,
                    (v) {
                      setState(() {
                        gpuCategory = v;
                        if (selectedGpuCategoryName == 'share') {
                          final shareModels = widget.repo.choices('gpu_models', gpuId: v);
                          final existing = shareModels.where(
                            (c) => c.name.toLowerCase() == 'share',
                          );
                          if (existing.isNotEmpty) {
                            gpu = existing.first.id;
                          } else {
                            gpu = widget.repo.addChoice('gpu_models', 'Share', gpuId: v);
                          }
                        } else {
                          gpu = null;
                        }
                      });
                    },
                  ),
                ),
                if (gpuCategory != null && selectedGpuCategoryName != 'share') ...[
                  const SizedBox(height: 12),
                  _FormFieldBlock(
                    label: 'موديل كرت الشاشة',
                    child: field(
                      'موديل كرت الشاشة',
                      'gpu_models',
                      gpu,
                      (v) => setState(() => gpu = v),
                      gpuId: gpuCategory,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'الشاشة',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'حجم الشاشة',
                  child: field(
                    'حجم الشاشة',
                    'screen_sizes',
                    screen,
                    (v) => setState(() => screen = v),
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'شاشة لمس',
                  child: BinaryToggle(
                    label: 'شاشة لمس',
                    value: touch,
                    onChanged: (v) => setState(() => touch = v),
                  ),
                ),
                const SizedBox(height: 12),
                _FormFieldBlock(
                  label: 'حاسبة 2 في 1',
                  child: BinaryToggle(
                    label: 'حاسبة 2 في 1',
                    value: twoInOne,
                    onChanged: (v) => setState(() => twoInOne = v),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'الكمية',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      hintText: 'أدخل الكمية',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'ملاحظات',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextField(
                    controller: notes,
                    maxLines: 4,
                    maxLength: 500,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      hintText: 'ملاحظات إضافية...',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 150,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.mediumAll,
                          ),
                        ),
                        onPressed: save,
                        child: const Text('حفظ الحاسبة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget field(
    String label,
    String table,
    int? value,
    ValueChanged<int?> onChanged, {
    int? brandId,
    int? gpuId,
    double width = double.infinity,
    List<Choice>? choices,
  }) => SizedBox(
    width: width,
    child: SearchableDropdown(
      label: label,
      enabled: (table != 'models' || brandId != null) && (table != 'gpu_models' || gpuId != null),
      value: value,
      items: choices ?? widget.repo.choices(table, brandId: brandId, gpuId: gpuId),
      onChanged: onChanged,
      onAdd: () => addLookup(table, label, brandId: brandId, gpuId: gpuId),
    ),
  );

  void addLookup(String table, String label, {int? brandId, int? gpuId}) {
    final input = TextEditingController();
    showDialog(
      context: context,
      builder: (dialog) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('إضافة $label', textAlign: TextAlign.right),
          content: TextField(
            controller: input,
            autofocus: true,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLength: 100,
            decoration: InputDecoration(labelText: 'اسم $label'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('إلغاء'),
            ),
            PrimaryButton(
              label: 'إضافة',
              onPressed: () {
                final value = input.text.trim();
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم القيمة')),
                  );
                  return;
                }

                final exists = widget.repo
                    .choices(table, brandId: brandId, gpuId: gpuId)
                    .any(
                      (item) => item.name.toLowerCase() == value.toLowerCase(),
                    );

                if (exists) {
                  Navigator.pop(dialog);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('هذه القيمة موجودة بالفعل')),
                  );
                  return;
                }

                try {
                  final id = widget.repo.addChoice(
                    table,
                    value,
                    brandId: brandId,
                    gpuId: gpuId,
                  );
                  Navigator.pop(dialog);
                  setState(() {
                    if (table == 'brands') brand = id;
                    if (table == 'models') model = id;
                    if (table == 'cpus') cpu = id;
                    if (table == 'gpus') gpuCategory = id;
                    if (table == 'gpu_models') gpu = id;
                    if (table == 'screen_sizes') screen = id;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إضافة القيمة بنجاح')),
                  );
                } catch (_) {
                  Navigator.pop(dialog);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('هذه القيمة موجودة بالفعل')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void save() {
    final validation = LaptopValidator.validate(
      brandId: brand,
      modelId: model,
      cpuId: cpu,
      gpuId: gpu,
      screenId: screen,
      quantity: quantity.text,
      notes: notes.text,
    );

    if (!validation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.errors.first),
        ),
      );
      return;
    }

    final isEditing = widget.item != null;

    try {
      widget.repo.save(
        {
          'brand': brand,
          'model': model,
          'cpu': cpu,
          'cpuGenerationId': cpuGenerationId,
          'cpuClassId': cpuClassId,
          'gpu': gpu,
          'screen': screen,
          'touch': touch,
          'convertible': twoInOne,
          'quantity': int.parse(quantity.text.trim()),
          'notes': notes.text.trim(),
        },
        id: widget.item?.id,
        sessionId: widget.sessionId,
      );

      Navigator.pop(context);
      widget.onSaved();
      showDialog(
        context: context,
        builder: (context) => _SuccessDialog(
          title: isEditing ? 'تم التعديل بنجاح' : 'تم الحفظ بنجاح',
          message: isEditing
              ? 'تم تعديل بيانات الحاسبة بنجاح'
              : 'تم حفظ بيانات الحاسبة بنجاح',
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الحفظ: $e')),
      );
    }
  }
}

class _FormFieldBlock extends StatelessWidget {
  const _FormFieldBlock({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      child,
    ],
  );
}

class BinaryToggle extends StatelessWidget {
  const BinaryToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: SegmentedButton<bool>(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      segments: const [
        ButtonSegment(value: true, label: Text('نعم')),
        ButtonSegment(value: false, label: Text('لا')),
      ],
      selected: {value},
      onSelectionChanged: (v) => onChanged(v.first),
    ),
  );
}

class SearchableDropdown extends StatelessWidget {
  const SearchableDropdown({
    super.key,
    required this.label,
    required this.enabled,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.onAdd,
  });
  final String label;
  final bool enabled;
  final int? value;
  final List<Choice> items;
  final ValueChanged<int?> onChanged;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: DropdownMenu<int>(
      enabled: enabled,
      initialSelection: value,
      hintText: 'اختر $label',
      width: double.infinity,
      enableFilter: true,
      textStyle: const TextStyle(fontSize: 14, color: AppColors.text),
      leadingIcon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.primary,
      ),
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.surface),
        minimumSize: WidgetStatePropertyAll(Size(260, 200)),
        maximumSize: WidgetStatePropertyAll(Size(320, 420)),
      ),
      dropdownMenuEntries: [
        ...items.map(
          (item) => DropdownMenuEntry(value: item.id, label: item.name),
        ),
        if (enabled)
          const DropdownMenuEntry(value: -1, label: '+ إضافة قيمة جديدة'),
      ],
      onSelected: (selected) {
        if (selected == -1) {
          onAdd();
          return;
        }
        onChanged(selected);
      },
    ),
  );
}

class SearchableStringDropdown extends StatefulWidget {
  const SearchableStringDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onAddNew,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final Future<void> Function(String newValue) onAddNew;

  @override
  State<SearchableStringDropdown> createState() => _SearchableStringDropdownState();
}

class _SearchableStringDropdownState extends State<SearchableStringDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isOpen = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<String> get _filteredOptions {
    if (_searchQuery.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _isOpen = !_isOpen);
            if (_isOpen) _focusNode.requestFocus();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: _isOpen ? AppColors.primary : AppColors.border,
              ),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.value ?? 'اختر ${widget.label}',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.value != null
                          ? AppColors.text
                          : AppColors.secondary,
                    ),
                  ),
                ),
                Icon(
                  _isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
        if (_isOpen) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      hintText: 'البحث عن ${widget.label}...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filteredOptions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _filteredOptions.length) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.add, size: 18, color: AppColors.primary),
                          title: Text(
                            _searchQuery.isEmpty
                                ? '+ إضافة قيمة جديدة'
                                : '+ إضافة "$_searchQuery"',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () async {
                            final newValue = _searchQuery.isNotEmpty
                                ? _searchQuery
                                : '';
                            if (newValue.isEmpty) return;
                            await widget.onAddNew(newValue);
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                            widget.onChanged(newValue);
                            setState(() => _isOpen = false);
                          },
                        );
                      }
                      final option = _filteredOptions[index];
                      final isSelected = option == widget.value;
                      return ListTile(
                        dense: true,
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withAlpha(20),
                        title: Text(
                          option,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        onTap: () {
                          widget.onChanged(option);
                          setState(() {
                            _isOpen = false;
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ReportsPage extends StatefulWidget {
  const ReportsPage(this.repo, {super.key});
  final InventoryRepository repo;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int? sessionId;

  @override
  Widget build(BuildContext context) {
    final sessions = widget.repo.listSessions();
    final currentSessionId = sessionId ?? widget.repo.currentSession()?.id;
    final selected = currentSessionId != null
        ? sessions.firstWhere(
            (s) => s.id == currentSessionId,
            orElse: () => sessions.first,
          )
        : sessions.firstOrNull;
    if (selected == null) {
      return const PageFrame(
        title: 'التقارير',
        description: 'تقارير وإحصائيات مخزون الحاسبات',
        child: Center(child: Text('لا توجد جرود بعد')),
      );
    }
    final summary = widget.repo.summary(sessionId: selected.id);
    const groups = {
      'b.name': 'الجرد حسب الشركة',
      'm.name': 'الجرد حسب الموديل',
      'c.name': 'الجرد حسب المعالج',
      'g.name': 'الجرد حسب كرت الشاشة',
      's.name': 'الجرد حسب حجم الشاشة',
    };

    final defects = widget.repo
        .list(sessionId: selected.id)
        .where((item) => item.notes.isNotEmpty)
        .toList();

    final mismatched = widget.repo
        .list(sessionId: selected.id)
        .where((item) => item.quantity <= 0)
        .toList();

    return PageFrame(
      title: 'التقارير',
      description: 'تقارير وإحصائيات مخزون الحاسبات',
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonFormField<int>(
              key: ValueKey('report-session-${selected.id}'),
              initialValue: selected.id,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'اختر جرد'),
              items: sessions.map((session) {
                final dateStr =
                    '${session.date.day}/${session.date.month}/${session.date.year}';
                final statusIcon = session.status == 'جاري'
                    ? Icons.radio_button_checked
                    : Icons.check_circle_outline;
                final statusColor = session.status == 'جاري'
                    ? AppColors.primary
                    : AppColors.success;
                return DropdownMenuItem<int>(
                  value: session.id,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${session.name} — $dateStr — ${session.status}',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => sessionId = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 2.0,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _SummaryTile(
                label: 'إجمالي الأجهزة',
                value: summary.totalDevices.toString(),
                icon: Icons.devices_outlined,
              ),
              _SummaryTile(
                label: 'إجمالي الكمية',
                value: summary.totalQuantity.toString(),
                icon: Icons.inventory_outlined,
              ),
              _SummaryTile(
                label: 'مطابق',
                value: summary.matched.toString(),
                icon: Icons.check_circle_outline,
                valueColor: AppColors.success,
              ),
              _SummaryTile(
                label: 'غير مطابق',
                value: summary.mismatched.toString(),
                icon: Icons.cancel_outlined,
                valueColor: AppColors.warning,
              ),
              _SummaryTile(
                label: 'عدد الشركات',
                value: summary.companyCount.toString(),
                icon: Icons.business_outlined,
              ),
              _SummaryTile(
                label: 'عدد الموديلات',
                value: summary.modelCount.toString(),
                icon: Icons.category_outlined,
              ),
              _SummaryTile(
                label: 'الأجهزة التي تحتوي على أعطال',
                value: summary.defectCount.toString(),
                icon: Icons.bug_report_outlined,
                valueColor: summary.defectCount > 0 ? AppColors.error : null,
              ),
              _SummaryTile(
                label: 'الجرد الحالي',
                value: selected.name,
                icon: Icons.assignment_outlined,
                isText: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in groups.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    for (final row in widget.repo.report(
                      entry.key,
                      sessionId: selected.id,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                row['name'] as String,
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              label: Text('${row['quantity']} حاسبة'),
                              backgroundColor: AppColors.lightBlue,
                              labelStyle: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (mismatched.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'الأجهزة غير المطابقة (${mismatched.length})',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in mismatched)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.brand} ${item.model}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${item.cpu} — ${item.gpu} — ${item.screen}',
                                      style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  'الكمية: ${item.quantity}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (defects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bug_report_outlined, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'الأجهزة التي تحتوي على أعطال (${defects.length})',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in defects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${item.brand} ${item.model}',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${item.cpu} — ${item.gpu} — ${item.screen}',
                                      style: const TextStyle(color: AppColors.secondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'العطل: ${item.notes}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.isText = false,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool isText;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: valueColor ?? AppColors.primary),
        const SizedBox(height: 8),
        isText
            ? Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  color: valueColor ?? AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondary, fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog({required this.title, required this.message});
  final String title;
  final String message;

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(24),
    child: AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: Opacity(
          opacity: _scale.value,
          child: SizedBox(
            width: 320,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.successLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.secondary),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage(this.repo, {super.key});
  final InventoryRepository repo;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final settings = [
      ('الشركات', 'إدارة شركات الحاسبات', Icons.business_outlined, 'brands'),
      ('الموديلات', 'إدارة موديلات الحاسبات', Icons.category_outlined, 'models'),
      ('المعالجات', 'إدارة أنواع المعالجات', Icons.memory_outlined, 'cpus'),
      (
        'كروت الشاشة',
        'إدارة أنواع كروت الشاشة',
        Icons.videogame_asset_outlined,
        'gpus',
      ),
      (
        'موديلات كرت الشاشة',
        'إدارة موديلات كروت الشاشة',
        Icons.memory_outlined,
        'gpu_models',
      ),
      ('أحجام الشاشات', 'إدارة أحجام الشاشات', Icons.desktop_windows_outlined, 'screen_sizes'),
    ];
    return PageFrame(
      title: 'الإعدادات',
      description: 'إدارة القوائم والبيانات المساعدة',
      action: OutlinedButton.icon(
        onPressed: _importLookupValues,
        icon: const Icon(Icons.file_upload_outlined, size: 18),
        label: const Text('استيراد قيم من Excel'),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in settings)
            SizedBox(
              width: 300,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Icon(item.$3, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.right,
                      ),
                      Text(
                        item.$2,
                        style: const TextStyle(color: AppColors.secondary),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: OutlinedButton.icon(
                          onPressed: () => _openManagementDialog(
                            item.$1,
                            item.$4,
                          ),
                          icon: const Icon(Icons.settings_outlined, size: 16),
                          label: const Text('إدارة'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openManagementDialog(String title, String table) {
    showDialog(
      context: context,
      builder: (_) => _ManagementDialog(
        repo: widget.repo,
        title: title,
        table: table,
        onUpdated: () => setState(() {}),
      ),
    );
  }

  Future<void> _importLookupValues() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );
      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.first.path;
      if (filePath == null) return;

      final preview = await _previewLookupImport(filePath);

      if (!mounted) return;

      if (preview.hasErrors) {
        _showLookupImportPreviewDialog(preview);
      } else if (preview.rows.isEmpty) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على بيانات في الملف')),
        );
      } else {
        _showLookupImportConfirmDialog(preview);
      }
    } catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text('خطأ في استيراد الملف: $e')),
      );
    }
  }

  Future<_LookupImportPreview> _previewLookupImport(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const _LookupImportPreview(rows: [], errors: [], totalRows: 0);
    }

    final bytes = await file.readAsBytes();
    final excel = excel_pkg.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const _LookupImportPreview(rows: [], errors: [], totalRows: 0);
    }

    final sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) {
      return const _LookupImportPreview(rows: [], errors: [], totalRows: 0);
    }

    final headerRow = sheet.row(0);
    int? nameColumn;
    for (var i = 0; i < headerRow.length; i++) {
      final value = headerRow[i]?.value?.toString().trim() ?? '';
      if (value == 'الاسم' || value.toLowerCase() == 'name') {
        nameColumn = i;
        break;
      }
    }

    if (nameColumn == null) {
      return _LookupImportPreview(
        rows: [],
        errors: [const _LookupImportError(row: 0, column: 'الرأس', message: 'لم يتم العثور على عمود "الاسم"')],
        totalRows: 0,
      );
    }

    final rows = <_LookupImportRow>[];
    final errors = <_LookupImportError>[];

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      final name = row[nameColumn]?.value?.toString().trim() ?? '';
      if (name.isEmpty) continue;

      if (name.length > 100) {
        errors.add(_LookupImportError(row: r + 1, column: 'الاسم', message: 'الاسم يجب أن يكون 100 حرف أو أقل'));
        continue;
      }

      final tables = ['brands', 'models', 'cpus', 'gpus', 'gpu_models', 'screen_sizes'];
      for (final table in tables) {
        final exists = widget.repo.choices(table).any(
          (c) => c.name.toLowerCase() == name.toLowerCase(),
        );
        if (exists) {
          errors.add(_LookupImportError(row: r + 1, column: 'الاسم', message: '"$name" موجود بالفعل في $table'));
          break;
        }
      }

      if (!errors.any((e) => e.row == r + 1)) {
        rows.add(_LookupImportRow(name: name, targetTable: _detectTargetTable(name)));
      }
    }

    return _LookupImportPreview(rows: rows, errors: errors, totalRows: rows.length);
  }

  String _detectTargetTable(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('cpu') || lower.contains('processor') || lower.contains('core') || lower.contains('ryzen') || lower.startsWith('i') && RegExp(r'^i[3579]$').hasMatch(lower)) {
      return 'cpus';
    }
    if (lower == 'rtx' || lower == 'gtx' || lower == 'quadro' || lower == 'share' || lower == 'other' || lower == 'radeon') {
      return 'gpus';
    }
    if (lower.contains('rtx') || lower.contains('gtx') || lower.contains('quadro') || lower.contains('radeon') || RegExp(r'^\d{4}$').hasMatch(lower)) {
      return 'gpu_models';
    }
    if (RegExp(r'^\d+(\.\d+)?["\u201D]?$').hasMatch(lower) || lower.contains('inch') || lower.contains('screen')) {
      return 'screen_sizes';
    }
    return 'brands';
  }

  void _showLookupImportPreviewDialog(_LookupImportPreview preview) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('معاينة الاستيراد'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('عدد الصفوف: ${preview.totalRows}'),
                const SizedBox(height: 8),
                Text(
                  'الأخطاء: ${preview.errors.length}',
                  style: TextStyle(
                    color: preview.errors.isNotEmpty ? AppColors.error : null,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: preview.errors.length,
                    itemBuilder: (context, index) {
                      final error = preview.errors[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.error,
                          child: Text(
                            '${error.row}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(error.column),
                        subtitle: Text(error.message),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            if (preview.rows.isNotEmpty)
              PrimaryButton(
                label: 'استيراد ${preview.rows.length} قيمة صحيحة',
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showLookupImportConfirmDialog(preview);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showLookupImportConfirmDialog(_LookupImportPreview preview) {
    final modelRows = preview.rows.where((r) => r.targetTable == 'models').toList();
    final gpuModelRows = preview.rows.where((r) => r.targetTable == 'gpu_models').toList();
    final otherRows = preview.rows.where((r) => r.targetTable != 'models' && r.targetTable != 'gpu_models').toList();
    int? importBrandId;
    int? importGpuCategoryId;
    final brands = widget.repo.choices('brands');
    final gpuCategories = widget.repo.choices('gpus');

    if (modelRows.isNotEmpty && brands.isNotEmpty) {
      importBrandId = brands.first.id;
    }
    if (gpuModelRows.isNotEmpty && gpuCategories.isNotEmpty) {
      importGpuCategoryId = gpuCategories.first.id;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد الاستيراد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('هل تريد استيراد ${preview.rows.length} قيمة إلى القوائم؟'),
                if (modelRows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: importBrandId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'الشركة (للموديلات)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: brands.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
                    onChanged: (v) => setDialogState(() => importBrandId = v),
                  ),
                ],
                if (gpuModelRows.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: importGpuCategoryId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'الفئة (لموديلات كرت الشاشة)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: gpuCategories.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                    onChanged: (v) => setDialogState(() => importGpuCategoryId = v),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              PrimaryButton(
                label: 'استيراد',
                onPressed: () {
                  if (modelRows.isNotEmpty && importBrandId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار الشركة للموديلات')),
                    );
                    return;
                  }
                  if (gpuModelRows.isNotEmpty && importGpuCategoryId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار الفئة لموديلات كرت الشاشة')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext);
                  try {
                    var imported = 0;
                    for (final row in otherRows) {
                      widget.repo.addChoice(row.targetTable, row.name);
                      imported++;
                    }
                    for (final row in modelRows) {
                      widget.repo.addChoice('models', row.name, brandId: importBrandId);
                      imported++;
                    }
                    for (final row in gpuModelRows) {
                      widget.repo.addChoice('gpu_models', row.name, gpuId: importGpuCategoryId);
                      imported++;
                    }
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم استيراد $imported قيمة بنجاح')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في الاستيراد: $e')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementDialog extends StatefulWidget {
  const _ManagementDialog({
    required this.repo,
    required this.title,
    required this.table,
    required this.onUpdated,
  });

  final InventoryRepository repo;
  final String title;
  final String table;
  final VoidCallback onUpdated;

  @override
  State<_ManagementDialog> createState() => _ManagementDialogState();
}

class _ManagementDialogState extends State<_ManagementDialog> {
  late List<Choice> items;
  final TextEditingController _controller = TextEditingController();
  int? _selectedParentId;

  bool get _isModelTable => widget.table == 'models';
  bool get _isGpuModelTable => widget.table == 'gpu_models';
  bool get _needsParent => _isModelTable || _isGpuModelTable;
  late List<Choice> _parents;

  @override
  void initState() {
    super.initState();
    if (_isModelTable) {
      _parents = widget.repo.choices('brands');
    } else if (_isGpuModelTable) {
      _parents = widget.repo.choices('gpus');
    } else {
      _parents = [];
    }
    if (_parents.isNotEmpty && _selectedParentId == null) {
      _selectedParentId = _parents.first.id;
    }
    _refresh();
  }

  void _refresh() {
    if (_isModelTable && _selectedParentId != null) {
      items = widget.repo.choices(widget.table, brandId: _selectedParentId);
    } else if (_isGpuModelTable && _selectedParentId != null) {
      items = widget.repo.choices(widget.table, gpuId: _selectedParentId);
    } else {
      items = widget.repo.choices(widget.table);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                    Text(
                    'إدارة ${widget.title}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.text),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_needsParent) ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedParentId,
                  isDense: true,
                  decoration: InputDecoration(
                    labelText: _isModelTable ? 'الشركة' : 'الفئة',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: _parents.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedParentId = v);
                    _refresh();
                  },
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 100,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: 'إضافة ${widget.title} جديد',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PrimaryButton(
                    label: 'إضافة',
                    icon: Icons.add,
                    onPressed: () {
                      final name = _controller.text.trim();
                      if (name.isEmpty) return;
                      if (_needsParent && _selectedParentId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_isModelTable ? 'يرجى اختيار الشركة' : 'يرجى اختيار الفئة')),
                        );
                        return;
                      }
                      try {
                        widget.repo.addChoice(
                          widget.table,
                          name,
                          brandId: _isModelTable ? _selectedParentId : null,
                          gpuId: _isGpuModelTable ? _selectedParentId : null,
                        );
                        _controller.clear();
                        _refresh();
                        widget.onUpdated();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('هذه القيمة موجودة بالفعل')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد عناصر',
                          style: TextStyle(color: AppColors.secondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            title: Text(
                              item.name,
                              textAlign: TextAlign.right,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'تعديل',
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  onPressed: () => _editItem(item),
                                ),
                                IconButton(
                                  tooltip: 'حذف',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: AppColors.error,
                                  ),
                                  onPressed: () => _deleteItem(item),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void _editItem(Choice item) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('تعديل ${widget.title}', textAlign: TextAlign.right),
          content: TextField(
            controller: controller,
            maxLength: 100,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                try {
                  widget.repo.updateChoice(widget.table, item, name);
                  Navigator.pop(dialogContext);
                  _refresh();
                  widget.onUpdated();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تعذّر التعديل')),
                  );
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(Choice item) {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حذف $widget.title', textAlign: TextAlign.right),
          content: Text(
            'هل أنت متأكد من حذف "${item.name}"؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                try {
                  widget.repo.deleteChoice(widget.table, item.id);
                  Navigator.pop(dialogContext);
                  _refresh();
                  widget.onUpdated();
                } catch (e) {
                   Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لا يمكن حذف هذا العنصر لأنه مستخدم في جرد'),
                    ),
                  );
                }
              },
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LookupImportRow {
  const _LookupImportRow({required this.name, required this.targetTable});
  final String name;
  final String targetTable;
}

class _LookupImportError {
  const _LookupImportError({required this.row, required this.column, required this.message});
  final int row;
  final String column;
  final String message;
}

class _LookupImportPreview {
  const _LookupImportPreview({required this.rows, required this.errors, required this.totalRows});
  final List<_LookupImportRow> rows;
  final List<_LookupImportError> errors;
  final int totalRows;
  bool get hasErrors => errors.isNotEmpty;
}
