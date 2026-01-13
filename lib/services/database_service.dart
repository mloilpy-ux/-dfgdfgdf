import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/content_source.dart';
import '../models/content_item.dart';
import 'logger_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  final LoggerService _logger = LoggerService.instance;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('furry_content.db');
    return _database!;
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
    await db.execute('''
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

    await db.execute('''
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

    await db.execute('''
      CREATE TABLE shown_content (
        id TEXT PRIMARY KEY,
        shownAt TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_content_created ON content(createdAt DESC)');
    await db.execute('CREATE INDEX idx_content_saved ON content(isSaved)');
    await db.execute('CREATE INDEX idx_sources_active ON sources(isActive)');

    await _insertDefaultSources(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE sources ADD COLUMN isNsfw INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE sources ADD COLUMN lastParsed TEXT');
        await db.execute('ALTER TABLE sources ADD COLUMN parsedCount INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        _logger.log('⚠️ Ошибка обновления БД: $e', isError: false);
      }
    }
  }

  Future<void> _insertDefaultSources(Database db) async {
    final defaultSources = ContentSource.getDefaultSources();
    for (var source in defaultSources) {
      await db.insert('sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<ContentSource>> getSources() async {
    final db = await database;
    final maps = await db.query('sources', orderBy: 'addedAt DESC');
    return maps.map((map) => ContentSource.fromMap(map)).toList();
  }

  Future<void> insertSource(ContentSource source) async {
    final db = await database;
    await db.insert('sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSource(ContentSource source) async {
    final db = await database;
    await db.update('sources', source.toMap(), where: 'id = ?', whereArgs: [source.id]);
  }

  Future<void> deleteSource(String id) async {
    final db = await database;
    await db.delete('content', where: 'sourceId = ?', whereArgs: [id]);
    await db.delete('sources', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ContentItem>> getContent({bool onlyGifs = false, bool onlySaved = false}) async {
    final db = await database;
    final conditions = <String>[];
    final args = <int>[];

    if (onlyGifs) {
      conditions.add('isGif = ?');
      args.add(1);
    }

    if (onlySaved) {
      conditions.add('isSaved = ?');
      args.add(1);
    }

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
    await db.insert('content', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateContent(ContentItem item) async {
    final db = await database;
    await db.update('content', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<bool> contentExists(String id) async {
    final db = await database;
    final result = await db.query('content', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty;
  }

  Future<void> clearAllContent() async {
    final db = await database;
    await db.delete('content');
    await db.delete('shown_content');
  }

  Future<void> markAsShown(String id) async {
    final db = await database;
    await db.insert(
      'shown_content',
      {'id': id, 'shownAt': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> wasShown(String id) async {
    final db = await database;
    final result = await db.query('shown_content', where: 'id = ?', whereArgs: [id], limit: 1);
    return result.isNotEmpty;
  }
}
