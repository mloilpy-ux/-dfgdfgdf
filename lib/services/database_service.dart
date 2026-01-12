import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/content_source.dart';
import '../models/content_item.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sources (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        type TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        addedAt TEXT NOT NULL
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
        isGif INTEGER NOT NULL,
        isNsfw INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        isSaved INTEGER NOT NULL,
        postUrl TEXT,
        FOREIGN KEY (sourceId) REFERENCES sources (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE shown_content (
        id TEXT PRIMARY KEY,
        shownAt TEXT NOT NULL
      )
    ''');

    // Добавляем дефолтные источники
    await _insertDefaultSources(db);
  }

  Future<void> _insertDefaultSources(Database db) async {
    final defaultSources = [
      ContentSource(
        id: 'default_1',
        name: 'r/furry_irl',
        url: 'https://www.reddit.com/r/furry_irl/',
        type: SourceType.reddit,
      ),
      ContentSource(
        id: 'default_2',
        name: 'r/furrymemes',
        url: 'https://www.reddit.com/r/furrymemes/',
        type: SourceType.reddit,
      ),
      ContentSource(
        id: 'default_3',
        name: 'r/furryart',
        url: 'https://www.reddit.com/r/furryart/',
        type: SourceType.reddit,
      ),
    ];

    for (var source in defaultSources) {
      await db.insert('sources', source.toMap());
    }
  }

  // CRUD для источников
  Future<List<ContentSource>> getSources() async {
    final db = await database;
    final maps = await db.query('sources', orderBy: 'addedAt DESC');
    return maps.map((map) => ContentSource.fromMap(map)).toList();
  }

  Future<void> insertSource(ContentSource source) async {
    final db = await database;
    await db.insert('sources', source.toMap());
  }

  Future<void> updateSource(ContentSource source) async {
    final db = await database;
    await db.update(
      'sources',
      source.toMap(),
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }

  Future<void> deleteSource(String id) async {
    final db = await database;
    await db.delete('sources', where: 'id = ?', whereArgs: [id]);
  }

  // CRUD для контента
  Future<List<ContentItem>> getContent({bool? onlyGifs, bool? onlySaved}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (onlyGifs == true) {
      where = 'isGif = ?';
      whereArgs = [1];
    }
    if (onlySaved == true) {
      where = where == null ? 'isSaved = ?' : '$where AND isSaved = ?';
      whereArgs = [...?whereArgs, 1];
    }

    final maps = await db.query(
      'content',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
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

  Future<void> markAsShown(String id) async {
    final db = await database;
    await db.insert('shown_content', {'id': id, 'shownAt': DateTime.now().toIso8601String()});
  }

  Future<bool> wasShown(String id) async {
    final db = await database;
    final result = await db.query('shown_content', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty;
  }
}
