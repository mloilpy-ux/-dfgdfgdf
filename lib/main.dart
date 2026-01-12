import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// ==========================================
// 1. КОНСТАНТЫ И ТЕМЫ (FURRY THEME)
// ==========================================

const String kAppVersion = "Lunya Hub 7.0 (Reborn)";
const String kUserAgent = "Mozilla/5.0 (compatible; LunyaHub/7.0; +http://lunya.app)";

// Цветовая палитра "Neon Furry"
const Color kPrimaryColor = Color(0xFF7C4DFF); // Deep Purple
const Color kSecondaryColor = Color(0xFF64FFDA); // Teal Accent
const Color kErrorColor = Color(0xFFFF5252);
const Color kSurfaceColor = Color(0xFF1E1E1E);
const Color kBackgroundColor = Color(0xFF121212);

// ==========================================
// 2. МОДЕЛИ ДАННЫХ
// ==========================================

enum SourceType { reddit, telegram, twitter, custom }
enum ContentType { image, gif, video }

class ContentSource {
  final String id;
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

  factory ContentSource.fromJson(Map<String, dynamic> json) {
    return ContentSource(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      type: SourceType.values[json['type']],
      isActive: json['isActive'],
      isNSFW: json['isNSFW'],
    );
  }
}

class MediaItem {
  final String id; // Уникальный ID для дедупликации
  final String url;
  final String thumbnailUrl;
  final ContentType type;
  final String sourceName;
  final bool isNSFW;
  final DateTime parsedAt;

  MediaItem({
    required this.id,
    required this.url,
    required this.thumbnailUrl,
    required this.type,
    required this.sourceName,
    required this.isNSFW,
    required this.parsedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'type': type.index,
        'sourceName': sourceName,
        'isNSFW': isNSFW,
        'parsedAt': parsedAt.toIso8601String(),
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      url: json['url'],
      thumbnailUrl: json['thumbnailUrl'],
      type: ContentType.values[json['type']],
      sourceName: json['sourceName'],
      isNSFW: json['isNSFW'],
      parsedAt: DateTime.parse(json['parsedAt']),
    );
  }
}

class LogEntry {
  final DateTime time;
  final String tag;
  final String message;
  final bool isError;

  LogEntry(this.tag, this.message, {this.isError = false}) : time = DateTime.now();
}

// ==========================================
// 3. СЕРВИСЫ (SERVICES)
// ==========================================

/// Сервис логирования (Singleton)
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final StreamController<List<LogEntry>> _controller = StreamController.broadcast();
  final List<LogEntry> _logs = [];

  Stream<List<LogEntry>> get stream => _controller.stream;
  List<LogEntry> get logs => List.unmodifiable(_logs);

  void log(String tag, String message, {bool isError = false}) {
    final entry = LogEntry(tag, message, isError: isError);
    _logs.insert(0, entry); // Новые сверху
    if (_logs.length > 1000) _logs.removeLast();
    _controller.add(_logs);
    debugPrint("[${tag}] $message");
  }

  void clear() {
    _logs.clear();
    _controller.add(_logs);
  }
}

/// Сервис хранения данных (File System)
class StorageService {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _sourcesFile async {
    final path = await _localPath;
    return File('$path/lunya_sources.json');
  }

  static Future<File> get _favoritesFile async {
    final path = await _localPath;
    return File('$path/lunya_favorites.json');
  }

  static Future<void> saveSources(List<ContentSource> sources) async {
    final file = await _sourcesFile;
    final jsonStr = jsonEncode(sources.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonStr);
  }

  static Future<List<ContentSource>> loadSources() async {
    try {
      final file = await _sourcesFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => ContentSource.fromJson(e)).toList();
    } catch (e) {
      LoggerService().log("STORAGE", "Error loading sources: $e", isError: true);
      return [];
    }
  }

  static Future<void> saveFavorites(List<MediaItem> items) async {
    final file = await _favoritesFile;
    final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
    await file.writeAsString(jsonStr);
  }

  static Future<List<MediaItem>> loadFavorites() async {
    try {
      final file = await _favoritesFile;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(content);
      return jsonList.map((e) => MediaItem.fromJson(e)).toList();
    } catch (e) {
      LoggerService().log("STORAGE", "Error loading favorites: $e", isError: true);
      return [];
    }
  }
}

