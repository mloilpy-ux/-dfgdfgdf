import 'package:flutter/foundation.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';

class SourcesProvider with ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  final LoggerService _logger = LoggerService.instance;

  List<ContentSource> _sources = [];
  bool _isLoading = false;

  List<ContentSource> get sources => _sources;
  List<ContentSource> get activeSources => _sources.where((s) => s.isActive).toList();
  bool get isLoading => _isLoading;

  SourcesProvider() {
    loadSources();
  }

  Future<void> loadSources() async {
    _isLoading = true;
    notifyListeners();

    _logger.log('🔄 Загрузка источников...');
    _sources = await _db.getSources();
    
    if (_sources.isEmpty) {
      _logger.log('📌 Инициализация источников по умолчанию');
      final defaults = ContentSource.getDefaultSources();
      for (var source in defaults) {
        await _db.insertSource(source);
      }
      _sources = await _db.getSources();
    }

    _logger.log('✅ Загружено ${_sources.length} источников');
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addSource(String url) async {
    try {
      _logger.log('➕ Добавление источника: $url');
      final source = ContentSource.fromUrl(url);
      await _db.insertSource(source);
      await loadSources();
      _logger.log('✅ Источник добавлен: ${source.name}');
    } catch (e) {
      _logger.log('❌ Ошибка добавления источника: $e', isError: true);
      rethrow;
    }
  }

  Future<void> toggleSource(ContentSource source) async {
    try {
      final updated = source.copyWith(isActive: !source.isActive);
      await _db.updateSource(updated);
      await loadSources();
      _logger.log('🔄 Источник ${updated.name} ${updated.isActive ? "активирован" : "деактивирован"}');
    } catch (e) {
      _logger.log('❌ Ошибка переключения источника: $e', isError: true);
    }
  }

  Future<void> deleteSource(String id) async {
    try {
      _logger.log('🗑️ Удаление источника: $id');
      await _db.deleteSource(id);
      await loadSources();
      _logger.log('✅ Источник удален');
    } catch (e) {
      _logger.log('❌ Ошибка удаления источника: $e', isError: true);
    }
  }

  Future<void> updateSourceParsedCount(String id) async {
    try {
      final source = _sources.firstWhere((s) => s.id == id);
      final updated = source.copyWith(
        lastParsed: DateTime.now(),
        parsedCount: source.parsedCount + 1,
      );
      await _db.updateSource(updated);
      await loadSources();
    } catch (e) {
      _logger.log('❌ Ошибка обновления статистики: $e', isError: true);
    }
  }
}
