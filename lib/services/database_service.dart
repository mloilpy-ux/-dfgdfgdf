import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/content_item.dart';
import '../models/content_source.dart';

class DatabaseService {
  static final instance = DatabaseService();
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _opening;

  DatabaseService({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;

  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    try {
      final factory = _factory ?? databaseFactory;
      final path =
          _path ?? join(await factory.getDatabasesPath(), 'furry_content.db');
      return await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) async {
            await _createTables(db);
            for (final source in ContentSource.getDefaultSources()) {
              await db.insert('sources', source.toMap());
            }
          },
          onUpgrade: _upgrade,
        ),
      );
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sources (
        id TEXT PRIMARY KEY, name TEXT NOT NULL, url TEXT NOT NULL,
        type TEXT NOT NULL, isActive INTEGER NOT NULL DEFAULT 1,
        isNsfw INTEGER NOT NULL DEFAULT 0, addedAt TEXT NOT NULL,
        lastParsed TEXT, parsedCount INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS content (
        id TEXT PRIMARY KEY, sourceId TEXT NOT NULL, title TEXT NOT NULL,
        author TEXT, mediaUrl TEXT NOT NULL, thumbnailUrl TEXT,
        isGif INTEGER NOT NULL DEFAULT 0, mediaKind TEXT, isNsfw INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL, isSaved INTEGER NOT NULL DEFAULT 0, postUrl TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_content_created ON content(createdAt DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_content_saved ON content(isSaved)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_content_source ON content(sourceId)',
    );
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    await _createTables(db);
    final sourceColumns = (await db.rawQuery(
      'PRAGMA table_info(sources)',
    )).map((row) => row['name']).toSet();
    for (final entry in const {
      'isNsfw': 'INTEGER NOT NULL DEFAULT 0',
      'lastParsed': 'TEXT',
      'parsedCount': 'INTEGER NOT NULL DEFAULT 0',
    }.entries) {
      if (!sourceColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE sources ADD COLUMN ${entry.key} ${entry.value}',
        );
      }
    }
    final columns = await db.rawQuery('PRAGMA table_info(content)');
    if (!columns.any((row) => row['name'] == 'mediaKind')) {
      await db.execute('ALTER TABLE content ADD COLUMN mediaKind TEXT');
    }
    final telegram = ContentSource.defaultTelegramSource();
    final existing = await db.query('sources', columns: ['url']);
    if (!existing.any((row) {
      try {
        return ContentSource.fromUrl(row['url'] as String).url == telegram.url;
      } on FormatException {
        return false;
      }
    })) {
      await db.insert(
        'sources',
        telegram.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<List<ContentSource>> getSources() async {
    final db = await database;
    final rows = await db.query('sources', orderBy: 'addedAt DESC');
    return rows.map(ContentSource.fromMap).toList();
  }

  Future<ContentSource> insertSource(ContentSource source) async {
    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'sources',
        where: 'url = ?',
        whereArgs: [source.url],
        limit: 1,
      );
      if (existing.isNotEmpty) return ContentSource.fromMap(existing.single);
      await txn.insert('sources', source.toMap());
      return source;
    });
  }

  Future<void> setSourceActive(String id, bool active) async {
    final db = await database;
    await db.update(
      'sources',
      {'isActive': active ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSource(String id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('content', where: 'sourceId = ?', whereArgs: [id]);
      await txn.delete('sources', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<ContentItem>> getContent({
    bool onlySaved = false,
    bool onlyActive = false,
  }) async {
    final db = await database;
    final where = onlySaved
        ? 'isSaved = 1'
        : onlyActive
        ? 'sourceId IN (SELECT id FROM sources WHERE isActive = 1)'
        : null;
    final rows = await db.query(
      'content',
      where: where,
      orderBy: 'createdAt DESC',
    );
    return rows.map(ContentItem.fromMap).toList();
  }

  Future<int> importContent(
    ContentSource source,
    List<ContentItem> items,
  ) async {
    final db = await database;
    return db.transaction((txn) async {
      final active = await txn.query(
        'sources',
        columns: ['id'],
        where: 'id = ? AND isActive = 1',
        whereArgs: [source.id],
        limit: 1,
      );
      if (active.isEmpty) throw StateError('Источник выключен или удалён');

      var added = 0;
      for (final item in items) {
        final values = item.toMap();
        final existing = await txn.query(
          'content',
          columns: ['isSaved'],
          where: 'id = ? AND sourceId = ?',
          whereArgs: [item.id, source.id],
          limit: 1,
        );
        if (existing.isEmpty) {
          final idCollision = await txn.query(
            'content',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [item.id],
            limit: 1,
          );
          if (idCollision.isNotEmpty) continue;
          await txn.insert('content', values);
          added++;
        } else {
          values.remove('isSaved');
          await txn.update(
            'content',
            values,
            where: 'id = ? AND sourceId = ?',
            whereArgs: [item.id, source.id],
          );
        }
      }

      await txn.rawUpdate(
        'UPDATE sources SET lastParsed = ?, parsedCount = parsedCount + 1 WHERE id = ?',
        [DateTime.now().toIso8601String(), source.id],
      );
      return added;
    });
  }

  Future<void> setSaved(String id, bool saved) async {
    final db = await database;
    await db.update(
      'content',
      {'isSaved': saved ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearAllContent() async {
    final db = await database;
    await db.delete('content');
  }
}
