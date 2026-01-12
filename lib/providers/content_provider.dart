import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/reddit_parser.dart';
import '../services/nsfw_detector_service.dart';
import '../services/logger_service.dart';

class ContentProvider with ChangeNotifier {
  List<ContentItem> _items = [];
  bool _isLoading = false;
  bool _showNsfw = false;
  String? _errorMessage;
  
  final DatabaseService _db = DatabaseService.instance;
  final RedditParser _redditParser = RedditParser();
  final NsfwDetectorService _nsfwDetector = NsfwDetectorService.instance;
  final LoggerService _logger = LoggerService.instance;

  List<ContentItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get showNsfw => _showNsfw;
  String? get errorMessage => _errorMessage;

  Future<void> loadContent(List<ContentSource> activeSources) async {
    if (_isLoading) {
      _logger.log('⏳ Загрузка уже выполняется, пропускаем');
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _logger.log('🚀 Начало загрузки контента из ${activeSources.length} источников');

      for (var source in activeSources) {
        if (!source.isActive) {
          _logger.log('⏭️ Пропускаем неактивный источник: ${source.name}');
          continue;
        }

        try {
          await _loadFromSource(source);
        } catch (e) {
          _logger.log('❌ Ошибка загрузки из ${source.name}: $e', isError: true);
          // Продолжаем с другими источниками
        }
      }

      await refreshContent();
      _logger.log('✅ Загрузка контента завершена успешно');
      
    } catch (e) {
      _errorMessage = 'Ошибка загрузки контента: $e';
      _logger.log('💥 Критическая ошибка загрузки: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromSource(ContentSource source) async {
    _logger.log('📥 Загрузка из ${source.name} (${source.type.name})');

    switch (source.type) {
      case SourceType.reddit:
        await _loadRedditContent(source);
        break;
      
      case SourceType.twitter:
        _logger.log('⚠️ Twitter парсинг пока не реализован');
        break;
      
      case SourceType.telegram:
        _logger.log('⚠️ Telegram парсинг пока не реализован');
        break;
      
      default:
        _logger.log('⚠️ Неизвестный тип источника: ${source.type}', isError: true);
    }
  }

  Future<void> _loadRedditContent(ContentSource source) async {
    try {
      final newItems = await _redditParser.parseSubreddit(source.url, source.id);
      
      if (newItems.isEmpty) {
        _logger.log('📭 Новых элементов не найдено в ${source.name}');
        return;
      }

      int addedCount = 0;
      
      for (var item in newItems) {
        try {
          // Проверяем, был ли элемент уже показан
          final wasShown = await _db.wasShown(item.id);
          
          if (!wasShown) {
            await _db.insertContent(item);
            await _db.markAsShown(item.id);
            addedCount++;
          }
        } catch (e) {
          _logger.log('❌ Ошибка сохранения элемента ${item.id}: $e', isError: true);
        }
      }

      _logger.log('✅ Добавлено $addedCount новых элементов из ${source.name}');
      
    } catch (e) {
      _logger.log('❌ Ошибка парсинга Reddit: $e', isError: true);
      throw Exception('Reddit parsing failed: $e');
    }
  }

  Future<void> refreshContent({bool onlyGifs = false, bool onlySaved = false}) async {
    try {
      _logger.log('🔄 Обновление списка контента (GIFs: $onlyGifs, Saved: $onlySaved)');
      
      _items = await _db.getContent(onlyGifs: onlyGifs, onlySaved: onlySaved);
      
      // Применяем NSFW фильтр
      if (!_showNsfw) {
        final originalCount = _items.length;
        _items = _items.where((item) => !item.isNsfw).toList();
        _logger.log('🔞 Отфильтровано ${originalCount - _items.length} NSFW элементов');
      }
      
      _logger.log('📦 Загружено ${_items.length} элементов контента');
      _errorMessage = null;
      
    } catch (e) {
      _errorMessage = 'Ошибка обновления контента: $e';
      _logger.log('💥 Ошибка refreshContent: $e', isError: true);
      _items = []; // Безопасный fallback
    }
    
    notifyListeners();
  }

  void toggleNsfwFilter() {
    _showNsfw = !_showNsfw;
    _logger.log('🔞 NSFW фильтр: ${_showNsfw ? "ВКЛ ✅" : "ВЫКЛ ❌"}');
    refreshContent();
  }

  Future<void> toggleSave(ContentItem item) async {
    try {
      item.isSaved = !item.isSaved;
      await _db.updateContent(item);
      
      _logger.log('💾 ${item.isSaved ? "Сохранено" : "Удалено из сохраненных"}: ${item.title}');
      notifyListeners();
      
    } catch (e) {
      _logger.log('❌ Ошибка сохранения элемента: $e', isError: true);
      // Откатываем изменение при ошибке
      item.isSaved = !item.isSaved;
      notifyListeners();
    }
  }

  Future<void> deleteItem(ContentItem item) async {
    try {
      await _db.deleteContent(item.id);
      _items.remove(item);
      _logger.log('🗑️ Удален элемент: ${item.title}');
      notifyListeners();
      
    } catch (e) {
      _logger.log('❌ Ошибка удаления элемента: $e', isError: true);
    }
  }

  Future<void> clearAll() async {
    try {
      await _db.clearAllContent();
      _items.clear();
      _logger.log('🧹 Весь контент очищен');
      notifyListeners();
      
    } catch (e) {
      _logger.log('❌ Ошибка очистки контента: $e', isError: true);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _logger.log('🔌 ContentProvider disposed');
    super.dispose();
  }
}
