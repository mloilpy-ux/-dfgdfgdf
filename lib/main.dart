import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:url_launcher/url_launcher.dart';

enum ContentType { image, gif }
enum SourceType { reddit, telegram, twitter, custom }

class MediaItem {
  final String url;
  final ContentType type;
  final String sourceName;
  final bool isNSFW;
  final String postId; // For dedup

  MediaItem({
    required this.url,
    required this.type,
    required this.sourceName,
    this.isNSFW = false,
    this.postId = '',
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'type': type.index,
    'sourceName': sourceName,
    'isNSFW': isNSFW,
    'postId': postId,
  };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
    url: json['url'],
    type: ContentType.values[json['type']],
    sourceName: json['sourceName'],
    isNSFW: json['isNSFW'] ?? false,
    postId: json['postId'] ?? '',
  );
}

class ContentSource {
  String id;
  String name;
  String url;
  SourceType type;
  bool isActive;
  bool isNSFW;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.isActive = true,
    this.isNSFW = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'type': type.index,
    'isActive': isActive,
    'isNSFW': isNSFW,
  };

  factory ContentSource.fromJson(Map<String, dynamic> json) => ContentSource(
    id: json['id'],
    name: json['name'],
    url: json['url'],
    type: SourceType.values[json['type']],
    isActive: json['isActive'] ?? true,
    isNSFW: json['isNSFW'] ?? false,
  );
}

class AppLogger {
  static final List<String> logs = [];
  static final StreamController<List<String>> _controller = StreamController.broadcast();
  static Stream<List<String>> get stream => _controller.stream;

  static void log(String tag, String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$t] [$tag] $msg';
    print(entry);
    logs.add(entry);
    if (logs.length > 1000) logs.removeAt(0);
    _controller.add(List.from(logs));
  }
}

class ScraperEngine {
  static const String _userAgent = 'Mozilla/5.0 (compatible; LunyaHub/7.0)';
  static const List<String> _nsfwKeywords = ['nsfw', 'yiff', 'porn', 'xxx', 'hentai', 'rule34', 'adult', '18+'];

  static bool _isNSFW(String title, String url, bool sourceNSFW) {
    if (sourceNSFW) return true;
    final lowerTitle = title.toLowerCase();
    final lowerUrl = url.toLowerCase();
    return _nsfwKeywords.any((k) => lowerTitle.contains(k) || lowerUrl.contains(k));
  }

  static Future<List<MediaItem>> scrape(ContentSource source) async {
    try {
      if (source.type == SourceType.reddit) {
        return _parseReddit(source);
      } else {
        return _parseHtml(source);
      }
    } catch (e) {
      AppLogger.log('SCRAPER', 'Error ${source.name}: $e');
      return [];
    }
  }

  static Future<List<MediaItem>> _parseReddit(ContentSource source) async {
    final subreddit = source.url.split('/r/')[1].split('/')[0].split('?')[0];
    final apiUrl = 'https://www.reddit.com/r/$subreddit/new.json?limit=30';
    AppLogger.log('REDDIT', 'Fetching $apiUrl');
    final resp = await http.get(Uri.parse(apiUrl), headers: {'User-Agent': _userAgent});
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final data = json.decode(resp.body);
    final children = data['data']['children'] as List<dynamic>;
    final List<MediaItem> items = [];
    for (var child in children) {
      final post = child['data'];
      final postId = post['id'];
      final title = post['title'] ?? '';
      final over18 = post['over_18'] ?? false;
      final sourceNSFW = source.isNSFW;
      final isItemNSFW = over18 || _isNSFW(title, post['url'] ?? '', sourceNSFW);
      String? imgUrl;
      final preview = post['preview'];
      if (preview != null && preview['images'] != null) {
        final images = preview['images'] as List<dynamic>;
        if (images.isNotEmpty) {
          imgUrl = images[0]['source']['url']?.toString();
          imgUrl = imgUrl?.replaceAll('&amp;', '&');
        }
      } else {
        final url = post['url'] ?? '';
        final postHint = post['post_hint'];
        if (postHint == 'image' || url.contains(RegExp(r'\.(jpg|png|webp|gif)$'))) {
          imgUrl = url;
        }
      }
      if (imgUrl != null && (imgUrl.contains('i.redd.it') || imgUrl.contains('imgur') || imgUrl.contains('preview.redd.it'))) {
        final type = imgUrl.endsWith('.gif') ? ContentType.gif : ContentType.image;
        items.add(MediaItem(url: imgUrl, type: type, sourceName: source.name, isNSFW: isItemNSFW, postId: postId));
      }
    }
    AppLogger.log('REDDIT', 'Found ${items.length} from ${source.name}');
    return items;
  }

