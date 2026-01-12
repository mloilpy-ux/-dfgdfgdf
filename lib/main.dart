import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

// --- 1. CORE MODELS ---

enum ContentType { image, gif, video }
enum SourceType { reddit, telegram, twitter, custom }

class MediaItem {
  final String url;
  final ContentType type;
  final String sourceName;
  final bool isNSFW; // Флаг контента

  MediaItem({
    required this.url,
    required this.type,
    required this.sourceName,
    this.isNSFW = false,
  });
}

class ContentSource {
  String id;
  String name;
  String url; 
  SourceType type;
  bool isActive;
  bool isNSFW; // Флаг источника

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.isActive = true,
    this.isNSFW = false,
  });
}

// --- 2. LOGGER ---

class AppLogger {
  static final List<String> logs = [];
  static final StreamController<List<String>> _controller = StreamController.broadcast();
  static Stream<List<String>> get stream => _controller.stream;

  static void log(String tag, String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    final entry = "[$t] [$tag] $msg";
    print(entry); 
    logs.add(entry);
    if (logs.length > 500) logs.removeAt(0);
    _controller.add(List.from(logs));
  }
}

// --- 3. SCRAPER ENGINE (С УЛУЧШЕННОЙ ФИЛЬТРАЦИЕЙ) ---

class ScraperEngine {
  static const String _userAgent = "Mozilla/5.0 (compatible; LunyaHub/6.1; +http://lunya.app)";

  // Ключевые слова для детекта NSFW в URL (для не-Reddit источников)
  static const List<String> _nsfwKeywords = ['nsfw', 'yiff', 'xxx', 'porn', '18+', 'adult'];

  static bool _detectNSFW(String url, ContentSource source) {
    // 1. Если сам источник помечен как NSFW -> весь контент NSFW
    if (source.isNSFW) return true;
    
    // 2. Эвристика по URL (для Telegram/Web)
    final lowerUrl = url.toLowerCase();
    for (var word in _nsfwKeywords) {
      if (lowerUrl.contains(word)) return true;
    }
    return false;
  }

  static Future<List<MediaItem>> scrape(ContentSource source) async {
    try {
      if (source.type == SourceType.reddit) {
        return _parseRedditJson(source);
      } else {
        return _parseHtml(source);
      }
    } catch (e) {
      AppLogger.log("SCRAPER", "Error parsing ${source.name}: $e");
      return [];
    }
  }

  static Future<List<MediaItem>> _parseRedditJson(ContentSource source) async {
    final url = source.url.endsWith('.json') ? source.url : '${source.url}/hot.json?limit=25';
    AppLogger.log("NET", "GET JSON: $url");
    
    final resp = await http.get(Uri.parse(url), headers: {'User-Agent': _userAgent});
    if (resp.statusCode != 200) throw Exception("HTTP ${resp.statusCode}");

    final data = json.decode(resp.body);
    final children = data['data']['children'] as List;
    List<MediaItem> items = [];

    for (var child in children) {
      final d = child['data'];
      final String u = d['url'];
      final bool over18 = d['over_18'] ?? false; // Reddit flag
      
      // NSFW Logic: Source flag OR Post flag
      final bool isItemNSFW = source.isNSFW || over18;

      ContentType type = ContentType.image;
      if (u.contains('.gif') || u.contains('.mp4') || d['is_video'] == true) {
        type = ContentType.gif;
      }

      if (u.contains('i.redd.it') || u.contains('v.redd.it') || u.contains('imgur')) {
        items.add(MediaItem(url: u, type: type, sourceName: source.name, isNSFW: isItemNSFW));
      }
    }
    return items;
  }

  static Future<List<MediaItem>> _parseHtml(ContentSource source) async {
    AppLogger.log("NET", "GET HTML: ${source.url}");
    final resp = await http.get(Uri.parse(source.url), headers: {'User-Agent': _userAgent});
    if (resp.statusCode != 200) throw Exception("HTTP ${resp.statusCode}");
    
    final html = resp.body;
    List<MediaItem> items = [];

    final bgImgRegex = RegExp(r"background-image:url\('([^']+)'\)");
    final imgTagRegex = RegExp(r'<img[^>]+src="([^">]+)"');
    final videoTagRegex = RegExp(r'<video[^>]+src="([^">]+)"');

    for (var m in bgImgRegex.allMatches(html)) {
      _addItem(items, m.group(1), ContentType.image, source);
    }
    for (var m in imgTagRegex.allMatches(html)) {
      _addItem(items, m.group(1), ContentType.image, source);
    }
    for (var m in videoTagRegex.allMatches(html)) {
      _addItem(items, m.group(1), ContentType.gif, source); 
    }

    AppLogger.log("SCRAPER", "Found ${items.length} items in HTML");
    return items;
  }

  static void _addItem(List<MediaItem> list, String? url, ContentType type, ContentSource source) {
    if (url == null) return;
    if (url.startsWith('//')) url = 'https:$url'; 
    if (url.contains('emoji') || url.contains('icon') || url.contains('logo')) return; 
    
    // Auto-detect NSFW for web links
    final bool isItemNSFW = _detectNSFW(url, source);

    if (!list.any((i) => i.url == url)) {
      list.add(MediaItem(url: url, type: type, sourceName: source.name, isNSFW: isItemNSFW));
    }
  }
}

