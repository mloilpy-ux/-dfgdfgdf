import 'package:flutter/material.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';

class SourceProvider with ChangeNotifier {
  List<ContentSource> _sources = [];
  final DatabaseService _db = DatabaseService.instance;
  final LoggerService _logger = LoggerService.instance;

  List<ContentSource> get sources => _sources;

  Future<void> loadSources() async {
    _sources = await _db.getSources();
    _logger.log('📚 Загружено ${_sources.length} источников');
    notifyListeners();
  }

  Future<void> addSource(ContentSource source) async {
    await _db.insertSource(source);
    await loadSources();
    _logger.log('➕ Добавлен источник: ${source.name}');
  }

  Future<void> toggleSource(String id) async {
    final source = _sources.firstWhere((s) => s.id == id);
    source.isActive = !source.isActive;
    await _db.updateSource(source);
    _logger.log('🔄 Источник ${source.name}: ${source.isActive ? "ВКЛ" : "ВЫКЛ"}');
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    await _db.deleteSource(id);
    await loadSources();
    _logger.log('🗑️ Источник удалён');
  }
}
