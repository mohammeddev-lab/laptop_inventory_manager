import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/database_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_radius.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/dashboard/side_menu_widget.dart';
import 'features/inventory/data/inventory_repository.dart';

final repositoryProvider = FutureProvider<InventoryRepository>((ref) async {
  return InventoryRepository(await DatabaseService.open());
});

void main() => runApp(const ProviderScope(child: InventoryApp()));

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام جرد الحاسبات المحمولة',
      theme: AppTheme.light(),
      home: const AppShell(),
    ),
  );
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => ref
      .watch(repositoryProvider)
      .when(
        loading: () => const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: LoadingState()),
        ),
        error: (_, _) => const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(child: Text('حدث خطأ أثناء تحميل البيانات')),
          ),
        ),
        data: (repo) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Row(
              children: [
                SideMenuWidget(
                  selected: selected,
                  onSelected: (value) => setState(() => selected = value),
                ),
                Expanded(child: _screen(repo)),
              ],
            ),
          ),
        ),
      );

  Widget _screen(InventoryRepository repo) => switch (selected) {
    0 => DashboardScreen(repo),
    1 => InventoryPage(repo),
    2 => ReportsPage(repo),
    _ => SettingsPage(repo),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.pageTitle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(description, style: AppTypography.caption),
                ],
              ),
            ),
            ?action,
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
    icon: icon == null ? const SizedBox.shrink() : Icon(icon),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      minimumSize: const Size(0, 44),
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.mediumAll,
      ),
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

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
  });
  final String title, description;
  final int value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    height: 98,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: AppColors.primary),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$value',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: AppColors.secondary),
            ),
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, color: AppColors.secondary),
            ),
          ],
        ),
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
  @override
  Widget build(BuildContext context) {
    final items = widget.repo.list(search: query);
    return PageFrame(
      title: 'الجرد',
      description: 'إدارة ومتابعة مخزون الحاسبات المحمولة',
      action: PrimaryButton(
        label: 'إضافة حاسبة',
        icon: Icons.add,
        onPressed: () => _openForm(),
      ),
      child: Column(
        children: [
          SearchField(onChanged: (value) => setState(() => query = value)),
          const SizedBox(height: 16),
          const InventoryFilters(),
          const SizedBox(height: 16),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    title: query.isEmpty
                        ? 'لا توجد حاسبات'
                        : 'لا توجد سجلات جرد مطابقة لعملية البحث الحالية.',
                    message: query.isEmpty
                        ? 'أضف أول حاسبة إلى المخزون.'
                        : 'غيّر عبارة البحث أو أعد تعيين الفلاتر.',
                    action: PrimaryButton(
                      label: 'إضافة حاسبة',
                      icon: Icons.add,
                      onPressed: () => _openForm(),
                    ),
                  )
                : InventoryTable(
                    items: items,
                    onEdit: _openForm,
                    onDelete: _confirmDelete,
                  ),
          ),
        ],
      ),
    );
  }

  void _openForm([InventoryItem? item]) => showDialog(
    context: context,
    builder: (_) => InventoryForm(
      repo: widget.repo,
      item: item,
      onSaved: () => setState(() {}),
    ),
  );
  void _confirmDelete(InventoryItem item) => showDialog(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('حذف سجل الجرد؟'),
      content: const Text(
        'هل أنت متأكد من رغبتك في حذف سجل الجرد هذا؟\nلا يمكن التراجع عن هذا الإجراء.',
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
  );
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged});
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    decoration: const InputDecoration(
      labelText: 'بحث',
      hintText: 'البحث عن الشركة أو الموديل أو المعالج أو كرت الشاشة...',
      prefixIcon: Icon(Icons.search),
    ),
  );
}

