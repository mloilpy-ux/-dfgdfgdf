import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/reddit_parser.dart';
import '../services/logger_service.dart';

class ContentProvider with ChangeNotifier {
  List<ContentItem> _allItems = [];
  List<ContentItem> _savedItems = [];
  bool _isLoading = false;
  bool _showNsfw = false;
  ContentType _contentType = ContentType.all;
  
  final DatabaseService _db = DatabaseService.instance;
  final RedditParser _redditParser = RedditParser();
  final LoggerService _logger = LoggerService.instance;

  List<ContentItem> get filteredItems {
    return _allItems.where((item) {
      if (!_showNsfw && item.isNsfw) return false;
      
      switch (_contentType) {
        case ContentType.images:
          return !item.isGif && !item.mediaUrl.contains('.mp4');
        case ContentType.gifs:
          return item.isGif;
        case ContentType.videos:
          return item.mediaUrl.contains('.mp4');
        case ContentType.all:
          return true;
      }
    }).toList();
  }

  List<ContentItem> get savedItems => _savedItems;
  bool get isLoading => _isLoading;
  bool get showNsfw => _showNsfw;
  ContentType get contentType => _contentType;

  void setContentType(ContentType type) {
    _contentType = type;
    _logger.log('🎬 Тип контента: ${type.name}');
    notifyListeners();
  }

  Future<void> loadNewContent() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final sources = await _db.getSources();
      final activeSources = sources.where((s) => s.isActive).toList();

      for (var source in activeSources) {
        try {
          final newItems = await _redditParser.parseSubreddit(source.url, source.id);
          
          for (var item in newItems) {
            final wasSeen = await _db.wasShown(item.id);
            if (!wasSeen) {
              _allItems.add(item);
              await _db.insertContent(item);
            }
          }
        } catch (e) {
          _logger.log('❌ Ошибка загрузки из ${source.name}: $e', isError: true);
        }
      }

      _logger.log('✅ Загружено ${_allItems.length} элементов');
    } catch (e) {
      _logger.log('💥 Ошибка loadNewContent: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsSeen(String id) async {
    try {
      await _db.markAsShown(id);
      _allItems.removeWhere((item) => item.id == id);
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка markAsSeen: $e', isError: true);
    }
  }

  Future<void> saveItem(ContentItem item) async {
    try {
      item.isSaved = true;
      await _db.updateContent(item);
      await _db.markAsShown(item.id);
      
      _savedItems.add(item);
      _allItems.removeWhere((i) => i.id == item.id);
      
      _logger.log('💾 Сохранено: ${item.title}');
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка saveItem: $e', isError: true);
    }
  }

  Future<void> loadSavedItems() async {
    try {
      _savedItems = await _db.getContent(onlySaved: true);
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка loadSavedItems: $e', isError: true);
    }
  }

  void toggleNsfwFilter() {
    _showNsfw = !_showNsfw;
    _logger.log('🔞 NSFW: ${_showNsfw ? "ВКЛ" : "ВЫКЛ"}');
    notifyListeners();
  }
}

enum ContentType { all, images, gifs, videos }