// --- 4. UI MAIN ---

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lunya Hub 6.1',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF), 
          secondary: Color(0xFF64FFDA), 
          surface: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  List<MediaItem> _imgQueue = [];
  List<MediaItem> _gifQueue = [];
  MediaItem? _currentImg;
  MediaItem? _currentGif;
  
  bool _isLoading = false;
  bool _allowNSFW = false; // Глобальный переключатель (по умолчанию выключен)
  String _loadingText = "Initializing...";

  List<ContentSource> sources = [
    ContentSource(id: 'r1', name: 'r/Furry', url: 'https://www.reddit.com/r/furry', type: SourceType.reddit),
    ContentSource(id: 'r2', name: 'r/FurryArt', url: 'https://www.reddit.com/r/furryart', type: SourceType.reddit),
    ContentSource(id: 'tg1', name: 'TG: Furry Archive', url: 'https://t.me/s/furry_art_archive', type: SourceType.telegram),
    // NSFW Source (маркирован флагом isNSFW: true)
    ContentSource(id: 'r3', name: 'r/Yiff', url: 'https://www.reddit.com/r/yiff', type: SourceType.reddit, isNSFW: true, isActive: true),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AppLogger.log("SYS", "Lunya Hub 6.1 Started");
    _fetchBatch();
  }

  // --- MAIN FETCH LOGIC ---

  Future<void> _fetchBatch() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadingText = "Scanning sources...";
    });

    // 1. Фильтруем ИСТОЧНИКИ
    final activeSources = sources.where((s) {
      if (!s.isActive) return false;
      // Если глобальный NSFW выключен, а источник помечен как NSFW - пропускаем его полностью
      if (!_allowNSFW && s.isNSFW) return false;
      return true;
    }).toList();
    
    if (activeSources.isEmpty) {
      _showToast("No active SFW sources. Check settings.");
      setState(() => _isLoading = false);
      return;
    }

    final source = activeSources[Random().nextInt(activeSources.length)];
    AppLogger.log("CORE", "Fetching from ${source.name}...");

    final newItems = await ScraperEngine.scrape(source);

    if (newItems.isNotEmpty) {
      newItems.shuffle();
      setState(() {
        int addedCount = 0;
        for (var item in newItems) {
          // 2. Глобальная фильтрация КОНТЕНТА
          // Если NSFW выключен, а у картинки (даже из SFW источника) есть маркер - скипаем
          if (!_allowNSFW && item.isNSFW) {
             AppLogger.log("FILTER", "Blocked NSFW item: ${item.url}");
             continue; 
          }

          if (item.type == ContentType.image) {
            _imgQueue.add(item);
          } else {
            _gifQueue.add(item);
          }
          addedCount++;
        }
        
        if (addedCount == 0) {
           AppLogger.log("CORE", "All items filtered out (SFW Mode)");
        }

        if (_currentImg == null && _imgQueue.isNotEmpty) _currentImg = _imgQueue.removeAt(0);
        if (_currentGif == null && _gifQueue.isNotEmpty) _currentGif = _gifQueue.removeAt(0);
      });
    }

    setState(() => _isLoading = false);
  }

  void _next() {
    setState(() {
      if (_tabController.index == 0) {
        if (_imgQueue.isNotEmpty) {
          _currentImg = _imgQueue.removeAt(0);
        } else {
          _fetchBatch();
        }
      } else {
        if (_gifQueue.isNotEmpty) {
          _currentGif = _gifQueue.removeAt(0);
        } else {
          _fetchBatch();
        }
      }
    });
  }

  Future<void> _download() async {
    final item = _tabController.index == 0 ? _currentImg : _currentGif;
    if (item == null) return;
    
    _showToast("Downloading...");
    try {
      final resp = await http.get(Uri.parse(item.url));
      final dir = await getApplicationDocumentsDirectory(); 
      final ext = item.url.split('.').last.substring(0, 3);
      final file = File('${dir.path}/lunya_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(resp.bodyBytes);
      _showToast("Saved to: ${file.path}");
    } catch (e) {
      _showToast("Error: $e");
    }
  }

  Future<void> _setWallpaper() async {
    if (_currentImg == null) return;
    _showToast("Setting Wallpaper...");
    try {
      final resp = await http.get(Uri.parse(_currentImg!.url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wall.jpg');
      await file.writeAsBytes(resp.bodyBytes);
      
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      _showToast("Wallpaper Set!");
    } catch (e) {
      _showToast("Error: $e");
    }
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.deepPurpleAccent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  // --- UI DIALOGS ---

  void _addCustomSourceDialog() {
    String url = "";
    String name = "";
    bool isNsfwSrc = false;
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text("Add Source"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: "Name", filled: true),
            onChanged: (v) => name = v,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: "URL (Full Link)", filled: true, hintText: "https://t.me/s/my_channel"),
            onChanged: (v) => url = v,
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            title: const Text("Is this source NSFW?"),
            value: isNsfwSrc, 
            onChanged: (v) => setDialogState(() => isNsfwSrc = v!)
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        FilledButton(onPressed: () {
          if (url.isNotEmpty && name.isNotEmpty) {
            setState(() {
              sources.add(ContentSource(
                id: DateTime.now().toString(),
                name: name,
                url: url,
                type: SourceType.custom,
                isNSFW: isNsfwSrc // Сохраняем флаг
              ));
            });
            AppLogger.log("CFG", "Added custom source: $name (NSFW: $isNsfwSrc)");
            Navigator.pop(ctx);
            _showToast("Source Added!");
          }
        }, child: const Text("Add")),
      ],
    )));
  }

  void _openLogs() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text("System Terminal")),
      backgroundColor: Colors.black,
      body: StreamBuilder<List<String>>(
        stream: AppLogger.stream,
        initialData: AppLogger.logs,
        builder: (ctx, snap) {
          final logs = snap.data ?? [];
          return ListView.builder(
            reverse: true,
            itemCount: logs.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(logs[logs.length - 1 - i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 11)),
            ),
          );
        },
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final item = _tabController.index == 0 ? _currentImg : _currentGif;

    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        backgroundColor: const Color(0xFF101014),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Lunya Hub v6.1"),
              accountEmail: const Text("Global Filter Edition"),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.pets, color: Colors.white)),
              decoration: const BoxDecoration(color: Colors.black),
            ),
            
            // GLOBAL NSFW SWITCH
            SwitchListTile(
              title: const Text("NSFW Filter"),
              subtitle: Text(_allowNSFW ? "UNLOCKED 🔞" : "SAFE MODE ✅", style: TextStyle(color: _allowNSFW ? Colors.red : Colors.green)),
              value: _allowNSFW,
              activeColor: Colors.red,
              secondary: Icon(Icons.lock, color: _allowNSFW ? Colors.red : Colors.green),
              onChanged: (val) {
                setState(() {
                  _allowNSFW = val;
                  // Очищаем очереди, чтобы убрать уже загруженный нежелательный контент
                  _imgQueue.clear(); 
                  _gifQueue.clear();
                  _currentImg = null; 
                  _currentGif = null;
                });
                _fetchBatch(); // Перезагружаем контент с новыми правилами
              },
            ),
            const Divider(color: Colors.white24),
            
            ListTile(title: const Text("SOURCES"), trailing: IconButton(icon: const Icon(Icons.add), onPressed: _addCustomSourceDialog)),
            ...sources.map((s) => CheckboxListTile(
              title: Text(s.name, style: TextStyle(
                decoration: (!_allowNSFW && s.isNSFW) ? TextDecoration.lineThrough : null, // Зачеркнуть если заблокирован фильтром
                color: s.isNSFW ? Colors.redAccent : Colors.white
              )),
              subtitle: Text(s.type.name.toUpperCase()),
              value: s.isActive,
              // Блокируем чекбокс, если глобальный фильтр выключен, а источник NSFW
              onChanged: (!_allowNSFW && s.isNSFW) ? null : (v) => setState(() => s.isActive = v!),
              secondary: Icon(Icons.link, color: s.isNSFW ? Colors.red : Colors.white),
            )),
            
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.terminal), title: const Text("System Logs"), onTap: _openLogs),
          ],
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) { if (d.primaryVelocity! < 0) _next(); },
        onVerticalDragEnd: (d) { if (d.primaryVelocity! > 0) _download(); },
        
        child: Stack(
          children: [
            Container(color: Colors.black),
            if (item != null)
               Positioned.fill(
                 child: Opacity(
                   opacity: 0.3, 
                   child: Image.network(item.url, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const SizedBox())
                 )
               ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          indicatorColor: Colors.deepPurpleAccent,
                          labelColor: Colors.white,
                          dividerColor: Colors.transparent,
                          onTap: (_) => setState((){}),
                          tabs: const [Tab(text: "ART"), Tab(text: "GIF")],
                        ),
                        IconButton(icon: const Icon(Icons.public), onPressed: _addCustomSourceDialog),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Center(
                      child: _isLoading 
                        ? const CircularProgressIndicator()
                        : item == null 
                          ? const Text("Waiting for content...") 
                          : Image.network(
                              item.url, 
                              fit: BoxFit.contain,
                              loadingBuilder: (c,child,p) => p==null ? child : const CircularProgressIndicator(),
                              errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                         _CircleButton(icon: Icons.download, onTap: _download),
                         Expanded(
                           child: Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 20),
                             child: FloatingActionButton.extended(
                               onPressed: _next,
                               label: const Text("NEXT"),
                               icon: const Icon(Icons.arrow_forward),
                               backgroundColor: Colors.white,
                               foregroundColor: Colors.black,
                             ),
                           ),
                         ),
                         _CircleButton(icon: Icons.wallpaper, onTap: _setWallpaper, color: Colors.deepPurpleAccent),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _CircleButton({required this.icon, required this.onTap, this.color = const Color(0xFF2C2C35)});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