/// Сервис парсинга (Engine)
class ScraperService {
  static final List<String> _nsfwKeywords = ['nsfw', 'yiff', 'xxx', 'porn', '18+', 'adult', 'hentai'];

  static bool isContentNSFW(String text, bool sourceIsNSFW) {
    if (sourceIsNSFW) return true;
    final lower = text.toLowerCase();
    for (var k in _nsfwKeywords) {
      if (lower.contains(k)) return true;
    }
    return false;
  }

  static Future<List<MediaItem>> scrape(ContentSource source) async {
    LoggerService().log("SCRAPER", "Starting scrape: ${source.name} (${source.type.name})...");
    try {
      switch (source.type) {
        case SourceType.reddit:
          return await _scrapeReddit(source);
        case SourceType.telegram:
          return await _scrapeTelegramWeb(source);
        case SourceType.twitter:
        case SourceType.custom:
          return await _scrapeGenericHtml(source);
      }
    } catch (e) {
      LoggerService().log("SCRAPER", "Error scraping ${source.name}: $e", isError: true);
      return [];
    }
  }

  // --- REDDIT PARSER (JSON) ---
  static Future<List<MediaItem>> _scrapeReddit(ContentSource source) async {
    final url = source.url.endsWith('.json') ? source.url : '${source.url}/hot.json?limit=25';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': kUserAgent});
    
    if (response.statusCode != 200) throw Exception("HTTP ${response.statusCode}");
    
    final data = json.decode(response.body);
    final children = data['data']['children'] as List;
    List<MediaItem> items = [];

    for (var child in children) {
      final d = child['data'];
      final String? postUrl = d['url_overridden_by_dest'] ?? d['url'];
      if (postUrl == null) continue;

      // Фильтрация
      final bool over18 = d['over_18'] ?? false;
      final String title = d['title'] ?? "";
      final bool isNSFW = isContentNSFW(title, source.isNSFW || over18);

      // Определение типа
      ContentType type = ContentType.image;
      if (postUrl.endsWith('.gif') || d['is_video'] == true) type = ContentType.gif;
      if (postUrl.contains('v.redd.it')) type = ContentType.video;

      // Пропускаем галереи Reddit (сложный парсинг, пока берем только прямые)
      if (postUrl.contains('reddit.com/gallery')) continue;

      items.add(MediaItem(
        id: d['name'] ?? postUrl, // Reddit ID (t3_xxxxx)
        url: postUrl,
        thumbnailUrl: d['thumbnail'] != 'self' && d['thumbnail'] != 'default' ? d['thumbnail'] : postUrl,
        type: type,
        sourceName: source.name,
        isNSFW: isNSFW,
        parsedAt: DateTime.now(),
      ));
    }
    LoggerService().log("REDDIT", "Found ${items.length} items in ${source.name}");
    return items;
  }

  // --- TELEGRAM PARSER (Web Preview) ---
  static Future<List<MediaItem>> _scrapeTelegramWeb(ContentSource source) async {
    // Преобразуем t.me/channel в t.me/s/channel для веб-превью
    String webUrl = source.url;
    if (!webUrl.contains('/s/')) {
      webUrl = webUrl.replaceFirst('t.me/', 't.me/s/');
    }

    final response = await http.get(Uri.parse(webUrl), headers: {'User-Agent': kUserAgent});
    if (response.statusCode != 200) throw Exception("TG HTTP ${response.statusCode}");

    final html = response.body;
    List<MediaItem> items = [];
    
    // Регулярки для Telegram Web
    final imgRegex = RegExp(r"background-image:url\('([^']+)'\)");
    final videoRegex = RegExp(r'<video[^>]+src="([^"]+)"'); // Простая эвристика

    // Поиск картинок
    final imgMatches = imgRegex.allMatches(html);
    for (var m in imgMatches) {
      String? url = m.group(1);
      if (url == null) continue;
      
      // Игнорируем аватарки и мелкие иконки
      if (url.contains('emoji') || url.contains('profile')) continue;

      items.add(MediaItem(
        id: url.hashCode.toString(),
        url: url,
        thumbnailUrl: url,
        type: ContentType.image,
        sourceName: source.name,
        isNSFW: source.isNSFW, // В TG сложно детектить NSFW программно, верим источнику
        parsedAt: DateTime.now(),
      ));
    }

    LoggerService().log("TELEGRAM", "Found ${items.length} items in ${source.name}");
    return items;
  }

