// lib/providers/sources_provider.dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/content_source.dart';

class SourcesProvider extends ChangeNotifier {
  late Box<ContentSource> _box;
  List<ContentSource> get sources => _box.values.toList();

  SourcesProvider() {
    _box = Hive.box<ContentSource>('sources');
    _initDefaults();
  }

  void _initDefaults() {
    if (_box.isEmpty) {
      final defaults = [
        ContentSource(id: 'furry_irl', name: 'r/furry_irl', url: 'https://www.reddit.com/r/furry_irl/.json', type: SourceType.reddit),
        ContentSource(id: 'furrymemes', name: 'r/furrymemes', url: 'https://www.reddit.com/r/furrymemes/.json', type: SourceType.reddit),
        ContentSource(id: 'furryart', name: 'r/furryart', url: 'https://www.reddit.com/r/furryart/.json', type: SourceType.reddit),
      ]; // [web:44]
      for (var s in defaults) {
        _box.put(s.id, s);
      }
    }
  }

  void toggleActive(String id) {
    final source = _box.get(id);
    if (source != null) {
      source.active = !source.active;
      _box.put(id, source);
      notifyListeners();
    }
  }

  void addSource(String url) {
    try {
      final source = ContentSource.fromUrl(url);
      _box.put(source.id, source);
      notifyListeners();
    } catch (e) {
      // log error
    }
  }

  void deleteSource(String id) {
    _box.delete(id);
    notifyListeners();
  }
}

// Similar for SettingsProvider (bool showNsfw=true, bool gifOnly=false)
// LoggerProvider List<String> logs = []; void addLog(String msg);

// ContentProvider
class ContentProvider extends ChangeNotifier {
  late Box<ContentItem> _contentsBox;
  late Box<String> _seenBox;
  List<ContentItem> _contents = [];
  bool _loading = false;
  List<ContentItem> get contents => _contents;
  bool get loading => _loading;

  ContentProvider() {
    _contentsBox = Hive.box<ContentItem>('contents');
    _seenBox = Hive.box<String>('seen');
    _contents = _contentsBox.values.where((c) => !c.isNsfw || context.read<SettingsProvider>().showNsfw).where((c) => !context.read<SettingsProvider>().gifOnly || c.isGif).toList()..sort((a,b) => b.created.compareTo(a.created));
  }

  Future<void> fetchContent() async {
    _loading = true;
    notifyListeners();
    final sourcesProv = context.read<SourcesProvider>();
    final settings = context.read<SettingsProvider>();
    final logger = context.read<LoggerProvider>();
    Set<String> newItems = [];
    for (var source in sourcesProv.sources.where((s) => s.active)) {
      logger.addLog('Parsing ${source.name}...');
      try {
        final response = await http.get(Uri.parse(source.url));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final children = json['data']['children'] as List;
          for (var child in children) {
            final item = ContentItem.fromRedditJson(child['data'], source.name);
            if (item != null && !_seenBox.containsKey(item.imageUrl)) {
              if (!settings.showNsfw && item.isNsfw) continue;
              if (settings.gifOnly && !item.isGif) continue;
              _seenBox.put(item.imageUrl, 'seen');
              _contentsBox.put(item.id, item);
              newItems.add(item.id);
            }
          }
          logger.addLog('Found ${newItems.length} new from ${source.name}');
        }
      } catch (e) {
        logger.addLog('Error parsing ${source.name}: $e');
      }
    }
    _contents = _contentsBox.values.toList()..sort((a,b) => b.created.compareTo(a.created));
    notifyListeners();
    _loading = false;
  }

  void toggleFavorite(ContentItem item) {
    // implement flag in model if needed
  }

  Future<void> saveImage(ContentItem item) async {
    // use gallery_saver.GallerySaver.saveImage(item.imageUrl)
    // request permission
  }
}
