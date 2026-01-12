import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

// --- 1. МОДЕЛИ ДАННЫХ ---

enum ContentType { image, gif }

class MediaItem {
  final String id;
  final String url;
  final ContentType type;
  final String sourceName;
  final bool isNSFW;
  bool isFavorite;

  MediaItem({
    required this.id,
    required this.url,
    required this.type,
    required this.sourceName,
    this.isNSFW = false,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'url': url, 'type': type.index, 'source': sourceName, 'nsfw': isNSFW
  };
}

class ContentSource {
  String id;
  String name;
  String url;
  bool isActive;
  bool isNSFW;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    this.isActive = true,
    this.isNSFW = false,
  });
}

// --- 2. СИСТЕМА ЛОГИРОВАНИЯ ---

class AppLogger {
  static final List<String> _logs = [];
  static final _controller = StreamController<List<String>>.broadcast();
  static Stream<List<String>> get stream => _controller.stream;

  static void log(String tag, String msg) {
    final time = DateTime.now().toString().substring(11, 19);
    final entry = "[$time] [$tag] $msg";
    _logs.add(entry);
    if (_logs.length > 200) _logs.removeAt(0);
    _controller.add(List.from(_logs.reversed));
    debugPrint(entry);
  }
}

// --- 3. ЯДРО СКРАПИНГА И КЭША ---

class ScraperEngine {
  static final Set<String> _seenUrls = {}; // Защита от повторов

  static Future<List<MediaItem>> fetch(ContentSource source) async {
    AppLogger.log("SCRAPER", "Начинаю опрос: ${source.name}");
    
    try {
      if (source.url.contains("reddit.com")) {
        return await _parseReddit(source);
      } else if (source.url.contains("t.me/s/")) {
        return await _parseTelegram(source);
      } else {
        return await _parseGeneric(source);
      }
    } catch (e) {
      AppLogger.log("ERROR", "Ошибка парсинга ${source.name}: $e");
      return [];
    }
  }

  static Future<List<MediaItem>> _parseReddit(ContentSource source) async {
    final cleanUrl = source.url.endsWith('/') ? source.url : "${source.url}/";
    final apiUrl = "${cleanUrl}hot.json?limit=30";
    
    final response = await http.get(Uri.parse(apiUrl), headers: {"User-Agent": "LunyaHub/6.2"});
    if (response.statusCode != 200) throw "HTTP ${response.statusCode}";

    final data = json.decode(response.body);
    final List posts = data['data']['children'];
    List<MediaItem> results = [];

    for (var post in posts) {
      final d = post['data'];
      final url = d['url'] as String;
      
      if (_seenUrls.contains(url)) continue;
      
      bool isGif = url.contains(".gif") || d['is_video'] == true || url.contains("v.redd.it");
      
      results.add(MediaItem(
        id: d['id'],
        url: url,
        type: isGif ? ContentType.gif : ContentType.image,
        sourceName: source.name,
        isNSFW: d['over_18'] ?? source.isNSFW,
      ));
      _seenUrls.add(url);
    }
    return results;
  }

  static Future<List<MediaItem>> _parseTelegram(ContentSource source) async {
    final response = await http.get(Uri.parse(source.url));
    final html = response.body;
    List<MediaItem> results = [];

    // Регулярка для извлечения фото из превью постов Telegram Web
    final imgRegex = RegExp(r"background-image:url\('([^']+)'\)");
    final matches = imgRegex.allMatches(html);

    for (var m in matches) {
      final url = m.group(1)!;
      if (_seenUrls.contains(url)) continue;
      
      results.add(MediaItem(
        id: url.hashCode.toString(),
        url: url,
        type: ContentType.image,
        sourceName: source.name,
        isNSFW: source.isNSFW,
      ));
      _seenUrls.add(url);
    }
    return results;
  }

  static Future<List<MediaItem>> _parseGeneric(ContentSource source) async {
    // Базовый парсер для остальных ссылок
    AppLogger.log("SCRAPER", "Использую универсальный метод для ${source.name}");
    return []; 
  }
}

// --- 4. ОСНОВНОЙ ИНТЕРФЕЙС ---

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LunyaApp());
}