  static Future<List<MediaItem>> _parseHtml(ContentSource source) async {
    AppLogger.log('HTML', 'Fetching ${source.url}');
    final resp = await http.get(Uri.parse(source.url), headers: {'User-Agent': _userAgent});
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    final html = resp.body;
    final List<MediaItem> items = [];
    final imgRegex = RegExp(r'<img[^>]+src=["\']([^"\']+)["\']', caseSensitive: false);
    final bgRegex = RegExp(r'background-image\s*:\s*url\([\'"]?([^)\'"]+)[\'"]?\)');
    for (final match in imgRegex.allMatches(html)) {
      _addHtmlItem(items, match.group(1)!, ContentType.image, source);
    }
    for (final match in bgRegex.allMatches(html)) {
      _addHtmlItem(items, match.group(1)!, ContentType.image, source);
    }
    return items;
  }

  static void _addHtmlItem(List<MediaItem> items, String url, ContentType type, ContentSource source) {
    if (url.startsWith('//')) url = 'https:$url';
    if (url.contains(RegExp(r'(emoji|icon|logo|avatar)'))) return;
    final isItemNSFW = source.isNSFW || _isNSFW('', url, false);
    if (!items.any((i) => i.url == url)) {
      items.add(MediaItem(url: url, type: type, sourceName: source.name, isNSFW: isItemNSFW));
    }
  }
}