  // --- GENERIC HTML PARSER ---
  static Future<List<MediaItem>> _scrapeGenericHtml(ContentSource source) async {
    final response = await http.get(Uri.parse(source.url), headers: {'User-Agent': kUserAgent});
    final html = response.body;
    List<MediaItem> items = [];

    // Ищем OpenGraph Image
    final ogImage = RegExp(r'<meta property="og:image" content="([^"]+)"');
    // Ищем обычные картинки
    final imgTag = RegExp(r'<img[^>]+src="([^"]+)"');

    for (var m in ogImage.allMatches(html)) {
      String? url = m.group(1);
      if (url != null) {
         items.add(MediaItem(
          id: url.hashCode.toString(),
          url: url,
          thumbnailUrl: url,
          type: ContentType.image,
          sourceName: source.name,
          isNSFW: source.isNSFW,
          parsedAt: DateTime.now(),
        ));
      }
    }
    
    // Если ничего не нашли через мета, ищем просто img
    if (items.isEmpty) {
       for (var m in imgTag.allMatches(html)) {
        String? url = m.group(1);
        if (url != null && url.startsWith('http') && !url.contains('logo') && !url.contains('icon')) {
           items.add(MediaItem(
            id: url.hashCode.toString(),
            url: url,
            thumbnailUrl: url,
            type: ContentType.image,
            sourceName: source.name,
            isNSFW: source.isNSFW,
            parsedAt: DateTime.now(),
          ));
        }
      }
    }

    LoggerService().log("GENERIC", "Found ${items.length} items in ${source.name}");
    return items;
  }
}

// ==========================================
// 4. STATE MANAGEMENT (APP STATE)
// ==========================================

class AppState extends ChangeNotifier {
  List<ContentSource> _sources = [];
  List<MediaItem> _feed = [];
  List<MediaItem> _favorites = [];
  Set<String> _seenIds = {}; // Для дедупликации

  bool _isGlobalNSFWAllowed = false;
  bool _isLoading = false;
  Timer? _backgroundTimer;

  // Getters
  List<ContentSource> get sources => _sources;
  List<MediaItem> get feed => _feed.where((i) => _isGlobalNSFWAllowed ? true : !i.isNSFW).toList();
  List<MediaItem> get favorites => _favorites;
  bool get isNSFW => _isGlobalNSFWAllowed;
  bool get isLoading => _isLoading;

  AppState() {
    _init();
  }

