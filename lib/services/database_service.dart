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
    
    try {
      _database = await _initDB('furry_content.db');
      _logger.log('✅ База данных инициализирована');
      return _database!;
    } catch (e) {
      _logger.log('❌ Ошибка инициализации БД: $e', isError: true);
      rethrow;
    }
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      _logger.log('📁 Путь к БД: $path');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
      );
    } catch (e) {
      _logger.log('❌ Ошибка открытия БД: $e', isError: true);
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    try {
      _logger.log('🔨 Создание таблиц БД...');

      // Таблица источников
      await db.execute('''
        CREATE TABLE sources (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          type TEXT NOT NULL,
          isActive INTEGER NOT NULL DEFAULT 1,
          addedAt TEXT NOT NULL
        )
      ''');

      // Таблица контента
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
          postUrl TEXT,
          FOREIGN KEY (sourceId) REFERENCES sources (id) ON DELETE CASCADE
        )
      ''');

      // Таблица показанного контента
      await db.execute('''
        CREATE TABLE shown_content (
          id TEXT PRIMARY KEY,
          shownAt TEXT NOT NULL
        )
      ''');

      // Индексы для оптимизации
      await db.execute('CREATE INDEX idx_content_created ON content(createdAt DESC)');
      await db.execute('CREATE INDEX idx_content_saved ON content(isSaved)');
      await db.execute('CREATE INDEX idx_content_gif ON content(isGif)');

      _logger.log('✅ Таблицы созданы успешно');

      // Добавляем дефолтные источники
      await _insertDefaultSources(db);
      
    } catch (e) {
      _logger.log('❌ Ошибка создания БД: $e', isError: true);
      rethrow;
    }
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    _logger.log('⬆️ Обновление БД с версии $oldVersion до $newVersion');
  }

  Future<void> _insertDefaultSources(Database db) async {
    try {
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
          name: 'r/furry',
          url: 'https://www.reddit.com/r/furry/',
          type: SourceType.reddit,
        ),
      ];

      for (var source in defaultSources) {
        await db.insert(
          'sources',
          source.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      _logger.log('✅ Добавлено ${defaultSources.length} дефолтных источников');
      
    } catch (e) {
      _logger.log('❌ Ошибка добавления дефолтных источников: $e', isError: true);
    }
  }

  // ============ CRUD для источников ============

  Future<List<ContentSource>> getSources() async {
    try {
      final db = await database;
      final maps = await db.query('sources', orderBy: 'addedAt DESC');
      
      _logger.log('📋 Загружено ${maps.length} источников');
      return maps.map((map) => ContentSource.fromMap(map)).toList();
      
    } catch (e) {
      _logger.log('❌ Ошибка получения источников: $e', isError: true);
      return [];
    }
  }

  Future<void> insertSource(ContentSource source) async {
    try {
      final db = await database;
      await db.insert(
        'sources',
        source.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      _logger.log('➕ Добавлен источник: ${source.name}');
      
    } catch (e) {
      _logger.log('❌ Ошибка добавления источника: $e', isError: true);
      rethrow;
    }
  }

  Future<void> updateSource(ContentSource source) async {
    try {
      final db = await database;
      final count = await db.update(
        'sources',
        source.toMap(),
        where: 'id = ?',
        whereArgs: [source.id],
      );
      
      if (count > 0) {
        _logger.log('✏️ Обновлен источник: ${source.name}');
      } else {
        _logger.log('⚠️ Источник не найден для обновления: ${source.id}');
      }
      
    } catch (e) {
      _logger.log('❌ Ошибка обновления источника: $e', isError: true);
      rethrow;
    }
  }

  Future<void> deleteSource(String id) async {
    try {
      final db = await database;
      
      // Удаляем контент связанный с источником
      await db.delete('content', where: 'sourceId = ?', whereArgs: [id]);
      
      // Удаляем источник
      final count = await db.delete('sources', where: 'id = ?', whereArgs: [id]);
      
      if (count > 0) {
        _logger.log('🗑️ Удален источник: $id');
      }
      
    } catch (e) {
      _logger.log('❌ Ошибка удаления источника: $e', isError: true);
      rethrow;
    }
  }

  // ============ CRUD для контента ============

  Future<List<ContentItem>> getContent({
    bool onlyGifs = false,
    bool onlySaved = false,
  }) async {
    try {
      final db = await database;
      final conditions = <String>[];
      final args = <dynamic>[];

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

      _logger.log('📦 Загружено ${maps.length} элементов контента');
      return maps.map((map) => ContentItem.fromMap(map)).toList();
      
    } catch (e) {
      _logger.log('❌ Ошибка получения контента: $e', isError: true);
      return [];
    }
  }

  Future<void> insertContent(ContentItem item) async {
    try {
      final db = await database;
      await db.insert(
        'content',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      _logger.log('➕ Добавлен контент: ${item.title}');
      
    } catch (e) {
      _logger.log('❌ Ошибка добавления контента: $e', isError: true);
      rethrow;
    }
  }

  Future<void> updateContent(ContentItem item) async {
    try {
      final db = await database;
      final count = await db.update(
        'content',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      
      if (count > 0) {
        _logger.log('✏️ Обновлен контент: ${item.id}');
      }
      
    } catch (e) {
      _logger.log('❌ Ошибка обновления контента: $e', isError: true);
      rethrow;
    }
  }

  // ========== НЕДОСТАЮЩИЕ МЕТОДЫ ==========

  Future<void> deleteContent(String id) async {
    try {
      final db = await database;
      final count = await db.delete('content', where: 'id = ?', whereArgs: [id]);
      
      if (count > 0) {
        _logger.log('🗑️ Удален контент: $id');
      }
      
    } catch (e) {
      _logger.log('❌ Ошибка удаления контента: $e', isError: true);
      rethrow;
    }
  }

  Future<void> clearAllContent() async {
    try {
      final db = await database;
      await db.delete('content');
      await db.delete('shown_content');
      
      _logger.log('🧹 Весь контент очищен');
      
    } catch (e) {
      _logger.log('❌ Ошибка очистки контента: $e', isError: true);
      rethrow;
    }
  }

  // ============ Работа с показанным контентом ============

  Future<void> markAsShown(String id) async {
    try {
      final db = await database;
      await db.insert(
        'shown_content',
        {
          'id': id,
          'shownAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      
    } catch (e) {
      _logger.log('❌ Ошибка markAsShown: $e', isError: true);
    }
  }

  Future<bool> wasShown(String id) async {
    try {
      final db = await database;
      final result = await db.query(
        'shown_content',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      return result.isNotEmpty;
      
    } catch (e) {
      _logger.log('❌ Ошибка wasShown: $e', isError: true);
      return false;
    }
  }

  // ============ Статистика ============

  Future<int> getContentCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM content');
      return Sqflite.firstIntValue(result) ?? 0;
      
    } catch (e) {
      _logger.log('❌ Ошибка подсчета контента: $e', isError: true);
      return 0;
    }
  }

  Future<int> getSourceCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM sources');
      return Sqflite.firstIntValue(result) ?? 0;
      
    } catch (e) {
      _logger.log('❌ Ошибка подсчета источников: $e', isError: true);
      return 0;
    }
  }

  // ============ Очистка и закрытие ============

  Future<void> close() async {
    try {
      final db = _database;
      if (db != null) {
        await db.close();
        _database = null;
        _logger.log('🔌 База данных закрыта');
      }
    } catch (e) {
      _logger.log('❌ Ошибка закрытия БД: $e', isError: true);
    }
  }

  Future<void> deleteDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'furry_content.db');
      
      await close();
      await databaseFactory.deleteDatabase(path);
      
      _logger.log('💥 База данных удалена');
      
    } catch (e) {
      _logger.log('❌ Ошибка удаления БД: $e', isError: true);
    }
  }
}