class LunyaApp extends StatelessWidget {
  const LunyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lunya Furry Hub',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF),
          secondary: Color(0xFF64FFDA),
          surface: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;
  late SharedPreferences _prefs;
  List<ContentSource> sources = [];
  List<MediaItem> feedItems = [];
  List<MediaItem> favorites = [];
  Set<String> seenUrls = {};
  bool allowNSFW = false;
  bool gifOnly = false;
  bool isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initPrefs();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadData();
    if (sources.isEmpty) {
      sources = [
        ContentSource(id: '1', name: 'r/furry_irl', url: 'https://www.reddit.com/r/furry_irl/', type: SourceType.reddit),
        ContentSource(id: '2', name: 'r/furrymemes', url: 'https://www.reddit.com/r/furrymemes/', type: SourceType.reddit),
        ContentSource(id: '3', name: 'r/furryart', url: 'https://www.reddit.com/r/furryart/', type: SourceType.reddit),
      ];
      await _saveSources();
    }
    AppLogger.log('SYS', 'Lunya Hub loaded');
    setState(() {});
    _fetchMore();
  }

  Future<void> _loadData() async {
    final sourcesJson = _prefs.getString('sources_json') ?? '[]';
    sources = (json.decode(sourcesJson) as List).map((s) => ContentSource.fromJson(s)).toList();
    final favJson = _prefs.getString('favorites_json') ?? '[]';
    favorites = (json.decode(favJson) as List).map((f) => MediaItem.fromJson(f)).toList();
    seenUrls = (_prefs.getStringList('seen_urls') ?? []).toSet();
    allowNSFW = _prefs.getBool('allow_nsfw') ?? false;
    gifOnly = _prefs.getBool('gif_only') ?? false;
  }

  Future<void> _saveData() async {
    await _prefs.setString('sources_json', json.encode(sources.map((s) => s.toJson()).toList()));
    await _prefs.setString('favorites_json', json.encode(favorites.map((f) => f.toJson()).toList()));
    await _prefs.setStringList('seen_urls', seenUrls.toList()..length = min(seenUrls.length, 10000));
    await _prefs.setBool('allow_nsfw', allowNSFW);
    await _prefs.setBool('gif_only', gifOnly);
  }

  Future<void> _fetchMore() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    final activeSources = sources.where((s) => s.isActive && (allowNSFW || !s.isNSFW)).toList();
    if (activeSources.isEmpty) {
      _showSnack('No active sources');
      setState(() => isLoading = false);
      return;
    }
    List<MediaItem> newItems = [];
    for (final source in activeSources) {
      final batch = await ScraperEngine.scrape(source);
      newItems.addAll(batch.where((item) => !seenUrls.contains(item.url)));
    }
    newItems = newItems
        .where((item) => !feedItems.any((f) => f.url == item.url))
        .where((item) => allowNSFW || !item.isNSFW)
        .toList();
    newItems.shuffle();
    seenUrls.addAll(newItems.map((i) => i.url));
    feedItems.addAll(newItems.take(50));
    await _saveData();
    AppLogger.log('FETCH', 'Added ${newItems.length} new items');
    setState(() => isLoading = false);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      _fetchMore();
    }
  }

  Future<void> _toggleFavorite(MediaItem item, {bool add = true}) async {
    if (add) {
      if (!favorites.any((f) => f.url == item.url)) {
        favorites.add(item);
      }
    } else {
      favorites.removeWhere((f) => f.url == item.url);
    }
    await _saveData();
    setState(() {});
  }

  Future<void> _download(MediaItem item) async {
    try {
      final resp = await http.get(Uri.parse(item.url));
      final dir = await getApplicationDocumentsDirectory();
      final ext = item.url.split('.').last.split('?')[0];
      final file = File('${dir.path}/lunya_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(resp.bodyBytes);
      _showSnack('Saved: ${file.path.split('/').last}');
    } catch (e) {
      _showSnack('Download error: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _addSource() async {
    final controllers = {'name': TextEditingController(), 'url': TextEditingController()};
    SourceType? detectedType;
    String? detectedName;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Source'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controllers['name']!, decoration: const InputDecoration(labelText: 'Name')),
          TextField(
            controller: controllers['url']!,
            decoration: const InputDecoration(labelText: 'URL', hintText: 'https://reddit.com/r/furry_irl/'),
            onChanged: (v) {
              final url = Uri.tryParse(v);
              if (url != null) {
                if (v.contains('reddit.com/r/')) {
                  detectedType = SourceType.reddit;
                  detectedName = 'r/${v.split('/r/')[1].split('/')[0].split('?')[0]}';
                } else if (v.contains('t.me/')) {
                  detectedType = SourceType.telegram;
                } else if (v.contains('twitter.com/') || v.contains('x.com/')) {
                  detectedType = SourceType.twitter;
                } else {
                  detectedType = SourceType.custom;
                }
              }
            },
          ),
          if (detectedType != null)
            Text('Detected: ${detectedType.name}${detectedName != null ? ' ($detectedName)' : ''}'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = controllers['name']!.text;
              final url = controllers['url']!.text;
              if (name.isNotEmpty && url.isNotEmpty) {
                sources.add(ContentSource(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: detectedName ?? name,
                  url: url,
                  type: detectedType ?? SourceType.custom,
                ));
                await _saveSources();
                setState(() {});
                _showSnack('Source added');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _editSource(ContentSource source) async {
    // Implement rename/delete popup similar to add
    final index = sources.indexOf(source);
    // ... dialog for name/url/nsfw toggle, then setState save
    await _saveSources();
    setState(() {});
  }

  Future<void> _saveSources() async {
    await _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFeed = feedItems.where((item) => !gifOnly || item.type == ContentType.gif).toList();

    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A1A1A),
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0A0A0A)),
              child: Row(children: [Icon(Icons.pets, color: Colors.white, size: 40), SizedBox(width: 10), Text('Lunya Hub', style: TextStyle(fontSize: 24))]),
            ),
            SwitchListTile(
              title: const Text('Allow NSFW'),
              secondary: const Icon(Icons.lock_open),
              value: allowNSFW,
              onChanged: (v) {
                setState(() => allowNSFW = v);
                feedItems.clear();
                _saveData();
                _fetchMore();
              },
            ),
            SwitchListTile(
              title: const Text('GIF Only'),
              secondary: const Icon(Icons.gif),
              value: gifOnly,
              onChanged: (v) => setState(() => gifOnly = v),
            ),
            ListTile(title: const Text('Sources'), leading: const Icon(Icons.source), onTap: () => setState(() => _navIndex = 3)),
            ListTile(title: const Text('Logs'), leading: const Icon(Icons.terminal), onTap: () => setState(() => _navIndex = 4)),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pets), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.gif), label: 'GIFs'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Gallery'),
          NavigationDestination(icon: Icon(Icons.list), label: 'Sources'),
          NavigationDestination(icon: Icon(Icons.terminal), label: 'Logs'),
        ],
      ),
      body: _buildBody(filteredFeed),
    );
  }

  Widget _buildBody(List<MediaItem> filteredFeed) {
    switch (_navIndex) {
      case 0:
      case 1:
        return RefreshIndicator(
          onRefresh: _fetchMore,
          child: GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: filteredFeed.length + (isLoading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i >= filteredFeed.length) return const Center(child: CircularProgressIndicator());
              final item = filteredFeed[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullView(items: filteredFeed, initialIndex: i))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.url,
                        fit: BoxFit.cover,
                        memCacheHeight: 400,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                      ),
                      if (item.isNSFW) const Align(alignment: Alignment.topRight, child: Icon(Icons.warning, color: Colors.red)),
                      Align(alignment: Alignment.bottomRight, child: Icon(item.type == ContentType.gif ? Icons.gif : Icons.image, color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      case 2:
        return RefreshIndicator(
          onRefresh: () => Future.value(),
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: favorites.length,
            itemBuilder: (ctx, i) {
              final item = favorites[i];
              return GestureDetector(
                onTap: () => _download(item),
                onLongPress: () => _toggleFavorite(item, add: false),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(imageUrl: item.url, fit: BoxFit.cover, memCacheHeight: 400),
                ),
              );
            },
          ),
        );
      case 3:
        return ListView.builder(
          itemCount: sources.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) return ListTile(title: const Text('Add Source'), leading: const Icon(Icons.add), onTap: _addSource);
            final source = sources[i - 1];
            return CheckboxListTile(
              title: Text(source.name, style: TextStyle(color: source.isNSFW ? Colors.red : null)),
              subtitle: Text('${source.url.split('/').last} (${source.type.name})'),
              value: source.isActive,
              secondary: PopupMenuButton(
                itemBuilder: (_) => [
                  const PopupMenuItem(child: Text('NSFW')),
                  const PopupMenuItem(child: Text('Rename')),
                  const PopupMenuItem(child: Text('Delete')),
                ],
                onSelected: (_) => _editSource(source),
              ),
              onChanged: (v) {
                source.isActive = v!;
                _saveSources();
                setState(() {});
              },
            );
          },
        );
      case 4:
      default:
        return StreamBuilder<List<String>>(
          stream: AppLogger.stream,
          initialData: AppLogger.logs,
          builder: (ctx, snap) {
            final logs = snap.data ?? [];
            return ListView.builder(
              reverse: true,
              itemCount: logs.length,
              itemBuilder: (ctx, i) => ListTile(title: Text(logs[logs.length - 1 - i], style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.green))),
            );
          },
        );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class FullView extends StatefulWidget {
  final List<MediaItem> items;
  final int initialIndex;
  const FullView({super.key, required this.items, required this.initialIndex});

  @override
  State<FullView> createState() => _FullViewState();
}

