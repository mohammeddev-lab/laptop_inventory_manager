import 'dart:io';

import 'package:excel/excel.dart' as excel_pkg;

import 'inventory_repository.dart';

class ImportValidationError {
  const ImportValidationError({
    required this.row,
    required this.column,
    required this.message,
  });

  final int row;
  final String column;
  final String message;
}

class ImportRow {
  const ImportRow({
    required this.brand,
    required this.model,
    required this.cpu,
    required this.gpu,
    required this.screen,
    required this.touch,
    required this.convertible,
    required this.quantity,
    this.notes = '',
  });

  final String brand;
  final String model;
  final String cpu;
  final String gpu;
  final String screen;
  final bool touch;
  final bool convertible;
  final int quantity;
  final String notes;
}

class ImportPreview {
  const ImportPreview({
    required this.rows,
    required this.errors,
    required this.totalRows,
  });

  final List<ImportRow> rows;
  final List<ImportValidationError> errors;
  final int totalRows;

  bool get hasErrors => errors.isNotEmpty;
}

class ImportService {
  ImportService(this.repository);
  final InventoryRepository repository;

  static const _headerMapping = {
    'الشركة': 'brand',
    'الموديل': 'model',
    'المعالج': 'cpu',
    'كرت الشاشة': 'gpu',
    'حجم الشاشة': 'screen',
    'اللمس': 'touch',
    '2 في 1': 'convertible',
    'الكمية': 'quantity',
    'العطل / الملاحظات': 'notes',
  };

  static const _knownGpuCategories = ['rtx', 'gtx', 'quadro', 'share', 'other'];

  Future<ImportPreview> preview(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const ImportPreview(rows: [], errors: [], totalRows: 0);
    }

    final bytes = await file.readAsBytes();
    final excel = excel_pkg.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return const ImportPreview(rows: [], errors: [], totalRows: 0);
    }

    final sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) {
      return const ImportPreview(rows: [], errors: [], totalRows: 0);
    }

    final headerRow = sheet.row(0);
    final columnMap = <int, String>{};
    for (var i = 0; i < headerRow.length; i++) {
      final value = headerRow[i]?.value?.toString().trim() ?? '';
      final mapped = _headerMapping[value];
      if (mapped != null) {
        columnMap[i] = mapped;
      }
    }

    final rows = <ImportRow>[];
    final errors = <ImportValidationError>[];

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      if (row.every((cell) => cell?.value == null)) continue;

      final data = <String, String>{};
      for (final entry in columnMap.entries) {
        final cellValue = row[entry.key]?.value?.toString().trim() ?? '';
        data[entry.value] = cellValue;
      }

      _validateRow(r, data, rows, errors);
    }

    return ImportPreview(rows: rows, errors: errors, totalRows: rows.length);
  }

  void _validateRow(
    int r,
    Map<String, String> data,
    List<ImportRow> rows,
    List<ImportValidationError> errors,
  ) {
    final brand = data['brand'] ?? '';
    final model = data['model'] ?? '';
    final cpu = data['cpu'] ?? '';
    final gpu = data['gpu'] ?? '';
    final screen = data['screen'] ?? '';
    final touchStr = data['touch'] ?? '';
    final convertibleStr = data['convertible'] ?? '';
    final quantityStr = data['quantity'] ?? '';
    final notes = data['notes'] ?? '';

    if (brand.isEmpty) {
      errors.add(ImportValidationError(row: r + 1, column: 'الشركة', message: 'الشركة مطلوبة'));
    }
    if (model.isEmpty) {
      errors.add(ImportValidationError(row: r + 1, column: 'الموديل', message: 'الموديل مطلوب'));
    }
    if (cpu.isEmpty) {
      errors.add(ImportValidationError(row: r + 1, column: 'المعالج', message: 'المعالج مطلوب'));
    }
    if (gpu.isEmpty) {
      errors.add(ImportValidationError(row: r + 1, column: 'كرت الشاشة', message: 'كرت الشاشة مطلوب'));
    }
    if (screen.isEmpty) {
      errors.add(ImportValidationError(row: r + 1, column: 'حجم الشاشة', message: 'حجم الشاشة مطلوب'));
    }

    final quantity = int.tryParse(quantityStr);
    if (quantity == null || quantity < 0) {
      errors.add(ImportValidationError(row: r + 1, column: 'الكمية', message: 'الكمية يجب أن تكون رقماً صحيحاً أكبر من أو يساوي صفر'));
    }

    if (errors.any((e) => e.row == r + 1)) return;

    final touch = touchStr == 'نعم' || touchStr.toLowerCase() == 'yes' || touchStr == 'true' || touchStr == '1';
    final convertible = convertibleStr == 'نعم' || convertibleStr.toLowerCase() == 'yes' || convertibleStr == 'true' || convertibleStr == '1';

    rows.add(ImportRow(
      brand: brand,
      model: model,
      cpu: cpu,
      gpu: gpu,
      screen: screen,
      touch: touch,
      convertible: convertible,
      quantity: quantity!,
      notes: notes,
    ));
  }

  int commit(ImportPreview preview, {int? sessionId}) {
    var imported = 0;
    for (final row in preview.rows) {
      final brandId = _resolveOrCreate('brands', row.brand);
      final modelId = _resolveOrCreateModel(brandId, row.model);
      final cpuId = _resolveOrCreate('cpus', row.cpu);
      final gpuModelId = _resolveOrCreateGpuModel(row.gpu);
      final screenId = _resolveOrCreate('screen_sizes', row.screen);

      repository.save(
        {
          'brand': brandId,
          'model': modelId,
          'cpu': cpuId,
          'gpu': gpuModelId,
          'screen': screenId,
          'touch': row.touch,
          'convertible': row.convertible,
          'quantity': row.quantity,
          'notes': row.notes,
        },
        sessionId: sessionId,
      );
      imported++;
    }
    return imported;
  }

  int _resolveOrCreate(String table, String name) {
    final existing = repository.choices(table).where(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first.id;
    return repository.addChoice(table, name);
  }

  int _resolveOrCreateModel(int brandId, String name) {
    final existing = repository.choices('models', brandId: brandId).where(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first.id;
    return repository.addChoice('models', name, brandId: brandId);
  }

  int _resolveOrCreateGpuModel(String gpuName) {
    final parts = _parseGpuName(gpuName);
    final categoryName = parts.$1;
    final modelName = parts.$2;

    final categories = repository.choices('gpus').where(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
    );
    final categoryId = categories.isNotEmpty
        ? categories.first.id
        : repository.addChoice('gpus', categoryName);

    final models = repository.choices('gpu_models', gpuId: categoryId).where(
      (c) => c.name.toLowerCase() == modelName.toLowerCase(),
    );
    if (models.isNotEmpty) return models.first.id;
    return repository.addChoice('gpu_models', modelName, gpuId: categoryId);
  }

  (String, String) _parseGpuName(String gpuName) {
    final lower = gpuName.toLowerCase().trim();
    for (final cat in _knownGpuCategories) {
      if (lower.startsWith('$cat ') || lower == cat) {
        final modelPart = lower.substring(cat.length).trim();
        if (modelPart.isNotEmpty) {
          return (cat.toUpperCase(), modelPart);
        }
        return (cat.toUpperCase(), cat.toUpperCase());
      }
    }
    final spaceIndex = gpuName.indexOf(' ');
    if (spaceIndex > 0) {
      return (gpuName.substring(0, spaceIndex), gpuName.substring(spaceIndex + 1));
    }
    return ('Other', gpuName);
  }
}
