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
  List<ContentSource> get activeSources =>
      _sources.where((s) => s.isActive).toList();
  bool get isLoading => _isLoading;

  SourcesProvider() {
    // БАГ #1 ИСПРАВЛЕН: откладываем до следующего микротаска —
    // виджеты успевают подписаться до первого notifyListeners()
    Future.microtask(() => loadSources());
  }

  Future<void> loadSources() async {
    _isLoading = true;
    notifyListeners();

    try {
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
    } catch (e) {
      _logger.log('❌ Ошибка загрузки источников: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSource(String url) async {
    try {
      _logger.log('➕ Добавление источника: $url');
      final source = ContentSource.fromUrl(url);
      await _db.insertSource(source);

      // БАГ #3 ИСПРАВЛЕН: обновляем локальный список напрямую
      _sources = [..._sources, source];
      notifyListeners();

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

      // БАГ #3 ИСПРАВЛЕН: заменяем только один элемент в памяти
      _sources = _sources.map((s) => s.id == source.id ? updated : s).toList();
      notifyListeners();

      _logger.log('🔄 ${updated.name} '
          '${updated.isActive ? "активирован" : "деактивирован"}');
    } catch (e) {
      _logger.log('❌ Ошибка переключения источника: $e', isError: true);
    }
  }

  Future<void> deleteSource(String id) async {
    try {
      _logger.log('🗑️ Удаление источника: $id');
      await _db.deleteSource(id);

      // БАГ #3 ИСПРАВЛЕН: удаляем только из локального списка
      _sources = _sources.where((s) => s.id != id).toList();
      notifyListeners();

      _logger.log('✅ Источник удалён');
    } catch (e) {
      _logger.log('❌ Ошибка удаления источника: $e', isError: true);
    }
  }

  Future<void> updateSourceParsedCount(String id) async {
    try {
      // БАГ #2 ИСПРАВЛЕН: orElse вместо краша StateError
      final index = _sources.indexWhere((s) => s.id == id);
      if (index == -1) {
        _logger.log('⚠️ Источник $id не найден для обновления статистики');
        return;
      }

      final updated = _sources[index].copyWith(
        lastParsed: DateTime.now(),
        parsedCount: _sources[index].parsedCount + 1,
      );
      await _db.updateSource(updated);

      // БАГ #3 ИСПРАВЛЕН: обновляем только один элемент
      _sources = [..._sources];
      _sources[index] = updated;
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка обновления статистики: $e', isError: true);
    }
  }
}
