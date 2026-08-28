import '../../../core/database/database_service.dart';

class Choice {
  const Choice(this.id, this.name);
  final int id;
  final String name;
  factory Choice.from(Map<String, Object?> r) =>
      Choice(r['id'] as int, r['name'] as String);
}

class InventoryItem {
  InventoryItem(
    this.id,
    this.brandId,
    this.modelId,
    this.cpuId,
    this.gpuId,
    this.screenId,
    this.brand,
    this.model,
    this.cpu,
    this.gpu,
    this.screen,
    this.touch,
    this.convertible,
    this.quantity,
    this.notes,
    this.createdAt,
  );
  final int id, brandId, modelId, cpuId, gpuId, screenId, quantity;
  final String brand, model, cpu, gpu, screen, notes, createdAt;
  final bool touch, convertible;
  factory InventoryItem.from(Map<String, Object?> r) => InventoryItem(
    r['id'] as int,
    r['brand_id'] as int,
    r['model_id'] as int,
    r['cpu_id'] as int,
    r['gpu_id'] as int,
    r['screen_size_id'] as int,
    r['brand'] as String,
    r['model'] as String,
    r['cpu'] as String,
    r['gpu'] as String,
    r['screen'] as String,
    (r['is_touch'] as int) == 1,
    (r['is_2_in_1'] as int) == 1,
    r['quantity'] as int,
    r['notes'] as String,
    r['created_at'] as String,
  );
}

class InventoryRepository {
  InventoryRepository(this.service);
  final DatabaseService service;
  List<Choice> choices(String table, {int? brandId, String search = ''}) {
    final where = table == 'models'
        ? 'brand_id = ? AND name LIKE ?'
        : 'name LIKE ?';
    final args = table == 'models'
        ? [brandId ?? -1, '%$search%']
        : ['%$search%'];

    final items = service.db
        .select('SELECT id,name FROM $table WHERE $where ORDER BY name', args)
        .map((x) => Choice.from(x))
        .toList();

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  int addChoice(String table, String name, {int? brandId}) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Name is required');
    try {
      service.db.execute(
        table == 'models'
            ? 'INSERT INTO models(brand_id,name) VALUES(?,?)'
            : 'INSERT INTO $table(name) VALUES(?)',
        table == 'models' ? [brandId, n] : [n],
      );
      return service.db.lastInsertRowId;
    } catch (_) {
      throw StateError('This value already exists');
    }
  }

  void updateChoice(String table, Choice choice, String name) {
    try {
      service.db.execute('UPDATE $table SET name=? WHERE id=?', [
        name.trim(),
        choice.id,
      ]);
    } catch (_) {
      throw StateError('Could not save value. It may duplicate another value.');
    }
  }

  void deleteChoice(String table, int id) {
    try {
      service.db.execute('DELETE FROM $table WHERE id=?', [id]);
    } catch (_) {
      throw StateError(
        'This value is used by inventory and cannot be deleted.',
      );
    }
  }

  List<InventoryItem> list({String search = '', int? brandId}) {
    final q =
        '''SELECT i.*, b.name brand,m.name model,c.name cpu,g.name gpu,s.name screen FROM laptop_inventory i JOIN brands b ON b.id=i.brand_id JOIN models m ON m.id=i.model_id JOIN cpus c ON c.id=i.cpu_id JOIN gpus g ON g.id=i.gpu_id JOIN screen_sizes s ON s.id=i.screen_size_id WHERE (?='' OR b.name LIKE ? OR m.name LIKE ? OR c.name LIKE ? OR g.name LIKE ?) AND (? IS NULL OR i.brand_id=?) ORDER BY i.created_at DESC''';
    return service.db
        .select(q, [
          search,
          '%$search%',
          '%$search%',
          '%$search%',
          '%$search%',
          brandId,
          brandId,
        ])
        .map((r) => InventoryItem.from(r))
        .toList();
  }

  InventoryItem? duplicate(Map<String, dynamic> v, {int? except}) {
    final r = service.db.select(
      'SELECT i.*,b.name brand,m.name model,c.name cpu,g.name gpu,s.name screen FROM laptop_inventory i JOIN brands b ON b.id=i.brand_id JOIN models m ON m.id=i.model_id JOIN cpus c ON c.id=i.cpu_id JOIN gpus g ON g.id=i.gpu_id JOIN screen_sizes s ON s.id=i.screen_size_id WHERE brand_id=? AND model_id=? AND cpu_id=? AND gpu_id=? AND screen_size_id=? AND is_touch=? AND is_2_in_1=? AND (? IS NULL OR i.id != ?) LIMIT 1',
      [
        v['brand'],
        v['model'],
        v['cpu'],
        v['gpu'],
        v['screen'],
        v['touch'] ? 1 : 0,
        v['convertible'] ? 1 : 0,
        except,
        except,
      ],
    );
    return r.isEmpty ? null : InventoryItem.from(r.first);
  }

  void save(Map<String, dynamic> v, {int? id, bool merge = false}) {
    service.db.execute('BEGIN');
    try {
      final existing = duplicate(v, except: id);
      if (existing != null && merge) {
        service.db.execute(
          'UPDATE laptop_inventory SET quantity=quantity+?,updated_at=CURRENT_TIMESTAMP WHERE id=?',
          [v['quantity'], existing.id],
        );
      } else if (id == null) {
        service.db.execute(
          'INSERT INTO laptop_inventory(brand_id,model_id,cpu_id,gpu_id,screen_size_id,is_touch,is_2_in_1,quantity,notes) VALUES(?,?,?,?,?,?,?,?,?)',
          [
            v['brand'],
            v['model'],
            v['cpu'],
            v['gpu'],
            v['screen'],
            v['touch'] ? 1 : 0,
            v['convertible'] ? 1 : 0,
            v['quantity'],
            v['notes'],
          ],
        );
      } else {
        service.db.execute(
          'UPDATE laptop_inventory SET brand_id=?,model_id=?,cpu_id=?,gpu_id=?,screen_size_id=?,is_touch=?,is_2_in_1=?,quantity=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',
          [
            v['brand'],
            v['model'],
            v['cpu'],
            v['gpu'],
            v['screen'],
            v['touch'] ? 1 : 0,
            v['convertible'] ? 1 : 0,
            v['quantity'],
            v['notes'],
            id,
          ],
        );
      }
      service.db.execute('COMMIT');
    } catch (e) {
      service.db.execute('ROLLBACK');
      rethrow;
    }
  }

  void delete(int id) =>
      service.db.execute('DELETE FROM laptop_inventory WHERE id=?', [id]);
  int total(String expression) =>
      service.db
              .select('SELECT $expression value FROM laptop_inventory')
              .first['value']
          as int? ??
      0;
  List<Map<String, Object?>> report(String field) => service.db.select(
    '''SELECT $field name,SUM(i.quantity) quantity FROM laptop_inventory i JOIN brands b ON b.id=i.brand_id JOIN models m ON m.id=i.model_id JOIN cpus c ON c.id=i.cpu_id JOIN gpus g ON g.id=i.gpu_id GROUP BY $field ORDER BY quantity DESC''',
  ).toList();
}
