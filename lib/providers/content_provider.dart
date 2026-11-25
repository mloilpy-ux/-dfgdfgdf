import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/content_item.dart';
import '../models/content_source.dart';
import '../services/database_service.dart';
import '../services/logger_service.dart';
import '../services/source_response.dart';
import '../services/web_scraper_service.dart';
import 'sources_provider.dart';

class SourceImport {
  const SourceImport({required this.message, this.failed = false});
  final String message;
  final bool failed;
}

class ContentProvider with ChangeNotifier {
  final DatabaseService _db;
  final http.Client _client;
  final LoggerService _logger = LoggerService.instance;
  final _inFlight = <String, Future<SourceImport>>{};
  final _results = <String, SourceImport>{};
  bool _refreshingAll = false;
  List<ContentItem> _items = [];
  List<ContentItem> _savedItems = [];
  String? _selectedSourceId;

  ContentProvider({DatabaseService? database, http.Client? client})
    : _db = database ?? DatabaseService.instance,
      _client = client ?? http.Client();

  List<ContentItem> get items => _items;
  List<ContentItem> get savedItems => _savedItems;
  bool get isLoading => _refreshingAll || _inFlight.isNotEmpty;
  String? get selectedSourceId => _selectedSourceId;

  List<ContentItem> itemsFor(MediaKind kind, {required bool showNsfw}) {
    return _items
        .where(
          (item) =>
              item.kind == kind &&
              (showNsfw || !item.isNsfw) &&
              (_selectedSourceId == null || item.sourceId == _selectedSourceId),
        )
        .toList();
  }

  void selectSource(String? id) {
    _selectedSourceId = id;
    notifyListeners();
  }

  SourceImport? resultFor(String sourceId) => _results[sourceId];
  bool isImporting(String sourceId) => _inFlight.containsKey(sourceId);

  Future<void> loadContent() async {
    _items = await _db.getContent(onlyActive: true);
    notifyListeners();
  }

  Future<void> loadSavedItems() async {
    _savedItems = await _db.getContent(onlySaved: true);
    notifyListeners();
  }

  Future<void> sourceChanged(List<ContentSource> activeSources) async {
    if (_selectedSourceId != null &&
        !activeSources.any((source) => source.id == _selectedSourceId)) {
      _selectedSourceId = null;
    }
    await loadContent();
    await loadSavedItems();
  }

  Future<Map<String, SourceImport>> parseAllActiveSources(
    SourcesProvider sources,
  ) async {
    if (_refreshingAll) return {};
    _refreshingAll = true;
    notifyListeners();
    try {
      final report = <String, SourceImport>{};
      for (final source in sources.autoRefreshSources) {
        report[source.id] = await importSource(source, sources);
      }
      _logger.log(
        'Обновлено источников: ${report.values.where((result) => !result.failed).length} из ${report.length}',
      );
      return report;
    } finally {
      _refreshingAll = false;
      notifyListeners();
    }
  }

  Future<SourceImport> importSource(
    ContentSource source,
    SourcesProvider sources,
  ) {
    if (source.type.opensInBrowser) {
      return Future.value(
        const SourceImport(
          message: 'Откройте страницу для импорта',
          failed: true,
        ),
      );
    }
    return _trackImport(source, () => _runImport(source, sources));
  }

  Future<SourceImport> importBrowserMedia(
    ContentSource source,
    SourcesProvider sources,
    List<ContentItem> items,
  ) => _trackImport(source, () async {
    try {
      return await _saveImport(source, sources, items);
    } catch (_) {
      return const SourceImport(
        message: 'Не удалось сохранить медиа источника',
        failed: true,
      );
    }
  });

  Future<SourceImport> _trackImport(
    ContentSource source,
    Future<SourceImport> Function() run,
  ) {
    final current = _inFlight[source.id];
    if (current != null) return current;
    final request = run().then((result) {
      _results[source.id] = result;
      _inFlight.remove(source.id);
      _logger.log('${source.name}: ${result.message}', isError: result.failed);
      notifyListeners();
      return result;
    });
    _inFlight[source.id] = request;
    notifyListeners();
    return request;
  }

  Future<SourceImport> _runImport(
    ContentSource source,
    SourcesProvider sources,
  ) async {
    try {
      final items = switch (source.type) {
        SourceType.telegram => await WebScraperService(
          _client,
        ).parseTelegram(source),
        SourceType.direct => [
          ContentItem(
            id: 'file_${source.id}',
            sourceId: source.id,
            title: source.name,
            mediaUrl: source.url,
            isNsfw: source.isNsfw,
            createdAt: source.addedAt,
          ),
        ],
        _ => throw const SourceFailure('Откройте страницу для импорта'),
      };
      return await _saveImport(source, sources, items);
    } on SourceFailure catch (error) {
      return SourceImport(message: error.message, failed: true);
    } on TimeoutException {
      return const SourceImport(
        message: 'Источник не ответил вовремя',
        failed: true,
      );
    } on http.ClientException {
      return const SourceImport(
        message: 'Не удалось подключиться к источнику',
        failed: true,
      );
    } catch (error) {
      _logger.log(
        'Не удалось обработать источник (${error.runtimeType})',
        isError: true,
      );
      return const SourceImport(
        message: 'Не удалось обработать источник',
        failed: true,
      );
    }
  }

  Future<SourceImport> _saveImport(
    ContentSource source,
    SourcesProvider sources,
    List<ContentItem> items,
  ) async {
    final added = await _db.importContent(source, items);
    await loadContent();
    await sources.refreshStats();
    return SourceImport(
      message: items.isEmpty
          ? 'В последних публикациях нет поддерживаемых медиа'
          : 'Новых материалов: $added · всего найдено: ${items.length}',
    );
  }

  Future<bool> toggleSave(ContentItem item) async {
    try {
      await _db.setSaved(item.id, !item.isSaved);
      await loadContent();
      await loadSavedItems();
      return true;
    } catch (error) {
      _logger.log('Ошибка сохранения: $error', isError: true);
      return false;
    }
  }

  Future<void> clearAllContent() async {
    await _db.clearAllContent();
    await loadContent();
    await loadSavedItems();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