class InventoryFilters extends StatelessWidget {
  const InventoryFilters({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: const [
          Expanded(child: _Filter(label: 'الشركة', value: 'جميع الشركات')),
          SizedBox(width: 10),
          Expanded(child: _Filter(label: 'المعالج', value: 'جميع المعالجات')),
          SizedBox(width: 10),
          Expanded(
            child: _Filter(label: 'كرت الشاشة', value: 'جميع كروت الشاشة'),
          ),
          SizedBox(width: 10),
          Expanded(child: _Filter(label: 'حجم الشاشة', value: 'جميع الأحجام')),
        ],
      ),
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    alignment: AlignmentDirectional.centerEnd,
    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
    dropdownColor: Colors.white,
    menuMaxHeight: 220,
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.white,
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
    selectedItemBuilder: (context) => [
      value,
    ].map((item) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          item,
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
    }).toList(),
    items: [
      DropdownMenuItem<String>(
        value: value,
        alignment: AlignmentDirectional.centerEnd,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
            value,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ],
    onChanged: (_) {},
  );
}

class InventoryTable extends StatelessWidget {
  const InventoryTable({
    super.key,
    required this.items,
    required this.onEdit,
    required this.onDelete,
  });

  final List<InventoryItem> items;
  final ValueChanged<InventoryItem> onEdit, onDelete;