  Future<void> _init() async {
    LoggerService().log("SYS", "Initializing AppState...");
    
    // 1. Загрузка избранного
    _favorites = await StorageService.loadFavorites();
    
    // 2. Загрузка источников
    _sources = await StorageService.loadSources();
    if (_sources.isEmpty) {
      _addDefaultSources();
    }

    // 3. Старт таймера для "фонового" обновления (раз в 5 минут)
    _backgroundTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      refreshFeed(isBackground: true);
    });

    // 4. Первая загрузка
    refreshFeed();
  }

  void _addDefaultSources() {
    LoggerService().log("SYS", "Adding default furry sources...");
    _sources.addAll([
      ContentSource(id: 'r_furry_irl', name: 'r/furry_irl', url: 'https://www.reddit.com/r/furry_irl', type: SourceType.reddit),
      ContentSource(id: 'r_furrymemes', name: 'r/furrymemes', url: 'https://www.reddit.com/r/furrymemes', type: SourceType.reddit),
      ContentSource(id: 'r_furryart', name: 'r/furryart', url: 'https://www.reddit.com/r/furryart', type: SourceType.reddit),
      ContentSource(id: 'tg_archive', name: 'TG: Furry Archive', url: 'https://t.me/furry_art_archive', type: SourceType.telegram),
    ]);
    StorageService.saveSources(_sources);
  }

  void toggleNSFW(bool value) {
    _isGlobalNSFWAllowed = value;
    LoggerService().log("SETTINGS", "Global NSFW Filter: $value");
    notifyListeners();
  }

  Future<void> addSource(String url) async {
    String name = "New Source";
    SourceType type = SourceType.custom;
    
    if (url.contains("reddit.com")) {
      type = SourceType.reddit;
      name = url.split("reddit.com/")[1].split("/")[0];
      if (name.isEmpty) name = "Reddit Source";
    } else if (url.contains("t.me")) {
      type = SourceType.telegram;
      name = "TG Channel";
    }

    final newSource = ContentSource(
      id: DateTime.now().millisecondsSinceEpoch.toString(), 
      name: name, 
      url: url, 
      type: type
    );
    
    _sources.add(newSource);
    await StorageService.saveSources(_sources);
    LoggerService().log("SOURCE", "Added source: $url");
    notifyListeners();
    refreshFeed();
  }

  void toggleSource(String id) {
    final index = _sources.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sources[index].isActive = !_sources[index].isActive;
      StorageService.saveSources(_sources);
      notifyListeners();
    }
  }

  void removeSource(String id) {
    _sources.removeWhere((s) => s.id == id);
    StorageService.saveSources(_sources);
    notifyListeners();
  }

  Future<void> refreshFeed({bool isBackground = false}) async {
    if (_isLoading && !isBackground) return;
    _isLoading = true;
    if (!isBackground) notifyListeners();

    List<MediaItem> newItems = [];
    final activeSources = _sources.where((s) => s.isActive).toList();

    LoggerService().log("CORE", "Starting batch scrape from ${activeSources.length} sources...");

    for (var source in activeSources) {
      // Имитация задержки чтобы не дудосить
      await Future.delayed(const Duration(milliseconds: 500)); 
      var items = await ScraperService.scrape(source);
      
      for (var item in items) {
        if (!_seenIds.contains(item.id)) {
          newItems.add(item);
          _seenIds.add(item.id);
        }
      }
    }

    if (newItems.isNotEmpty) {
      newItems.shuffle();
      _feed.insertAll(0, newItems);
      // Ограничиваем ленту до 500 элементов
      if (_feed.length > 500) {
        _feed = _feed.sublist(0, 500);
      }
      LoggerService().log("CORE", "Feed updated. New items: ${newItems.length}");
    } else {
      LoggerService().log("CORE", "No new items found.");
    }

    _isLoading = false;
    notifyListeners();
  }

  void toggleFavorite(MediaItem item) {
    final exists = _favorites.any((i) => i.id == item.id);
    if (exists) {
      _favorites.removeWhere((i) => i.id == item.id);
      LoggerService().log("FAV", "Removed from favorites: ${item.id}");
    } else {
      _favorites.add(item);
      LoggerService().log("FAV", "Added to favorites: ${item.id}");
    }
    StorageService.saveFavorites(_favorites);
    notifyListeners();
  }

  bool isFavorite(String id) => _favorites.any((i) => i.id == id);

  Future<void> clearHistory() async {
    _seenIds.clear();
    _feed.clear();
    refreshFeed();
  }
}

// ==========================================
// 5. ПОЛЬЗОВАТЕЛЬСКИЙ ИНТЕРФЕЙС (UI)
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Настройка системной панели
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const LunyaApp());
}

class LunyaApp extends StatelessWidget {
  const LunyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Внедряем AppState через InheritedWidget (упрощенная замена Provider)
    return AppStateProvider(
      state: AppState(),
      child: MaterialApp(
        title: 'Lunya Hub 7.0',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: kPrimaryColor,
            secondary: kSecondaryColor,
            surface: kSurfaceColor,
            background: kBackgroundColor,
            error: kErrorColor,
          ),
          scaffoldBackgroundColor: kBackgroundColor,
          appBarTheme: const AppBarTheme(
            backgroundColor: kBackgroundColor,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

// Простой Provider для доступа к State
class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppStateProvider>()!.notifier!;
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    
    final pages = [
      const FeedScreen(),
      const SourcesScreen(),
      const FavoritesScreen(),
      const LogsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: const Color(0xFF252525),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded), 
            label: 'Feed',
            selectedIcon: Icon(Icons.grid_view_rounded, color: kSecondaryColor),
          ),
          NavigationDestination(
            icon: Icon(Icons.rss_feed_rounded), 
            label: 'Sources',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded), 
            selectedIcon: Icon(Icons.favorite_rounded, color: Colors.redAccent),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_rounded), 
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}

// --- ЭКРАН ЛЕНТЫ ---
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final items = state.feed;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lunya Hub"),
        actions: [
          IconButton(
            icon: Icon(state.isNSFW ? Icons.lock_open : Icons.lock, 
              color: state.isNSFW ? Colors.red : Colors.green),
            onPressed: () => state.toggleNSFW(!state.isNSFW),
            tooltip: "Toggle NSFW",
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.refreshFeed(),
          )
        ],
      ),
      body: state.isLoading && items.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : items.isEmpty 
          ? Center(child: Text("No content. Check sources or wait.", style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) => MediaCard(item: items[i]),
            ),
    );
  }
}

