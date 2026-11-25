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
  List<ContentItem> _savedItems = [];
  List<ContentItem> get savedItems => _savedItems;

  Future<void> loadSavedItems() async {
    _savedItems = await _db.getContent(onlySaved: true);
    notifyListeners();
  }

  Future<void> loadContent({
    bool onlyGifs = false,
    bool onlySaved = false,
  }) async {
    _logger.log('📥 Загрузка контента из БД...');
    _items = await _db.getContent(onlyGifs: onlyGifs, onlySaved: onlySaved);
    _items = _items
        .where((item) => item.isSaved || !_shownIds.contains(item.id))
        .toList();
    _logger.log('✅ Загружено ${_items.length} элементов');
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
      _logger.log('🚀 Начало парсинга ${activeSources.length} источников');

      int totalAdded = 0;

      for (var source in activeSources) {
        try {
          _logger.log('🔍 Парсинг: ${source.name}');

          List<ContentItem> newItems = [];

          switch (source.type) {
            case SourceType.reddit:
              newItems = await _redditParser.parseSubreddit(
                source.url,
                source.id,
              );
              break;

            case SourceType.telegram:
              newItems = await _scraper.parseTelegram(source.url, source.id);
              break;

            case SourceType.twitter:
              _logger.log('⚠️ Twitter отключён (Nitter не работает)');
              newItems = [];
              break;
          }

          int addedCount = 0;
          for (var item in newItems) {
            if (!await _db.shouldSkip(item.id)) {
              await _db.insertContent(item);
              addedCount++;
            }
          }

          totalAdded += addedCount;
          _logger.log('✅ ${source.name}: +$addedCount новых');
          await sourcesProvider.updateSourceParsedCount(source.id);
        } catch (e) {
          _logger.log('❌ ${source.name}: $e', isError: true);
        }
      }

      _logger.log('🎉 Парсинг завершен! Добавлено: $totalAdded');
      await loadContent();
    } catch (e) {
      _logger.log('❌ Критическая ошибка: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggleSave(ContentItem item) async {
    try {
      final updated = item.copyWith(isSaved: !item.isSaved);
      await _db.updateContent(updated);
      _logger.log('${updated.isSaved ? "💾" : "🗑️"} ${item.title}');
      _items = _items
          .map((entry) => entry.id == item.id ? updated : entry)
          .toList();
      await loadSavedItems();
      return true;
    } catch (e) {
      _logger.log('❌ Ошибка сохранения: $e', isError: true);
      return false;
    }
  }

  void markAsShown(String id) {
    _shownIds.add(id);
    _db.markAsShown(id);
    _logger.log('👁️ Просмотрено: $id');
  }

  Future<void> clearAllContent() async {
    await _db.clearAllContent();
    _shownIds.clear();
    _savedItems = [];
    await loadContent();
    _logger.log('🗑️ Контент очищен');
  }
}