class LunyaApp extends StatelessWidget {
  const LunyaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F0F12),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Состояние
  List<MediaItem> _queue = [];
  List<MediaItem> _favorites = [];
  bool _isLoading = false;
  bool _nsfwEnabled = false;
  MediaItem? _currentItem;

  final List<ContentSource> _sources = [
    ContentSource(id: '1', name: 'r/Furry_irl', url: 'https://www.reddit.com/r/furry_irl'),
    ContentSource(id: '2', name: 'r/FurryArt', url: 'https://www.reddit.com/r/furryart'),
    ContentSource(id: '3', name: 'TG: Furry Archive', url: 'https://t.me/s/furry_art_archive'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadFavorites();
    _fetchContent();
  }

  // Логика получения данных
  Future<void> _fetchContent() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    AppLogger.log("CORE", "Запуск обновления ленты...");

    final activeSources = _sources.where((s) => s.isActive && (_nsfwEnabled || !s.isNSFW)).toList();
    
    if (activeSources.isEmpty) {
      AppLogger.log("CORE", "Нет активных источников!");
      setState(() => _isLoading = false);
      return;
    }

    // Опрашиваем случайный источник из активных
    final src = activeSources[Random().nextInt(activeSources.length)];
    final newItems = await ScraperEngine.fetch(src);

    setState(() {
      // Фильтрация по типу (Картинки vs Гифки) и NSFW
      final filtered = newItems.where((item) {
        bool typeMatch = (_tabController.index == 0) 
            ? item.type == ContentType.image 
            : item.type == ContentType.gif;
        bool nsfwMatch = _nsfwEnabled || !item.isNSFW;
        return typeMatch && nsfwMatch;
      }).toList();

      _queue.addAll(filtered);
      if (_currentItem == null && _queue.isNotEmpty) {
        _currentItem = _queue.removeAt(0);
      }
      _isLoading = false;
    });
    
    AppLogger.log("CORE", "Добавлено в очередь: ${newItems.length} объектов");
  }

  void _nextItem() {
    setState(() {
      if (_queue.isNotEmpty) {
        _currentItem = _queue.removeAt(0);
      } else {
        _currentItem = null;
        _fetchContent();
      }
    });
  }

  // Работа с Избранным ("Лапки")
  void _toggleFavorite() {
    if (_currentItem == null) return;
    setState(() {
      _currentItem!.isFavorite = !_currentItem!.isFavorite;
      if (_currentItem!.isFavorite) {
        _favorites.add(_currentItem!);
        _showToast("Мяу! Сохранено в лапки 🐾");
      }
    });
    _saveFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('favs');
    if (data != null) {
      // Здесь должна быть десериализация
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    AppLogger.log("SYS", "Избранное обновлено: ${_favorites.length}");
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Theme.of(context).colorScheme.primary,
    ));
  }

  // --- UI КОМПОНЕНТЫ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // Задний фон (размытый арт)
          if (_currentItem != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: CachedNetworkImage(imageUrl: _currentItem!.url, fit: BoxFit.cover),
              ),
            ),
          
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMainViewer()),
                _buildBottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.menu_open, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          )),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: "АРТЫ"), Tab(text: "ГИФКИ")],
          ),
          IconButton(
            icon: const Icon(Icons.terminal, color: Colors.greenAccent),
            onPressed: _showLogs,
          ),
        ],
      ),
    );
  }

  Widget _buildMainViewer() {
    if (_isLoading && _currentItem == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.SearchOff, size: 64, color: Colors.grey),
            const Text("Контент закончился"),
            TextButton(onPressed: _fetchContent, child: const Text("Попробовать еще раз")),
          ],
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity! < 0) _nextItem(); // Свайп влево
      },
      onDoubleTap: _toggleFavorite,
      child: Center(
        child: Hero(
          tag: _currentItem!.url,
          child: CachedNetworkImage(
            imageUrl: _currentItem!.url,
            fit: BoxFit.contain,
            placeholder: (c, u) => const CircularProgressIndicator(),
            errorWidget: (c, u, e) => const Icon(Icons.broken_image, size: 80),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ActionButton(
            icon: _currentItem?.isFavorite == true ? Icons.pets : Icons.pets_outlined,
            color: _currentItem?.isFavorite == true ? Colors.orange : Colors.white24,
            onTap: _toggleFavorite,
          ),
          FloatingActionButton.extended(
            onPressed: _nextItem,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            label: const Text("СЛЕДУЮЩИЙ"),
            icon: const Icon(Icons.arrow_forward_ios),
          ),
          _ActionButton(
            icon: Icons.download_rounded,
            onTap: () => _showToast("Скачивание начато..."),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF121216),
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Center(
              child: Column(
                children: [
                  CircleAvatar(radius: 30, backgroundColor: Colors.deepPurpleAccent, child: Icon(Icons.auto_awesome, color: Colors.white)),
                  SizedBox(height: 10),
                  Text("LUNYA HUB 6.2", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text("Content Aggregator", style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          SwitchListTile(
            title: const Text("18+ Фильтр (NSFW)"),
            subtitle: Text(_nsfwEnabled ? "РАЗБЛОКИРОВАНО" : "ЗАБЛОКИРОВАНО", 
                style: TextStyle(color: _nsfwEnabled ? Colors.red : Colors.green, fontSize: 10)),
            value: _nsfwEnabled,
            onChanged: (v) => setState(() { 
              _nsfwEnabled = v; 
              _queue.clear();
              _currentItem = null;
              _fetchContent();
            }),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ИСТОЧНИКИ", style: TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addSourceDialog),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _sources.length,
              itemBuilder: (context, index) {
                final s = _sources[index];
                return CheckboxListTile(
                  title: Text(s.name, style: const TextStyle(fontSize: 14)),
                  value: s.isActive,
                  onChanged: (v) => setState(() => s.isActive = v!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SYSTEM TERMINAL", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24),
            Expanded(
              child: StreamBuilder<List<String>>(
                stream: AppLogger.stream,
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (c, i) => Text(logs[i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSourceDialog() {
    String name = "";
    String url = "";
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Новый источник"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(decoration: const InputDecoration(hintText: "Название (например: r/art)"), onChanged: (v) => name = v),
          TextField(decoration: const InputDecoration(hintText: "URL ссылки"), onChanged: (v) => url = v),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
        ElevatedButton(onPressed: () {
          if (name.isNotEmpty && url.isNotEmpty) {
            setState(() => _sources.add(ContentSource(id: url, name: name, url: url)));
            AppLogger.log("CFG", "Добавлен источник: $name");
            Navigator.pop(context);
          }
        }, child: const Text("Добавить")),
      ],
    ));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton({required this.icon, required this.onTap, this.color = Colors.white10});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 28),
      ),
    );
  }
}
