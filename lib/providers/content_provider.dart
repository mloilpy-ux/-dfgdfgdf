import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../services/database_service.dart';
import '../services/reddit_parser.dart';
import '../services/nsfw_detector_service.dart';
import '../services/logger_service.dart';

class ContentProvider with ChangeNotifier {
  List<ContentItem> _items = [];
  bool _isLoading = false;
  bool _showNsfw = false;
  
  final DatabaseService _db = DatabaseService.instance;
  final RedditParser _redditParser = RedditParser();
  final NsfwDetectorService _nsfwDetector = NsfwDetectorService.instance;
  final LoggerService _logger = LoggerService.instance;

  List<ContentItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get showNsfw => _showNsfw;

  Future<void> loadContent(List activeSources) async {
    _isLoading = true;
    notifyListeners();

    _logger.log('🚀 Начало загрузки контента из ${activeSources.length} источников');

    for (var source in activeSources) {
      if (!source.isActive) continue;

      switch (source.type) {
        case SourceType.reddit:
          final newItems = await _redditParser.parseSubreddit(source.url, source.id);
          
          for (var item in newItems) {
            final wasShown = await _db.wasShown(item.id);
            if (!wasShown) {
              await _db.insertContent(item);
              await _db.markAsShown(item.id);
            }
          }
          break;
        default:
          _logger.log('⚠️ Тип источника ${source.type} пока не поддерживается');
      }
    }

    await refreshContent();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshContent({bool onlyGifs = false, bool onlySaved = false}) async {
    _items = await _db.getContent(onlyGifs: onlyGifs, onlySaved: onlySaved);
    
    if (!_showNsfw) {
      _items = _items.where((item) => !item.isNsfw).toList();
    }
    
    _logger.log('📦 Загружено ${_items.length} элементов контента');
    notifyListeners();
  }

  void toggleNsfwFilter() {
    _showNsfw = !_showNsfw;
    _logger.log('🔞 NSFW фильтр: ${_showNsfw ? "ВКЛ" : "ВЫКЛ"}');
    refreshContent();
  }

  Future<void> toggleSave(ContentItem item) async {
    item.isSaved = !item.isSaved;
    await _db.updateContent(item);
    notifyListeners();
  }
}
