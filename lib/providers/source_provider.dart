import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/content_source.dart';

class SourcesProvider extends ChangeNotifier {
  late final Box<ContentSource> box = Hive.box<ContentSource>('sources');
  List<ContentSource> get sources => box.values.toList();

  SourcesProvider() {
    if (box.isEmpty) _initDefaults();
  }

  void _initDefaults() {
    final defaults = [
      ContentSource(id: 'furry_irl', name: 'r/furry_irl', url: 'https://www.reddit.com/r/furry_irl/.json', type: SourceType.reddit),
      ContentSource(id: 'furrymemes', name: 'r/furrymemes', url: 'https://www.reddit.com/r/furrymemes/.json', type: SourceType.reddit),
      ContentSource(id: 'furryart', name: 'r/furryart', url: 'https://www.reddit.com/r/furryart/.json', type: SourceType.reddit),
    ];
    for (final s in defaults) box.put(s.id, s);
    notifyListeners();
  }

  void toggleActive(String id) {
    final source = box.get(id);
    if (source != null) {
      source.active = !source.active;
      box.put(id, source);
      notifyListeners();
    }
  }

  void addSource(String urlStr) {
    try {
      final source = ContentSource.fromUrl(urlStr);
      box.put(source.id, source);
      notifyListeners();
    } catch (e) {}
  }

  void deleteSource(String id) => box.delete(id)..notifyListeners();
}
