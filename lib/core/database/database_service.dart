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

  void _migrate() {
    db.execute(
      '''CREATE TABLE IF NOT EXISTS schema_meta (version INTEGER NOT NULL)''',
    );
    if (db.select('SELECT * FROM schema_meta').isEmpty) {
      db.execute('INSERT INTO schema_meta VALUES (1)');
    }
    db.execute('''
      CREATE TABLE IF NOT EXISTS brands (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
      CREATE TABLE IF NOT EXISTS cpus (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
      CREATE TABLE IF NOT EXISTS gpus (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
      CREATE TABLE IF NOT EXISTS screen_sizes (id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
      CREATE TABLE IF NOT EXISTS models (id INTEGER PRIMARY KEY, brand_id INTEGER NOT NULL REFERENCES brands(id) ON DELETE RESTRICT, name TEXT NOT NULL COLLATE NOCASE, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(brand_id,name));
      CREATE TABLE IF NOT EXISTS laptop_inventory (id INTEGER PRIMARY KEY, brand_id INTEGER NOT NULL REFERENCES brands(id) ON DELETE RESTRICT, model_id INTEGER NOT NULL REFERENCES models(id) ON DELETE RESTRICT, cpu_id INTEGER NOT NULL REFERENCES cpus(id) ON DELETE RESTRICT, gpu_id INTEGER NOT NULL REFERENCES gpus(id) ON DELETE RESTRICT, screen_size_id INTEGER NOT NULL REFERENCES screen_sizes(id) ON DELETE RESTRICT, is_touch INTEGER NOT NULL CHECK(is_touch IN (0,1)), is_2_in_1 INTEGER NOT NULL CHECK(is_2_in_1 IN (0,1)), quantity INTEGER NOT NULL CHECK(quantity > 0), notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);
      CREATE INDEX IF NOT EXISTS idx_inventory_brand ON laptop_inventory(brand_id);
      CREATE INDEX IF NOT EXISTS idx_inventory_model ON laptop_inventory(model_id);
      CREATE INDEX IF NOT EXISTS idx_inventory_cpu ON laptop_inventory(cpu_id);
    ''');
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
  }

  void _seedTable(String table, List<String> values) {
    for (final value in values) {
      db.execute('INSERT OR IGNORE INTO $table(name) VALUES(?)', [value]);
    }
  }

  void close() {
    db.dispose();
    _instance = null;
  }
}
