import 'package:flutter/material.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';

class SourceProvider with ChangeNotifier {
  List<ContentSource> _sources = [];
  bool _isLoading = false;

  final DatabaseService _db = DatabaseService.instance;
  final LoggerService _logger = LoggerService.instance;

  List<ContentSource> get sources => _sources;
  List<ContentSource> get activeSources => _sources.where((s) => s.isActive).toList();
  bool get isLoading => _isLoading;

  Future<void> loadSources() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sources = await _db.getSources();
      _logger.log('📋 Загружено ${_sources.length} источников');
    } catch (e) {
      _logger.log('❌ Ошибка загрузки источников: $e', isError: true);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSource(ContentSource source) async {
    try {
      await _db.insertSource(source);
      _sources.add(source);
      _logger.log('➕ Добавлен источник: ${source.name}');
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка добавления источника: $e', isError: true);
      rethrow;
    }
  }

  Future<void> toggleSource(ContentSource source) async {
    try {
      final updated = source.copyWith(isActive: !source.isActive);
      await _db.updateSource(updated);
      
      final index = _sources.indexWhere((s) => s.id == source.id);
      if (index != -1) {
        _sources[index] = updated;
      }
      
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка переключения источника: $e', isError: true);
    }
  }

  Future<void> deleteSource(String id) async {
    try {
      await _db.deleteSource(id);
      _sources.removeWhere((s) => s.id == id);
      _logger.log('🗑️ Удалён источник: $id');
      notifyListeners();
    } catch (e) {
      _logger.log('❌ Ошибка удаления источника: $e', isError: true);
    }
  }
}
