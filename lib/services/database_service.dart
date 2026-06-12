import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/content_source.dart';
import '../models/content_item.dart';
import 'logger_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  // БАГ #1 ИСПРАВЛЕН: мьютекс предотвращает одновременную инициализацию
  static bool _isInitializing = false;
  static final List<Completer<Database>> _initQueue = [];

  final LoggerService _logger = LoggerService.instance;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // БАГ #1 ИСПРАВЛЕН: если инициализация уже идёт — ждём её завершения
    if (_isInitializing) {
      final completer = Completer<Database>();
      _initQueue.add(completer);
      return completer.future;
    }

    _isInitializing = true;
    try {
      _database = await _initDB('furry_content.db');
      // Оповещаем всех ожидающих
      for (final c in _initQueue) {
        c.complete(_database);
      }
      _initQueue.clear();
      return _database!;
    } catch (e) {
      for (final c in _initQueue) {
        c.completeError(e);
      }
      _initQueue.clear();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // БАГ #3 ИСПРАВЛЕН: вся инициализация в одной транзакции
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE sources (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          type TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          isNsfw INTEGER NOT NULL DEFAULT 0,
          addedAt TEXT NOT NULL,
          lastParsed TEXT,
          parsedCount INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await txn.execute('''
        CREATE TABLE content (
          id TEXT PRIMARY KEY,
          sourceId TEXT NOT NULL,
          title TEXT NOT NULL,
          author TEXT,
          mediaUrl TEXT NOT NULL,
          thumbnailUrl TEXT,
          isGif INTEGER NOT NULL DEFAULT 0,
          isNsfw INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          isSaved INTEGER NOT NULL DEFAULT 0,
          postUrl TEXT
        )
      ''');

      await txn.execute('''
        CREATE TABLE shown_content (
          id TEXT PRIMARY KEY,
          shownAt TEXT NOT NULL
        )
      ''');

      await txn.execute('CREATE INDEX idx_content_created ON content(createdAt DESC)');
      await txn.execute('CREATE INDEX idx_content_saved ON content(isSaved)');
      await txn.execute('CREATE INDEX idx_sources_active ON sources(isActive)');
      // БАГ #2 ИСПРАВЛЕН: индекс для быстрой очистки старых записей
      await txn.execute('CREATE INDEX idx_shown_at ON shown_content(shownAt)');
    });

    await _insertDefaultSources(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE sources ADD COLUMN isNsfw INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE sources ADD COLUMN lastParsed TEXT');
        await db.execute('ALTER TABLE sources ADD COLUMN parsedCount INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        _logger.log('⚠️ Ошибка обновления схемы БД: $e', isError: false);
      }
    }
  }

  Future<void> _insertDefaultSources(Database db) async {
    final defaultSources = ContentSource.getDefaultSources();
    for (var source in defaultSources) {
      await db.insert('sources', source.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ── Sources ──────────────────────────────────────────────

  Future<List<ContentSource>> getSources() async {
    final db = await database;
    final maps = await db.query('sources', orderBy: 'addedAt DESC');
    return maps.map((map) => ContentSource.fromMap(map)).toList();
  }

  Future<void> insertSource(ContentSource source) async {
    final db = await database;
    await db.insert('sources', source.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSource(ContentSource source) async {
    final db = await database;
    await db.update('sources', source.toMap(),
        where: 'id = ?', whereArgs: [source.id]);
  }

  Future<void> deleteSource(String id) async {
    final db = await database;
    // БАГ #3 ИСПРАВЛЕН: атомарное удаление в транзакции
    await db.transaction((txn) async {
      await txn.delete('content', where: 'sourceId = ?', whereArgs: [id]);
      await txn.delete('sources', where: 'id = ?', whereArgs: [id]);
    });
  }

  // ── Content ──────────────────────────────────────────────

  Future<List<ContentItem>> getContent({
    bool onlyGifs = false,
    bool onlySaved = false,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <int>[];

    if (onlyGifs) { conditions.add('isGif = ?'); args.add(1); }
    if (onlySaved) { conditions.add('isSaved = ?'); args.add(1); }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final maps = await db.query(
      'content',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'createdAt DESC',
      limit: 1000,
    );
    return maps.map((map) => ContentItem.fromMap(map)).toList();
  }

  Future<void> insertContent(ContentItem item) async {
    final db = await database;
    await db.insert('content', item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateContent(ContentItem item) async {
    final db = await database;
    await db.update('content', item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<bool> contentExists(String id) async {
    final db = await database;
    final result = await db.query('content',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty;
  }

  // БАГ #4 ИСПРАВЛЕН: объединяем wasShown + contentExists в один запрос.
  // В ContentProvider заменить:
  //   final wasShown = await _db.wasShown(item.id);
  //   final exists  = await _db.contentExists(item.id);
  //   if (!wasShown && !exists) { ... }
  // На:
  //   if (!await _db.shouldSkip(item.id)) { ... }
  Future<bool> shouldSkip(String id) async {
    final db = await database;
    // Проверяем оба условия одним SQL-запросом через UNION
    final result = await db.rawQuery('''
      SELECT 1 FROM content WHERE id = ?
      UNION ALL
      SELECT 1 FROM shown_content WHERE id = ?
      LIMIT 1
    ''', [id, id]);
    return result.isNotEmpty;
  }

  Future<void> clearAllContent() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('content');
      await txn.delete('shown_content');
    });
  }

  // ── Shown content ─────────────────────────────────────────

  Future<void> markAsShown(String id) async {
    final db = await database;
    await db.insert(
      'shown_content',
      {'id': id, 'shownAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // БАГ #2 ИСПРАВЛЕН: чистим записи старше 30 дней при каждой записи
    _pruneShownContent(db);
  }

  void _pruneShownContent(Database db) {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    db.delete('shown_content', where: 'shownAt < ?', whereArgs: [cutoff]);
  }

  Future<bool> wasShown(String id) async {
    final db = await database;
    final result = await db.query('shown_content',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty;
  }
}