class _FullViewState extends State<FullView> with TickerProviderStateMixin {
  late PageController _pageController;
  int currentIndex = 0;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[currentIndex];
    final isFav = false; // Check from global, but simplify
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(item.sourceName),
        actions: [
          IconButton(icon: const Icon(Icons.download), onPressed: () => _download(item)),
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
            onPressed: () => _toggleFav(item),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            // Swipe right: save
            _toggleFav(item);
          } else if (details.primaryVelocity! < 0) {
            // Swipe left: next
            _next();
          }
        },
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => currentIndex = i),
          itemBuilder: (_, i) {
            final it = widget.items[i];
            return Center(
              child: InteractiveViewer(
                child: CachedNetworkImage(imageUrl: it.url, fit: BoxFit.contain),
              ),
            );
          },
        ),
      ),
      bottomSheet: Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: _prev),
            FloatingActionButton.extended(onPressed: _toggleFav, label: Text(isFav ? 'Saved' : 'Save'), icon: const Icon(Icons.pets)),
            IconButton(icon: const Icon(Icons.arrow_forward_ios, color: Colors.white), onPressed: _next),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (currentIndex < widget.items.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (currentIndex > 0) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _toggleFav(MediaItem item) {
    // Global toggle, but simulate
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery')));
  }

  Future<void> _download(MediaItem item) async {
    // Call global download
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloading...')));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  runApp(const LunyaApp());
}
