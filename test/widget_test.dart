import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laptop_inventory_manager/core/database/database_service.dart';
import 'package:laptop_inventory_manager/core/validators/validators.dart';
import 'package:laptop_inventory_manager/features/inventory/data/inventory_repository.dart';
import 'package:laptop_inventory_manager/main.dart';
import 'package:path/path.dart' as p;

void main() {
  test('model list filters by generation and family values', () {
    final base = [
      const Choice(1, 'Dell Latitude 7440 7th U'),
      const Choice(2, 'Dell Latitude 7440 7th H'),
      const Choice(3, 'Dell Latitude 7440 7th HX'),
      const Choice(4, 'HP EliteBook 840 6th U'),
    ];

    final filtered = filterModelChoicesByCpu(
      base,
      generation: '7th',
      family: 'hx',
    );

    expect(filtered.map((e) => e.id), [3]);
  });

  test('inventory sessions keep historical records independent', () async {
    final dir = await Directory.systemTemp.createTemp('inventory_session_test');
    final path = p.join(dir.path, 'inventory_session_test.db');
    final db = await DatabaseService.open(path: path);
    final repo = InventoryRepository(db);

    final brand = repo.addChoice('brands', 'Dell Session Test');
    final model = repo.addChoice(
      'models',
      'Latitude 7440 Session',
      brandId: brand,
    );
    final cpu = repo.addChoice('cpus', 'i7 Session');
    final gpu = repo.addChoice('gpus', 'RTX Session');
    final screen = repo.addChoice('screen_sizes', '14" Session');

    final session1 = repo.createSession(
      name: 'جرد #1',
      date: DateTime(2026, 8, 29),
    );
    final session2 = repo.createSession(
      name: 'جرد #2',
      date: DateTime(2026, 8, 30),
    );

    repo.save({
      'brand': brand,
      'model': model,
      'cpu': cpu,
      'gpu': gpu,
      'screen': screen,
      'touch': false,
      'convertible': false,
      'quantity': 1,
      'notes': 'session 1',
    }, sessionId: session1.id);

    repo.save({
      'brand': brand,
      'model': model,
      'cpu': cpu,
      'gpu': gpu,
      'screen': screen,
      'touch': false,
      'convertible': false,
      'quantity': 5,
      'notes': 'session 2',
    }, sessionId: session2.id);

    expect(repo.listSessions().length, greaterThanOrEqualTo(2));
    expect(repo.list(sessionId: session1.id).length, 1);
    expect(repo.list(sessionId: session2.id).length, 1);
    expect(repo.list(sessionId: session1.id).first.quantity, 1);
    expect(repo.list(sessionId: session2.id).first.quantity, 5);
    expect(repo.currentSession()?.id, session2.id);

    db.close();
    await dir.delete(recursive: true);
  });

  group('NameValidator', () {
    test('rejects empty name', () {
      final result = NameValidator.validate('');
      expect(result.isValid, false);
      expect(result.errors, contains('الاسم مطلوب'));
    });

    test('rejects whitespace-only name', () {
      final result = NameValidator.validate('   ');
      expect(result.isValid, false);
    });

    test('rejects name exceeding max length', () {
      final result = NameValidator.validate('a' * 101);
      expect(result.isValid, false);
      expect(result.errors.first, contains('100 حرف'));
    });

    test('accepts valid name', () {
      final result = NameValidator.validate('ThinkPad 320');
      expect(result.isValid, true);
    });

    test('trims whitespace', () {
      final result = NameValidator.validate('  ThinkPad 320  ');
      expect(result.isValid, true);
    });
  });

  group('QuantityValidator', () {
    test('rejects empty quantity', () {
      final result = QuantityValidator.validate('');
      expect(result.isValid, false);
      expect(result.errors, contains('الكمية مطلوبة'));
    });

    test('rejects non-numeric quantity', () {
      final result = QuantityValidator.validate('abc');
      expect(result.isValid, false);
    });

    test('rejects negative quantity', () {
      final result = QuantityValidator.validate('-1');
      expect(result.isValid, false);
    });

    test('accepts zero quantity', () {
      final result = QuantityValidator.validate('0');
      expect(result.isValid, true);
    });

    test('accepts positive quantity', () {
      final result = QuantityValidator.validate('10');
      expect(result.isValid, true);
    });
  });

  group('LaptopValidator', () {
    test('rejects missing brand', () {
      final result = LaptopValidator.validate(
        modelId: 1,
        cpuId: 1,
        gpuId: 1,
        screenId: 1,
        quantity: '1',
      );
      expect(result.isValid, false);
      expect(result.errors, contains('الشركة مطلوبة'));
    });

    test('rejects missing model', () {
      final result = LaptopValidator.validate(
        brandId: 1,
        cpuId: 1,
        gpuId: 1,
        screenId: 1,
        quantity: '1',
      );
      expect(result.isValid, false);
      expect(result.errors, contains('الموديل مطلوب'));
    });

    test('rejects invalid quantity', () {
      final result = LaptopValidator.validate(
        brandId: 1,
        modelId: 1,
        cpuId: 1,
        gpuId: 1,
        screenId: 1,
        quantity: 'abc',
      );
      expect(result.isValid, false);
      expect(result.errors, contains('الكمية يجب أن تكون رقماً صحيحاً'));
    });

    test('accepts valid laptop data', () {
      final result = LaptopValidator.validate(
        brandId: 1,
        modelId: 1,
        cpuId: 1,
        gpuId: 1,
        screenId: 1,
        quantity: '10',
      );
      expect(result.isValid, true);
    });
  });

  group('InventoryRepository', () {
    late DatabaseService db;
    late InventoryRepository repo;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('repo_test');
      final path = p.join(tempDir.path, 'test.db');
      db = await DatabaseService.open(path: path);
      repo = InventoryRepository(db);
    });

    tearDown(() {
      db.close();
    });

    tearDownAll(() async {
      await tempDir.delete(recursive: true);
    });

    test('addChoice creates choice and returns id', () {
      final id = repo.addChoice('brands', 'TestBrand');
      expect(id, greaterThan(0));
    });

    test('addChoice rejects duplicate', () {
      repo.addChoice('brands', 'DupBrand');
      expect(
        () => repo.addChoice('brands', 'DupBrand'),
        throwsA(isA<StateError>()),
      );
    });

    test('addChoice rejects empty name', () {
      expect(
        () => repo.addChoice('brands', ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('addChoice rejects name exceeding 100 chars', () {
      expect(
        () => repo.addChoice('brands', 'a' * 101),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('addChoice rejects null brandId for models', () {
      expect(
        () => repo.addChoice('models', 'TestModel'),
        throwsA(isA<StateError>()),
      );
    });

    test('choices returns list of choices', () {
      repo.addChoice('brands', 'ChoiceA');
      repo.addChoice('brands', 'ChoiceB');
      final choices = repo.choices('brands');
      expect(choices.length, greaterThanOrEqualTo(2));
    });

    test('choices filters by brand for models', () {
      final brandId = repo.addChoice('brands', 'ModelTestBrand');
      repo.addChoice('models', 'ModelA', brandId: brandId);
      repo.addChoice('models', 'ModelB', brandId: brandId);
      final models = repo.choices('models', brandId: brandId);
      expect(models.length, 2);
    });

    test('updateChoice updates name', () {
      final id = repo.addChoice('brands', 'OldName');
      final choice = Choice(id, 'OldName');
      repo.updateChoice('brands', choice, 'NewName');
      final updated = repo.choices('brands').where((c) => c.id == id);
      expect(updated.first.name, 'NewName');
    });

    test('updateChoice rejects duplicate name', () {
      repo.addChoice('brands', 'Brand1');
      final id2 = repo.addChoice('brands', 'Brand2');
      final choice = Choice(id2, 'Brand2');
      expect(
        () => repo.updateChoice('brands', choice, 'Brand1'),
        throwsA(isA<StateError>()),
      );
    });

    test('save creates inventory item', () {
      final brand = repo.addChoice('brands', 'SaveBrand');
      final model = repo.addChoice('models', 'SaveModel', brandId: brand);
      final cpu = repo.addChoice('cpus', 'SaveCPU');
      final gpu = repo.addChoice('gpus', 'SaveGPU');
      final screen = repo.addChoice('screen_sizes', '14" Save');

      repo.save({
        'brand': brand,
        'model': model,
        'cpu': cpu,
        'gpu': gpu,
        'screen': screen,
        'touch': false,
        'convertible': false,
        'quantity': 5,
        'notes': 'test save',
      });

      final items = repo.list();
      expect(items.length, 1);
      expect(items.first.quantity, 5);
    });

    test('save with quantity=0 is allowed', () {
      final brand = repo.addChoice('brands', 'ZeroBrand');
      final model = repo.addChoice('models', 'ZeroModel', brandId: brand);
      final cpu = repo.addChoice('cpus', 'ZeroCPU');
      final gpu = repo.addChoice('gpus', 'ZeroGPU');
      final screen = repo.addChoice('screen_sizes', '14" Zero');

      repo.save({
        'brand': brand,
        'model': model,
        'cpu': cpu,
        'gpu': gpu,
        'screen': screen,
        'touch': false,
        'convertible': false,
        'quantity': 0,
        'notes': 'mismatched',
      });

      final items = repo.list();
      expect(items.length, 1);
      expect(items.first.quantity, 0);
    });

    test('duplicate detects matching items', () {
      final brand = repo.addChoice('brands', 'DupBrand');
      final model = repo.addChoice('models', 'DupModel', brandId: brand);
      final cpu = repo.addChoice('cpus', 'DupCPU');
      final gpu = repo.addChoice('gpus', 'DupGPU');
      final screen = repo.addChoice('screen_sizes', '14" Dup');

      repo.save({
        'brand': brand,
        'model': model,
        'cpu': cpu,
        'gpu': gpu,
        'screen': screen,
        'touch': false,
        'convertible': false,
        'quantity': 1,
        'notes': '',
      });

      final dup = repo.duplicate({
        'brand': brand,
        'model': model,
        'cpu': cpu,
        'gpu': gpu,
        'screen': screen,
        'touch': false,
        'convertible': false,
      });

      expect(dup, isNotNull);
    });

    test('report returns grouped data', () {
      final brand = repo.addChoice('brands', 'ReportBrand');
      final model = repo.addChoice('models', 'ReportModel', brandId: brand);
      final cpu = repo.addChoice('cpus', 'ReportCPU');
      final gpu = repo.addChoice('gpus', 'ReportGPU');
      final screen = repo.addChoice('screen_sizes', '14" Report');

      repo.save({
        'brand': brand,
        'model': model,
        'cpu': cpu,
        'gpu': gpu,
        'screen': screen,
        'touch': false,
        'convertible': false,
        'quantity': 3,
        'notes': '',
      });

      final report = repo.report('b.name');
      expect(report.length, 1);
      expect(report.first['quantity'], 3);
    });

    test('report rejects invalid field', () {
      expect(
        () => repo.report('invalid.field'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ThinkPad 320 seed', () {
    test('ThinkPad 320 exists after seed', () async {
      final dir = await Directory.systemTemp.createTemp('seed_test');
      final path = p.join(dir.path, 'seed_test.db');
      final db = await DatabaseService.open(path: path);
      final repo = InventoryRepository(db);

      final lenovo = repo.choices('brands').where(
        (c) => c.name.toLowerCase() == 'lenovo',
      );
      expect(lenovo.isNotEmpty, true);

      final models = repo.choices('models', brandId: lenovo.first.id);
      final thinkpad = models.where(
        (c) => c.name.toLowerCase() == 'thinkpad 320',
      );
      expect(thinkpad.isNotEmpty, true);

      db.close();
      await dir.delete(recursive: true);
    });
  });

  group('GPU models', () {
    test('GPU categories and models exist after seed', () async {
      final dir = await Directory.systemTemp.createTemp('gpu_seed_test');
      final path = p.join(dir.path, 'gpu_seed_test.db');
      final db = await DatabaseService.open(path: path);
      final repo = InventoryRepository(db);

      final rtx = repo.choices('gpus').where(
        (c) => c.name.toLowerCase() == 'rtx',
      );
      expect(rtx.isNotEmpty, true);

      final rtxModels = repo.choices('gpu_models', gpuId: rtx.first.id);
      expect(rtxModels.isNotEmpty, true);

      final has3060 = rtxModels.any((c) => c.name == '3060');
      expect(has3060, true);

      db.close();
      await dir.delete(recursive: true);
    });

    test('GPU models filtered by category', () async {
      final dir = await Directory.systemTemp.createTemp('gpu_filter_test');
      final path = p.join(dir.path, 'gpu_filter_test.db');
      final db = await DatabaseService.open(path: path);
      final repo = InventoryRepository(db);

      final rtx = repo.choices('gpus').firstWhere((c) => c.name == 'RTX');
      final gtx = repo.choices('gpus').firstWhere((c) => c.name == 'GTX');

      final rtxModels = repo.choices('gpu_models', gpuId: rtx.id);
      final gtxModels = repo.choices('gpu_models', gpuId: gtx.id);

      for (final m in rtxModels) {
        expect(m.name, isNot(gtxModels.map((g) => g.name).contains(m.name)));
      }

      db.close();
      await dir.delete(recursive: true);
    });

    test('save inventory with GPU model', () async {
      final dir = await Directory.systemTemp.createTemp('gpu_save_test');
      final path = p.join(dir.path, 'gpu_save_test.db');
      final db = await DatabaseService.open(path: path);
      final repo = InventoryRepository(db);

      final brand = repo.addChoice('brands', 'GPU Test Brand');
      final model = repo.addChoice('models', 'GPU Test Model', brandId: brand);
      final cpu = repo.addChoice('cpus', 'GPU Test CPU');
      final rtx = repo.choices('gpus').firstWhere((c) => c.name == 'RTX');
      final gpuModel = repo.choices('gpu_models', gpuId: rtx.id).first;
      final screen = repo.addChoice('screen_sizes', '14" GPU');

      repo.save({
        'brand': brand,
        'model': model,
        'cpu': cpu,
        'gpu': gpuModel.id,
        'screen': screen,
        'touch': false,
        'convertible': false,
        'quantity': 3,
        'notes': '',
      });

      final items = repo.list();
      expect(items.length, 1);
      expect(items.first.gpuModelId, gpuModel.id);
      expect(items.first.gpu, isNotEmpty);

      db.close();
      await dir.delete(recursive: true);
    });
  });
}