class MediaCard extends StatelessWidget {
  final MediaItem item;
  const MediaCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenViewer(item: item)));
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item.thumbnailUrl, 
              fit: BoxFit.cover,
              errorBuilder: (_,__,___) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image)),
              loadingBuilder: (_, child, prog) => prog == null ? child : Container(color: Colors.grey[900]),
            ),
            if (item.type == ContentType.gif)
              const Positioned(top: 8, right: 8, child: Icon(Icons.play_circle_fill, color: Colors.white70)),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.transparent, Colors.black87], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.sourceName, style: const TextStyle(fontSize: 10, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                    if (item.isNSFW) const Icon(Icons.explicit, size: 14, color: Colors.redAccent),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- ЭКРАН ПОЛНОГО ПРОСМОТРА (SWIPE) ---
class FullScreenViewer extends StatelessWidget {
  final MediaItem item;
  const FullScreenViewer({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final isFav = state.isFavorite(item.id);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Dismissible(
        key: Key(item.id),
        direction: DismissDirection.vertical,
        onDismissed: (_) => Navigator.pop(context),
        child: GestureDetector(
          // Двойной тап для лайка
          onDoubleTap: () => state.toggleFavorite(item),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                child: Center(
                  child: Image.network(item.url, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                bottom: 40,
                right: 20,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "fav",
                      backgroundColor: isFav ? Colors.redAccent : Colors.grey[800],
                      onPressed: () => state.toggleFavorite(item),
                      child: Icon(isFav ? Icons.favorite : Icons.favorite_border),
                    ),
                    const SizedBox(height: 16),
                    FloatingActionButton(
                      heroTag: "share",
                      backgroundColor: Colors.grey[800],
                      onPressed: () => launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
                      child: const Icon(Icons.open_in_new),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- ЭКРАН ИСТОЧНИКОВ ---
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final controller = TextEditingController();

    void _addNew() {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Add Source"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "URL (Reddit/Telegram)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () {
            if (controller.text.isNotEmpty) {
              state.addSource(controller.text);
              Navigator.pop(ctx);
            }
          }, child: const Text("Add")),
        ],
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sources"),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addNew)],
      ),
      body: ListView.builder(
        itemCount: state.sources.length,
        itemBuilder: (ctx, i) {
          final s = state.sources[i];
          return ListTile(
            leading: Icon(
              s.type == SourceType.reddit ? Icons.reddit : Icons.send,
              color: s.isActive ? kSecondaryColor : Colors.grey,
            ),
            title: Text(s.name),
            subtitle: Text(s.url, style: const TextStyle(fontSize: 10)),
            trailing: Switch(
              value: s.isActive,
              onChanged: (_) => state.toggleSource(s.id),
              activeColor: kSecondaryColor,
            ),
            onLongPress: () => state.removeSource(s.id),
          );
        },
      ),
    );
  }
}

// --- ЭКРАН ИЗБРАННОГО ---
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);
    final items = state.favorites;
    
    return Scaffold(
      appBar: AppBar(title: const Text("My Gallery")),
      body: items.isEmpty
          ? const Center(child: Text("No favorites yet. Double tap an image!", style: TextStyle(color: Colors.grey)))
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) => GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenViewer(item: items[i]))),
                child: Image.network(items[i].thumbnailUrl, fit: BoxFit.cover),
              ),
            ),
    );
  }
}

// --- ЭКРАН ЛОГОВ ---
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Logs"),
        actions: [IconButton(icon: const Icon(Icons.delete), onPressed: () => LoggerService().clear())],
      ),
      body: StreamBuilder<List<LogEntry>>(
        stream: LoggerService().stream,
        initialData: LoggerService().logs,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: logs.length,
            separatorBuilder: (_,__) => const Divider(height: 1, color: Colors.white10),
            itemBuilder: (ctx, i) {
              final log = logs[i];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${log.time.hour}:${log.time.minute}:${log.time.second}",
                      style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      color: log.isError ? Colors.red.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                      child: Text(log.tag, style: TextStyle(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold,
                        color: log.isError ? Colors.redAccent : Colors.blueAccent
                      )),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(log.message, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