  static const _columnWidths = [
    120.0,
    120.0,
    120.0,
    130.0,
    110.0,
    82.0,
    90.0,
    92.0,
    96.0,
    120.0,
  ];

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1200),
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
                        width: _columnWidths[i],
                        child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: Text(
                            _columnHeaders[i],
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                ],
                rows: items
                    .map(
                      (item) => DataRow(
                        color: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return AppColors.lightBlue.withAlpha(80);
                          }
                          return Colors.white;
                        }),
                        cells: [
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.brand),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.model),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.cpu),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.gpu),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.screen),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.touch ? 'نعم' : 'لا'),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(item.convertible ? 'نعم' : 'لا'),
                            ),
                          ),
                          DataCell(
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
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
                                  '${item.quantity}',
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
                              alignment: AlignmentDirectional.centerEnd,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: item.quantity > 0
                                      ? AppColors.successLight
                                      : AppColors.warningLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  item.quantity > 0 ? 'مطابق' : 'غير مطابق',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: item.quantity > 0
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                textDirection: TextDirection.rtl,
                                children: [
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
                                    onPressed: () => onEdit(item),
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
                                    onPressed: () => onDelete(item),
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
          ),
        ),
      ),
    ),
  );

  static const List<String> _columnHeaders = [
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
  });
  final InventoryRepository repo;
  final InventoryItem? item;
  final VoidCallback onSaved;
  @override
  State<InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<InventoryForm> {
  late int? brand, model, cpu, gpu, screen;
  late bool touch, twoInOne;
  late final TextEditingController quantity, notes;
  String? generation;
  String? family;
  String? ramSize;
  String? storageSize;
  String? gpuSeries;

  final List<String> generationOptions = ['6th', '7th', '8th', '9th', '10th'];
  final List<String> familyOptions = ['u', 'h', 'hx'];
  final List<String> ramOptions = ['8 GB', '16 GB', '32 GB', '64 GB'];
  final List<String> storageOptions = ['256 GB', '512 GB', '1 TB', '2 TB'];
  final List<String> gpuSeriesOptions = ['20', '30', '40', '50', 'أخرى'];

  @override
  void initState() {
    super.initState();
    final x = widget.item;
    brand = x?.brandId;
    model = x?.modelId;
    cpu = x?.cpuId;
    gpu = x?.gpuId;
    screen = x?.screenId;
    touch = x?.touch ?? false;
    twoInOne = x?.convertible ?? false;
    quantity = TextEditingController(text: '${x?.quantity ?? 1}');
    notes = TextEditingController(text: x?.notes ?? '');
    generation = generationOptions.first;
    family = familyOptions.first;
    ramSize = ramOptions.first;
    storageSize = storageOptions.first;
  }

  @override
  void dispose() {
    quantity.dispose();
    notes.dispose();
    super.dispose();
  }

  bool get requiresCpuDetails => cpu != null;

  Future<void> addCustomValue({
    required String title,
    required List<String> values,
    required ValueChanged<String> onAdded,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إضافة $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
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
    );
    if (result != null && result.trim().isNotEmpty) {
      final value = result.trim();
      if (!values.contains(value)) {
        values.add(value);
        onAdded(value);
      }
    }
  }

  String get selectedGpuName {
    if (gpu == null) return '';
    final match = widget.repo
        .choices('gpus')
        .firstWhere(
          (entry) => entry.id == gpu,
          orElse: () => const Choice(-1, ''),
        );
    return match.name.toLowerCase();
  }

  bool get requiresGpuSeries => selectedGpuName == 'gtx';

  List<Choice> get modelOptions {
    final base = widget.repo.choices('models', brandId: brand);
    if (cpu == null) return base;
    return filterModelChoicesByCpu(
      base,
      generation: generation,
      family: family,
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    const Text(
                      'إضافة حاسبة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
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
                    (v) => setState(() {
                      cpu = v;
                      if (cpu != null) {
                        generation ??= generationOptions.first;
                        family ??= familyOptions.first;
                      } else {
                        generation = null;
                        family = null;
                      }
                    }),
                  ),
                ),
                if (requiresCpuDetails) ...[
                  const SizedBox(height: 12),
                  _FormFieldBlock(
                    label: 'جيل المعالج',
                    child: SizedBox(
                      width: double.infinity,
                      child: DropdownMenu<String>(
                        initialSelection: generation ?? generationOptions.first,
                        width: double.infinity,
                        enableFilter: false,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                        hintText: 'اختر الجيل',
                        menuStyle: const MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(Colors.white),
                          minimumSize: WidgetStatePropertyAll(Size(260, 180)),
                          maximumSize: WidgetStatePropertyAll(Size(320, 260)),
                        ),
                        dropdownMenuEntries: [
                          ...generationOptions.map(
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
                              title: 'جيل المعالج',
                              values: generationOptions,
                              onAdded: (newValue) =>
                                  setState(() => generation = newValue),
                            );
                            return;
                          }
                          setState(() => generation = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FormFieldBlock(
                    label: 'فئة المعالج',
                    child: SizedBox(
                      width: double.infinity,
                      child: DropdownMenu<String>(
                        initialSelection: family ?? familyOptions.first,
                        width: double.infinity,
                        enableFilter: false,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                        hintText: 'اختر الفئة',
                        menuStyle: const MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(Colors.white),
                          minimumSize: WidgetStatePropertyAll(Size(260, 180)),
                          maximumSize: WidgetStatePropertyAll(Size(320, 260)),
                        ),
                        dropdownMenuEntries: [
                          ...familyOptions.map(
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
                              title: 'فئة المعالج',
                              values: familyOptions,
                              onAdded: (newValue) =>
                                  setState(() => family = newValue),
                            );
                            return;
                          }
                          setState(() => family = value);
                        },
                      ),
                    ),
                  ),
                ],
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
                        backgroundColor: WidgetStatePropertyAll(Colors.white),
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
                        backgroundColor: WidgetStatePropertyAll(Colors.white),
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
                  label: 'كرت الشاشة',
                  child: field(
                    'كرت الشاشة',
                    'gpus',
                    gpu,
                    (v) => setState(() {
                      gpu = v;
                      if (v == null) {
                        gpuSeries = null;
                      } else if (selectedGpuName == 'gtx') {
                        gpuSeries ??= gpuSeriesOptions.first;
                      } else {
                        gpuSeries = null;
                      }
                    }),
                  ),
                ),
                if (requiresGpuSeries) ...[
                  const SizedBox(height: 12),
                  _FormFieldBlock(
                    label: 'نوع كرت الشاشة',
                    child: SizedBox(
                      width: double.infinity,
                      child: DropdownMenu<String>(
                        initialSelection: gpuSeries ?? gpuSeriesOptions.first,
                        width: double.infinity,
                        enableFilter: false,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          color: AppColors.text,
                        ),
                        hintText: 'اختر النوع',
                        menuStyle: const MenuStyle(
                          backgroundColor: WidgetStatePropertyAll(Colors.white),
                          minimumSize: WidgetStatePropertyAll(Size(260, 180)),
                          maximumSize: WidgetStatePropertyAll(Size(320, 260)),
                        ),
                        dropdownMenuEntries: [
                          ...gpuSeriesOptions.map(
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
                              title: 'نوع كرت الشاشة',
                              values: gpuSeriesOptions,
                              onAdded: (newValue) =>
                                  setState(() => gpuSeries = newValue),
                            );
                            return;
                          }
                          setState(() => gpuSeries = value);
                        },
                      ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
    double width = double.infinity,
    List<Choice>? choices,
  }) => SizedBox(
    width: width,
    child: SearchableDropdown(
      label: label,
      enabled: table != 'models' || brandId != null,
      value: value,
      items: choices ?? widget.repo.choices(table, brandId: brandId),
      onChanged: onChanged,
      onAdd: () => addLookup(table, label, brandId),
    ),
  );

  void addLookup(String table, String label, int? brandId) {
    final input = TextEditingController();
    showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text('إضافة $label'),
        content: TextField(
          controller: input,
          autofocus: true,
          textDirection: TextDirection.rtl,
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
                  .choices(table, brandId: brandId)
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
                );
                Navigator.pop(dialog);
                setState(() {
                  if (table == 'brands') brand = id;
                  if (table == 'models') model = id;
                  if (table == 'cpus') cpu = id;
                  if (table == 'gpus') gpu = id;
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
    );
  }

  void save() {
    final q = int.tryParse(quantity.text);
    if (brand == null ||
        model == null ||
        cpu == null ||
        gpu == null ||
        screen == null ||
        q == null ||
        q < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى إكمال الحقول المطلوبة وإدخال كمية صحيحة أكبر من صفر',
          ),
        ),
      );
      return;
    }

    widget.repo.save({
      'brand': brand,
      'model': model,
      'cpu': cpu,
      'gpu': gpu,
      'screen': screen,
      'touch': touch,
      'convertible': twoInOne,
      'quantity': q,
      'notes': notes.text.trim(),
    }, id: widget.item?.id);

    Navigator.pop(context);
    widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.item == null
              ? 'تمت إضافة الحاسبة بنجاح'
              : 'تم تعديل بيانات الحاسبة بنجاح',
        ),
      ),
    );
  }
}

