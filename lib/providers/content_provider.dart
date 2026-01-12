import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/reddit_parser.dart';
import '../services/logger_service.dart';

class ContentProvider with ChangeNotifier {
  List<ContentItem> _unseenItems = [];
  List<ContentItem> _savedItems = [];
  bool _isLoading = false;
  bool _showNsfw = false;
  bool _onlyGifs = false;
  
  final DatabaseService _db = DatabaseService.instance;
  final RedditParser _redditParser = RedditParser();
  final LoggerService _logger = LoggerService.instance;

  List<ContentItem> get unseenItems => _unseenItems;
  List<ContentItem> get savedItems => _savedItems;
  bool get isLoading => _isLoading;
  bool get showNsfw => _showNsfw;
  bool get onlyGifs => _onlyGifs;

  // Загрузка нового контента
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
            // Проверяем, не был ли показан
            final wasSeen = await _db.wasShown(item.id);
            
            if (!wasSeen) {
              // Применяем фильтры
              if (!_showNsfw && item.isNsfw) continue;
              if (_onlyGifs && !item.isGif) continue;
              
              _unseenItems.add(item);
              await _db.insertContent(item);
            }
          }
        } catch (e) {
          _logger.log('❌ Ошибка загрузки из ${source.name}: $e', isError: true);
        }
      }

      _logger.log('✅ Загружено ${_unseenItems.length} новых элементов');
      
    } catch (e) {
      _logger.log('💥 Ошибка loadNewContent: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Отметить как просмотренный
  Future<void> markAsSeen(String id) async {
    try {
      await _db.markAsShown(id);
      _unseenItems.removeWhere((item) => item.id == id);
      _logger.log('👁️ Отмечен как просмотренный: $id');
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка markAsSeen: $e', isError: true);
    }
  }

  // Сохранить элемент
  Future<void> saveItem(ContentItem item) async {
    try {
      item.isSaved = true;
      await _db.updateContent(item);
      await _db.markAsShown(item.id);
      
      _savedItems.add(item);
      _unseenItems.removeWhere((i) => i.id == item.id);
      
      _logger.log('💾 Сохранено: ${item.title}');
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка saveItem: $e', isError: true);
    }
  }

  // Загрузить сохраненные
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
    _unseenItems.clear();
    loadNewContent();
  }

  void toggleGifFilter() {
    _onlyGifs = !_onlyGifs;
    _logger.log('🎬 Только GIF: ${_onlyGifs ? "ВКЛ" : "ВЫКЛ"}');
    _unseenItems.clear();
    loadNewContent();
  }
}
