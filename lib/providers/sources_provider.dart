import 'package:flutter/foundation.dart';

import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';

class SourcesProvider with ChangeNotifier {
  final DatabaseService _db;
  final LoggerService _logger = LoggerService.instance;
  List<ContentSource> _sources = [];
  Future<void>? _loading;
  String? _loadError;

  SourcesProvider({DatabaseService? database})
    : _db = database ?? DatabaseService.instance;

  List<ContentSource> get sources => List.unmodifiable(_sources);
  List<ContentSource> get activeSources =>
      _sources.where((source) => source.isActive).toList();
  Iterable<ContentSource> get autoRefreshSources =>
      activeSources.where((source) => !source.type.opensInBrowser);
  bool get isLoading => _loading != null;
  String? get loadError => _loadError;

  Future<void> loadSources() {
    if (_loading case final pending?) return pending;
    final pending = _loading = _loadSources();
    notifyListeners();
    return pending;
  }

  Future<void> _loadSources() async {
    try {
      _loadError = null;
      await _reload();
    } catch (error) {
      _loadError = 'Не удалось открыть список источников';
      _logger.log('Источники: $error', isError: true);
    } finally {
      _loading = null;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    _sources = await _db.getSources();
  }

  Future<ContentSource> addSource(String url) =>
      saveSource(ContentSource.fromUrl(url));

  Future<ContentSource> saveSource(ContentSource source) async {
    final stored = await _db.insertSource(source);
    await refreshStats();
    return stored;
  }

  Future<void> toggleSource(ContentSource source) async {
    await _db.setSourceActive(source.id, !source.isActive);
    await refreshStats();
  }

  Future<void> toggleNsfw(ContentSource source) async {
    await _db.setSourceNsfw(source.id, !source.isNsfw);
    await refreshStats();
  }

  Future<void> deleteSource(String id) async {
    await _db.deleteSource(id);
    await refreshStats();
  }

  Future<void> refreshStats() async {
    await _reload();
    notifyListeners();
  }
}
