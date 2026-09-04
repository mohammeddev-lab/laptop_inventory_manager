import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseService {
  DatabaseService._(this.db);
  final Database db;
  static DatabaseService? _instance;

  static Future<DatabaseService> open({String? path}) async {
    if (_instance != null) return _instance!;
    final file =
        path ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'laptop_inventory.db',
        );
    Directory(p.dirname(file)).createSync(recursive: true);
    final db = sqlite3.open(file);
    db.execute('PRAGMA foreign_keys = ON');
    final service = DatabaseService._(db);
    service._migrate();
    service._seed();
    _instance = service;
    return service;
  }

  int _schemaVersion() {
    final rows = db.select(
      'SELECT version FROM schema_meta ORDER BY rowid DESC LIMIT 1',
    );
    return (rows.isEmpty ? 0 : rows.first['version'] as int? ?? 0);
  }

  bool _hasColumn(String table, String column) {
    final rows = db.select("PRAGMA table_info('$table')");
    return rows.any((row) => row['name'] == column);
  }

  bool _tableExists(String table) {
    final rows = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [table],
    );
    return rows.isNotEmpty;
  }

  void _ensureTable(String name, String createSql) {
    if (!_tableExists(name)) {
      _execute(createSql);
      return;
    }
    final requiredColumns = _requiredColumns[name];
    if (requiredColumns != null) {
      for (final col in requiredColumns) {
        if (!_hasColumn(name, col)) {
          // Table is corrupted. Disable foreign keys, drop, recreate, re-enable.
          _execute('PRAGMA foreign_keys = OFF');
          _execute('DROP TABLE IF EXISTS $name');
          _execute(createSql);
          _execute('PRAGMA foreign_keys = ON');
          return;
        }
      }
    }
  }

  static const _requiredColumns = <String, List<String>>{
    'inventory_sessions': ['id', 'name', 'date', 'status', 'created_at', 'updated_at'],
    'laptop_inventory': ['id', 'brand_id', 'model_id', 'cpu_id', 'gpu_model_id', 'screen_size_id', 'is_touch', 'is_2_in_1', 'quantity', 'notes', 'created_at', 'updated_at', 'session_id'],
    'brands': ['id', 'name'],
    'cpus': ['id', 'name'],
    'cpu_generations': ['id', 'name'],
    'cpu_classes': ['id', 'name'],
    'gpus': ['id', 'name'],
    'gpu_models': ['id', 'gpu_id', 'name'],
    'screen_sizes': ['id', 'name'],
    'models': ['id', 'brand_id', 'name'],
  };

  void _execute(String sql, [List<Object?> params = const []]) {
    db.execute(sql, params);
  }

  void _migrate() {
    _execute('CREATE TABLE IF NOT EXISTS schema_meta (version INTEGER NOT NULL)');
    if (db.select('SELECT * FROM schema_meta').isEmpty) {
      _execute('INSERT INTO schema_meta VALUES (1)');
    }

    _ensureTable('brands',
      'CREATE TABLE brands (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    _ensureTable('cpus',
      'CREATE TABLE cpus (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    _ensureTable('gpus',
      'CREATE TABLE gpus (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    _ensureTable('gpu_models',
      'CREATE TABLE gpu_models (id INTEGER PRIMARY KEY, gpu_id INTEGER NOT NULL REFERENCES gpus(id) ON DELETE RESTRICT, name TEXT NOT NULL COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(gpu_id,name))');
    _ensureTable('screen_sizes',
      'CREATE TABLE screen_sizes (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    _ensureTable('models',
      'CREATE TABLE models (id INTEGER PRIMARY KEY, brand_id INTEGER NOT NULL REFERENCES brands(id) ON DELETE RESTRICT, name TEXT NOT NULL COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(brand_id,name))');
    _ensureTable('inventory_sessions',
      "CREATE TABLE inventory_sessions (id INTEGER PRIMARY KEY, name TEXT NOT NULL DEFAULT '', date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'جاري', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, completed_at TEXT)");
    _ensureTable('laptop_inventory',
      "CREATE TABLE laptop_inventory (id INTEGER PRIMARY KEY, brand_id INTEGER NOT NULL REFERENCES brands(id) ON DELETE RESTRICT, model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE RESTRICT, cpu_id INTEGER NOT NULL REFERENCES cpus(id) ON DELETE RESTRICT, gpu_model_id INTEGER NOT NULL REFERENCES gpu_models(id) ON DELETE RESTRICT, screen_size_id INTEGER NOT NULL REFERENCES screen_sizes(id) ON DELETE RESTRICT, is_touch INTEGER NOT NULL CHECK(is_touch IN (0,1)), is_2_in_1 INTEGER NOT NULL CHECK(is_2_in_1 IN (0,1)), quantity INTEGER NOT NULL CHECK(quantity >= 0), notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, session_id INTEGER REFERENCES inventory_sessions(id))");

    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_brand ON laptop_inventory(brand_id)');
    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_model ON laptop_inventory(model_id)');
    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_cpu ON laptop_inventory(cpu_id)');
    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_session ON laptop_inventory(session_id)');

    final version = _schemaVersion();
    if (version < 2) {
      final hasSession =
          db
                  .select('SELECT COUNT(*) AS count FROM inventory_sessions')
                  .first['count']
              as int? ??
          0;
      if (hasSession == 0) {
        _execute(
          "INSERT INTO inventory_sessions(name, date, status, created_at, updated_at) VALUES('جرد افتراضي', date('now'), 'جاري', datetime('now'), datetime('now'))",
        );
      }

      final fallbackId = db
          .select('SELECT id FROM inventory_sessions ORDER BY id DESC LIMIT 1')
          .firstOrNull;
      final targetSessionId = fallbackId == null
          ? null
          : fallbackId['id'] as int?;

      if (targetSessionId != null) {
        _execute(
          'UPDATE laptop_inventory SET session_id=? WHERE session_id IS NULL',
          [targetSessionId],
        );
      }

      _execute(
        'UPDATE schema_meta SET version = 2 WHERE rowid = (SELECT MAX(rowid) FROM schema_meta)',
      );
    }

    if (version < 3) {
      _migrateV3();
      _execute(
        'UPDATE schema_meta SET version = 3 WHERE rowid = (SELECT MAX(rowid) FROM schema_meta)',
      );
    }

    if (version < 4) {
      _migrateV4();
      _execute(
        'UPDATE schema_meta SET version = 4 WHERE rowid = (SELECT MAX(rowid) FROM schema_meta)',
      );
    }

    if (version < 5) {
      _migrateV5();
      _execute(
        'UPDATE schema_meta SET version = 5 WHERE rowid = (SELECT MAX(rowid) FROM schema_meta)',
      );
    }
  }

  void _migrateV3() {
    final hasLenovo =
        db.select('SELECT id FROM brands WHERE name = ?', ['Lenovo']).isNotEmpty;
    if (!hasLenovo) {
      _execute('INSERT OR IGNORE INTO brands(name) VALUES(?)', ['Lenovo']);
    }

    final lenovoRow =
        db.select('SELECT id FROM brands WHERE name = ?', ['Lenovo']);
    if (lenovoRow.isNotEmpty) {
      final lenovoId = lenovoRow.first['id'] as int;
      final hasThinkPad =
          db
                  .select(
                    'SELECT id FROM models WHERE brand_id = ? AND name = ?',
                    [lenovoId, 'ThinkPad 320'],
                  )
                  .isNotEmpty;
      if (!hasThinkPad) {
        _execute(
          'INSERT OR IGNORE INTO models(brand_id, name) VALUES(?, ?)',
          [lenovoId, 'ThinkPad 320'],
        );
      }
    }
  }

  void _migrateV4() {
    if (!_tableExists('laptop_inventory')) return;
    if (!_hasColumn('laptop_inventory', 'gpu_id')) return;
    if (_hasColumn('laptop_inventory', 'gpu_model_id')) return;

    _ensureTable('gpu_models',
      'CREATE TABLE gpu_models (id INTEGER PRIMARY KEY, gpu_id INTEGER NOT NULL REFERENCES gpus(id) ON DELETE RESTRICT, name TEXT NOT NULL COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(gpu_id,name))');

    final gpuCategories = db.select('SELECT id, name FROM gpus');
    final gpuModelMap = <int, int>{};
    for (final cat in gpuCategories) {
      final catId = cat['id'] as int;
      final catName = cat['name'] as String;
      final existing = db.select(
        'SELECT id FROM gpu_models WHERE gpu_id = ? AND name = ?',
        [catId, catName],
      );
      if (existing.isNotEmpty) {
        gpuModelMap[catId] = existing.first['id'] as int;
      } else {
        _execute(
          'INSERT INTO gpu_models(gpu_id, name) VALUES(?, ?)',
          [catId, catName],
        );
        gpuModelMap[catId] = db.lastInsertRowId;
      }
    }

    _execute('ALTER TABLE laptop_inventory ADD COLUMN gpu_model_id INTEGER REFERENCES gpu_models(id)');

    final items = db.select('SELECT id, gpu_id FROM laptop_inventory');
    for (final item in items) {
      final oldGpuId = item['gpu_id'] as int?;
      if (oldGpuId != null && gpuModelMap.containsKey(oldGpuId)) {
        _execute(
          'UPDATE laptop_inventory SET gpu_model_id = ? WHERE id = ?',
          [gpuModelMap[oldGpuId], item['id']],
        );
      }
    }

    _execute('PRAGMA foreign_keys = OFF');
    _execute('ALTER TABLE laptop_inventory RENAME TO laptop_inventory_old');
    _execute(
      "CREATE TABLE laptop_inventory (id INTEGER PRIMARY KEY, brand_id INTEGER NOT NULL REFERENCES brands(id) ON DELETE RESTRICT, model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE RESTRICT, cpu_id INTEGER NOT NULL REFERENCES cpus(id) ON DELETE RESTRICT, gpu_model_id INTEGER NOT NULL REFERENCES gpu_models(id) ON DELETE RESTRICT, screen_size_id INTEGER NOT NULL REFERENCES screen_sizes(id) ON DELETE RESTRICT, is_touch INTEGER NOT NULL CHECK(is_touch IN (0,1)), is_2_in_1 INTEGER NOT NULL CHECK(is_2_in_1 IN (0,1)), quantity INTEGER NOT NULL CHECK(quantity >= 0), notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, session_id INTEGER REFERENCES inventory_sessions(id))",
    );
    _execute(
      'INSERT INTO laptop_inventory(id, brand_id, model_id, cpu_id, gpu_model_id, screen_size_id, is_touch, is_2_in_1, quantity, notes, created_at, updated_at, session_id) SELECT id, brand_id, model_id, cpu_id, gpu_model_id, screen_size_id, is_touch, is_2_in_1, quantity, notes, created_at, updated_at, session_id FROM laptop_inventory_old',
    );
    _execute('DROP TABLE laptop_inventory_old');
    _execute('PRAGMA foreign_keys = ON');

    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_brand ON laptop_inventory(brand_id)');
    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_model ON laptop_inventory(model_id)');
    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_cpu ON laptop_inventory(cpu_id)');
    _execute('CREATE INDEX IF NOT EXISTS idx_inventory_session ON laptop_inventory(session_id)');
  }

  void _migrateV5() {
    _ensureTable('cpu_generations',
      'CREATE TABLE cpu_generations (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');
    _ensureTable('cpu_classes',
      'CREATE TABLE cpu_classes (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)');

    if (_tableExists('laptop_inventory') && !_hasColumn('laptop_inventory', 'cpu_generation_id')) {
      _execute('ALTER TABLE laptop_inventory ADD COLUMN cpu_generation_id INTEGER REFERENCES cpu_generations(id)');
    }
    if (_tableExists('laptop_inventory') && !_hasColumn('laptop_inventory', 'cpu_class_id')) {
      _execute('ALTER TABLE laptop_inventory ADD COLUMN cpu_class_id INTEGER REFERENCES cpu_classes(id)');
    }

    _seedTable('cpu_generations', [
      '4th', '5th', '6th', '7th', '8th', '9th', '10th',
      '11th', '12th', '13th', '14th',
    ]);
    _seedTable('cpu_classes', [
      'U', 'H', 'HQ', 'HK', 'P', 'M', 'Y', 'HX',
    ]);
  }

  void _seed() {
    _seedTable('brands', [
      'HP',
      'Lenovo',
      'Acer',
      'Dell',
      'Asus',
      'Apple',
      'MSI',
      'Other',
    ]);
    _seedModels('Lenovo', ['ThinkPad 320']);
    _seedTable('cpus', [
      'i3',
      'i5',
      'i7',
      'i9',
      'R3',
      'R5',
      'R7',
      'R7 Pro',
      'Ultra 5',
      'Ultra 7',
      'Ultra 9',
    ]);
    _seedTable('gpus', ['RTX', 'GTX', 'Quadro', 'Share', 'Other']);
    _seedGpuModels('RTX', ['3050', '3060', '3070', '3080', '4050', '4060', '4070', '4080', '4090']);
    _seedGpuModels('GTX', ['1650', '1660', '1050', '1060', '1070', '1080']);
    _seedGpuModels('Quadro', ['T1000', 'T2000', 'RTX 3000', 'RTX 4000', 'RTX 5000']);
    _seedTable('screen_sizes', [
      '11.6"',
      '12.5"',
      '13.3"',
      '14"',
      '15.6"',
      '16"',
      '17.3"',
      'Other',
    ]);

    final sessions = db.select(
      'SELECT COUNT(*) AS count FROM inventory_sessions',
    );
    final count = sessions.first['count'] as int? ?? 0;
    if (count == 0) {
      db.execute(
        "INSERT INTO inventory_sessions(name, date, status, created_at, updated_at) VALUES('جرد افتراضي', date('now'), 'جاري', datetime('now'), datetime('now'))",
      );
    }
  }

  void _seedTable(String table, List<String> values) {
    for (final value in values) {
      db.execute('INSERT OR IGNORE INTO $table(name) VALUES(?)', [value]);
    }
  }

  void _seedModels(String brandName, List<String> modelNames) {
    final brandRow = db.select(
      'SELECT id FROM brands WHERE name = ?',
      [brandName],
    );
    if (brandRow.isEmpty) return;
    final brandId = brandRow.first['id'] as int;
    for (final name in modelNames) {
      db.execute(
        'INSERT OR IGNORE INTO models(brand_id, name) VALUES(?, ?)',
        [brandId, name],
      );
    }
  }

  void _seedGpuModels(String categoryName, List<String> modelNames) {
    final catRow = db.select(
      'SELECT id FROM gpus WHERE name = ?',
      [categoryName],
    );
    if (catRow.isEmpty) return;
    final catId = catRow.first['id'] as int;
    for (final name in modelNames) {
      db.execute(
        'INSERT OR IGNORE INTO gpu_models(gpu_id, name) VALUES(?, ?)',
        [catId, name],
      );
    }
  }

  void close() {
    db.dispose();
    _instance = null;
  }
}
