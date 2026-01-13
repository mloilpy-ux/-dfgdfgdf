import 'package:flutter/foundation.dart';
import '../models/content_item.dart';
import '../services/database_service.dart';
import '../services/reddit_parser.dart';
import '../services/web_scraper_service.dart';
import '../services/logger_service.dart';
import 'sources_provider.dart';
import '../models/content_source.dart';

class ContentProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final RedditParser _redditParser = RedditParser();
  final WebScraperService _scraper = WebScraperService.instance;
  final LoggerService _logger = LoggerService.instance;

  List<ContentItem> _items = [];
  bool _isLoading = false;
  final Set<String> _shownIds = {};

  List<ContentItem> get items => _items;
  bool get isLoading => _isLoading;

  Future<void> loadContent({bool onlyGifs = false, bool onlySaved = false}) async {
    _logger.log('📥 Загрузка контента из БД...');
    _items = await _db.getContent(onlyGifs: onlyGifs, onlySaved: onlySaved);
    
    // Исключаем просмотренные
    _items = _items.where((item) => !_shownIds.contains(item.id)).toList();
    
    _logger.log('✅ Загружено ${_items.length} элементов (без дубликатов)');
    notifyListeners();
  }

  Future<void> parseAllActiveSources(SourcesProvider sourcesProvider) async {
    if (_isLoading) {
      _logger.log('⚠️ Парсинг уже выполняется');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final activeSources = sourcesProvider.activeSources;
      _logger.log('🚀 Начало парсинга ${activeSources.length} активных источников');

      int totalAdded = 0;

      for (var source in activeSources) {
        try {
          _logger.log('🔍 Парсинг источника: ${source.name} (${source.type.name})');
          
          List<ContentItem> newItems = [];
          
          switch (source.type) {
            case SourceType.reddit:
              newItems = await _redditParser.parseSubreddit(source.url, source.id);
              break;
              
            case SourceType.twitter:
              final username = _extractTwitterUsername(source.url);
              if (username != null) {
                newItems = await _scraper.parseTwitter(username, source.id);
              }
              break;
              
            case SourceType.telegram:
              newItems = await _scraper.parseTelegram(source.url, source.id);
              break;
          }

          // Проверка на дубликаты
          int addedCount = 0;
          for (var item in newItems) {
            final wasShown = await _db.wasShown(item.id);
            final exists = await _db.contentExists(item.id);
            
            if (!wasShown && !exists) {
              await _db.insertContent(item);
              addedCount++;
            }
          }

          totalAdded += addedCount;
          _logger.log('✅ ${source.name}: добавлено $addedCount новых (пропущено ${newItems.length - addedCount} дубликатов)');
          
          await sourcesProvider.updateSourceParsedCount(source.id);
          
        } catch (e) {
          _logger.log('❌ Ошибка парсинга ${source.name}: $e', isError: true);
        }
      }

      _logger.log('🎉 Парсинг завершен! Всего добавлено: $totalAdded новых артов');
      await loadContent();
      
    } catch (e) {
      _logger.log('❌ Критическая ошибка парсинга: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String? _extractTwitterUsername(String url) {
    final match = RegExp(r'twitter\.com/([^/]+)|x\.com/([^/]+)').firstMatch(url);
    return match?.group(1) ?? match?.group(2);
  }

  Future<void> toggleSave(ContentItem item) async {
    try {
      final updated = item.copyWith(isSaved: !item.isSaved);
      await _db.updateContent(updated);
      _logger.log('${updated.isSaved ? "💾 Сохранено" : "🗑️ Удалено из сохранённых"}: ${item.title}');
      await loadContent();
    } catch (e) {
      _logger.log('❌ Ошибка сохранения: $e', isError: true);
    }
  }

  void markAsShown(String id) {
    _shownIds.add(id);
    _db.markAsShown(id);
    _logger.log('👁️ Отмечено как просмотренное: $id');
  }

  Future<void> clearAllContent() async {
    await _db.clearAllContent();
    _shownIds.clear();
    await loadContent();
    _logger.log('🗑️ Весь контент очищен');
  }
}
