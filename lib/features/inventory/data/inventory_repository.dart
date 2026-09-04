import '../../../core/database/database_service.dart';

class Choice {
  const Choice(this.id, this.name);
  final int id;
  final String name;
  factory Choice.from(Map<String, Object?> r) =>
      Choice(r['id'] as int, r['name'] as String);
}

class InventorySession {
  const InventorySession({
    required this.id,
    required this.name,
    required this.date,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  final int id;
  final String name;
  final DateTime date;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  factory InventorySession.from(Map<String, Object?> row) => InventorySession(
    id: row['id'] as int,
    name: row['name'] as String? ?? 'جرد',
    date: DateTime.parse(row['date'] as String),
    status: row['status'] as String? ?? 'جاري',
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
    completedAt: row['completed_at'] == null
        ? null
        : DateTime.parse(row['completed_at'] as String),
  );
}

class InventorySummary {
  const InventorySummary({
    required this.totalDevices,
    required this.totalQuantity,
    required this.matched,
    required this.mismatched,
    required this.companyCount,
    required this.modelCount,
    required this.defectCount,
  });

  final int totalDevices;
  final int totalQuantity;
  final int matched;
  final int mismatched;
  final int companyCount;
  final int modelCount;
  final int defectCount;
}

class InventoryItem {
  InventoryItem(
    this.id,
    this.brandId,
    this.modelId,
    this.cpuId,
    this.gpuModelId,
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
    this.sessionId,
  );
  final int id, brandId, modelId, cpuId, gpuModelId, screenId, quantity, sessionId;
  final String brand, model, cpu, gpu, screen, notes, createdAt;
  final bool touch, convertible;
  factory InventoryItem.from(Map<String, Object?> r) => InventoryItem(
    r['id'] as int,
    r['brand_id'] as int,
    r['model_id'] as int,
    r['cpu_id'] as int,
    r['gpu_model_id'] as int,
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
    (r['session_id'] as int?) ?? 0,
  );
}

class InventoryRepository {
  InventoryRepository(this.service);
  final DatabaseService service;

  static const _allowedReportFields = <String>{
    'b.name',
    'm.name',
    'c.name',
    'g.name',
    'gm.name',
    's.name',
  };

  static const _allowedTotalExpressions = <String>{
    'SUM(quantity)',
    'COUNT(*)',
  };

  InventorySession? currentSession() {
    final row = service.db.select(
      'SELECT * FROM inventory_sessions WHERE status = ? ORDER BY date DESC, id DESC LIMIT 1',
      ['جاري'],
    ).firstOrNull;
    return row == null ? null : InventorySession.from(row);
  }

  InventorySession createSession({String? name, DateTime? date}) {
    final now = DateTime.now();
    final sessionDate = (date ?? now);
    final sessionName = (name ?? '').trim();
    final current = currentSession();
    if (current != null) {
      service.db.execute(
        'UPDATE inventory_sessions SET status = ?, completed_at = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
        ['مكتمل', now.toIso8601String(), current.id],
      );
    }

    final finalName = sessionName.isEmpty
        ? 'جرد ${sessionDate.day}/${sessionDate.month}/${sessionDate.year}'
        : sessionName;

    service.db.execute(
      'INSERT INTO inventory_sessions(name, date, status, created_at, updated_at) VALUES(?,?,?,?,?)',
      [
        finalName,
        sessionDate.toIso8601String().substring(0, 10),
        'جاري',
        now.toIso8601String(),
        now.toIso8601String(),
      ],
    );

    final id = service.db.lastInsertRowId;
    final row = service.db.select(
      'SELECT * FROM inventory_sessions WHERE id = ?',
      [id],
    ).first;
    return InventorySession.from(row);
  }

  List<InventorySession> listSessions() => service.db
      .select('SELECT * FROM inventory_sessions ORDER BY date DESC, id DESC')
      .map(InventorySession.from)
      .toList();

  InventorySession ensureSession(int? sessionId) {
    if (sessionId != null) {
      final row = service.db.select(
        'SELECT * FROM inventory_sessions WHERE id = ?',
        [sessionId],
      ).firstOrNull;
      if (row != null) return InventorySession.from(row);
    }
    final current = currentSession();
    if (current != null) return current;
    return createSession();
  }

  void finishSession(int sessionId) {
    service.db.execute(
      'UPDATE inventory_sessions SET status = ?, completed_at = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?',
      ['مكتمل', DateTime.now().toIso8601String(), sessionId],
    );
  }

  List<Choice> choices(String table, {int? brandId, int? gpuId, String search = ''}) {
    String where;
    List<Object?> args;
    if (table == 'models') {
      where = 'brand_id = ? AND name LIKE ?';
      args = [brandId ?? -1, '%$search%'];
    } else if (table == 'gpu_models') {
      where = 'gpu_id = ? AND name LIKE ?';
      args = [gpuId ?? -1, '%$search%'];
    } else {
      where = 'name LIKE ?';
      args = ['%$search%'];
    }

    final items = service.db
        .select('SELECT id,name FROM $table WHERE $where ORDER BY name', args)
        .map((x) => Choice.from(x))
        .toList();

    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  int addChoice(String table, String name, {int? brandId, int? gpuId}) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Name is required');
    if (n.length > 100) throw ArgumentError('Name must be 100 characters or fewer');
    try {
      if (table == 'models') {
        service.db.execute(
          'INSERT INTO models(brand_id,name) VALUES(?,?)',
          [brandId, n],
        );
      } else if (table == 'gpu_models') {
        service.db.execute(
          'INSERT INTO gpu_models(gpu_id,name) VALUES(?,?)',
          [gpuId, n],
        );
      } else {
        service.db.execute(
          'INSERT INTO $table(name) VALUES(?)',
          [n],
        );
      }
      return service.db.lastInsertRowId;
    } catch (_) {
      throw StateError('This value already exists');
    }
  }

  void updateChoice(String table, Choice choice, String name) {
    final n = name.trim();
    if (n.isEmpty) throw ArgumentError('Name is required');
    if (n.length > 100) throw ArgumentError('Name must be 100 characters or fewer');
    try {
      service.db.execute('UPDATE $table SET name=? WHERE id=?', [n, choice.id]);
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

  static const _itemJoinSql =
      'SELECT i.*, b.name brand,m.name model,c.name cpu,gm.name gpu,s.name screen '
      'FROM laptop_inventory i '
      'JOIN brands b ON b.id=i.brand_id '
      'JOIN models m ON m.id=i.model_id '
      'JOIN cpus c ON c.id=i.cpu_id '
      'JOIN gpu_models gm ON gm.id=i.gpu_model_id '
      'JOIN screen_sizes s ON s.id=i.screen_size_id';

  List<InventoryItem> list({String search = '', int? brandId, int? sessionId}) {
    final targetSession = ensureSession(sessionId);
    final q =
        '$_itemJoinSql WHERE i.session_id = ? AND (?=\'\' OR b.name LIKE ? OR m.name LIKE ? OR c.name LIKE ? OR gm.name LIKE ?) AND (? IS NULL OR i.brand_id=?) ORDER BY i.created_at DESC';
    return service.db
        .select(q, [
          targetSession.id,
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

  InventoryItem? duplicate(
    Map<String, dynamic> v, {
    int? except,
    int? sessionId,
  }) {
    final targetSession = ensureSession(sessionId);
    final r = service.db.select(
      '$_itemJoinSql WHERE i.session_id=? AND i.brand_id=? AND i.model_id=? AND i.cpu_id=? AND i.gpu_model_id=? AND i.screen_size_id=? AND i.is_touch=? AND i.is_2_in_1=? AND (? IS NULL OR i.id != ?) LIMIT 1',
      [
        targetSession.id,
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

  void save(
    Map<String, dynamic> v, {
    int? id,
    bool merge = false,
    int? sessionId,
  }) {
    final targetSession = ensureSession(sessionId);
    service.db.execute('BEGIN');
    try {
      final existing = duplicate(v, except: id, sessionId: targetSession.id);
      if (existing != null) {
        if (merge) {
          service.db.execute(
            'UPDATE laptop_inventory SET quantity=quantity+?,updated_at=CURRENT_TIMESTAMP WHERE id=?',
            [v['quantity'], existing.id],
          );
        } else if (id == null) {
          service.db.execute(
            'UPDATE laptop_inventory SET brand_id=?,model_id=?,cpu_id=?,gpu_model_id=?,screen_size_id=?,is_touch=?,is_2_in_1=?,quantity=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',
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
              existing.id,
            ],
          );
        } else {
          throw StateError(
            'An item with the same specifications already exists in this session',
          );
        }
      } else if (id == null) {
        service.db.execute(
          'INSERT INTO laptop_inventory(brand_id,model_id,cpu_id,gpu_model_id,screen_size_id,is_touch,is_2_in_1,quantity,notes,session_id) VALUES(?,?,?,?,?,?,?,?,?,?)',
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
            targetSession.id,
          ],
        );
      } else {
        service.db.execute(
          'UPDATE laptop_inventory SET brand_id=?,model_id=?,cpu_id=?,gpu_model_id=?,screen_size_id=?,is_touch=?,is_2_in_1=?,quantity=?,notes=?,updated_at=CURRENT_TIMESTAMP WHERE id=?',
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

  int total(String expression, {int? sessionId}) {
    if (!_allowedTotalExpressions.contains(expression)) {
      throw ArgumentError('Invalid expression: $expression');
    }
    final targetSession = ensureSession(sessionId);
    final rows = service.db.select(
      'SELECT $expression value FROM laptop_inventory WHERE session_id = ?',
      [targetSession.id],
    );
    return (rows.firstOrNull?['value'] as int?) ?? 0;
  }

  InventorySummary summary({int? sessionId}) {
    final targetSession = ensureSession(sessionId);
    final rows = service.db.select(
      '''
      SELECT
        COUNT(*) total_devices,
        COALESCE(SUM(quantity),0) total_quantity,
        SUM(CASE WHEN quantity > 0 THEN 1 ELSE 0 END) matched,
        SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END) mismatched,
        COUNT(DISTINCT brand_id) company_count,
        COUNT(DISTINCT model_id) model_count,
        SUM(CASE WHEN notes <> '' THEN 1 ELSE 0 END) defect_count
      FROM laptop_inventory
      WHERE session_id = ?
      ''',
      [targetSession.id],
    );
    final row = rows.first;
    return InventorySummary(
      totalDevices: (row['total_devices'] as int?) ?? 0,
      totalQuantity: (row['total_quantity'] as int?) ?? 0,
      matched: (row['matched'] as int?) ?? 0,
      mismatched: (row['mismatched'] as int?) ?? 0,
      companyCount: (row['company_count'] as int?) ?? 0,
      modelCount: (row['model_count'] as int?) ?? 0,
      defectCount: (row['defect_count'] as int?) ?? 0,
    );
  }

  List<Map<String, Object?>> report(String field, {int? sessionId}) {
    if (!_allowedReportFields.contains(field)) {
      throw ArgumentError('Invalid report field: $field');
    }
    final targetSession = ensureSession(sessionId);
    return service.db
        .select(
          '''SELECT $field name,SUM(i.quantity) quantity FROM laptop_inventory i JOIN brands b ON b.id=i.brand_id JOIN models m ON m.id=i.model_id JOIN cpus c ON c.id=i.cpu_id JOIN gpu_models gm ON gm.id=i.gpu_model_id JOIN gpus g ON g.id=gm.gpu_id JOIN screen_sizes s ON s.id=i.screen_size_id WHERE i.session_id = ? GROUP BY $field ORDER BY quantity DESC''',
          [targetSession.id],
        )
        .toList();
  }
}