class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
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
        backgroundColor: Colors.white,
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
        backgroundColor: WidgetStatePropertyAll(Colors.white),
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

class ReportsPage extends StatelessWidget {
  const ReportsPage(this.repo, {super.key});
  final InventoryRepository repo;
  @override
  Widget build(BuildContext context) {
    const groups = {
      'b.name': 'الجرد حسب الشركة',
      'm.name': 'الجرد حسب الموديل',
      'c.name': 'الجرد حسب المعالج',
      'g.name': 'الجرد حسب كرت الشاشة',
    };
    return PageFrame(
      title: 'التقارير',
      description: 'تقارير وإحصائيات مخزون الحاسبات',
      child: ListView(
        children: [
          for (final entry in groups.entries)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    for (final row in repo.report(entry.key))
                      ListTile(
                        dense: true,
                        title: Text(row['name'] as String),
                        trailing: Chip(label: Text('${row['quantity']} حاسبة')),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage(this.repo, {super.key});
  final InventoryRepository repo;
  @override
  Widget build(BuildContext context) {
    const settings = [
      ('الشركات', 'إدارة شركات الحاسبات', Icons.business_outlined),
      ('الموديلات', 'إدارة موديلات الحاسبات', Icons.category_outlined),
      ('المعالجات', 'إدارة أنواع المعالجات', Icons.memory_outlined),
      (
        'كروت الشاشة',
        'إدارة أنواع كروت الشاشة',
        Icons.videogame_asset_outlined,
      ),
      ('أحجام الشاشات', 'إدارة أحجام الشاشات', Icons.desktop_windows_outlined),
    ];
    return PageFrame(
      title: 'الإعدادات',
      description: 'إدارة القوائم والبيانات المساعدة',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.$3, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        item.$2,
                        style: const TextStyle(color: AppColors.secondary),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('إدارة'),
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
}
