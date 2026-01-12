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
  final String thumbnailUrl; // Для превью видео
  final ContentType type;
  final String sourceName;
  final bool isNSFW;

  MediaItem({
    required this.url,
    required this.type,
    required this.sourceName,
    this.thumbnailUrl = '',
    this.isNSFW = false,
  });
}

class ContentSource {
  String id;
  String name;
  String url; // Реальный URL для парсинга
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
}

// --- 2. UTILS & LOGGER ---

class AppLogger {
  static final List<String> logs = [];
  static final StreamController<List<String>> _controller = StreamController.broadcast();
  static Stream<List<String>> get stream => _controller.stream;

  static void log(String tag, String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 19);
    final entry = "[$t] [$tag] $msg";
    print(entry); // Console
    logs.add(entry);
    if (logs.length > 500) logs.removeAt(0);
    _controller.add(List.from(logs));
  }
}

// "Furry phrases" generator
String getLoadingPhrase() {
  const phrases = [
    "Polishing beans...",
    "Wagging tail...",
    "Fetching art...",
    "Booping snoots...",
    "Loading fluff...",
    "Searching for cuties...",
    "OwO what's this? Loading...",
  ];
  return phrases[Random().nextInt(phrases.length)];
}

// --- 3. UNIVERSAL SCRAPER ENGINE ---

class ScraperEngine {
  static const String _userAgent = "Mozilla/5.0 (compatible; LunyaHub/6.0; +http://lunya.app)";

  static Future<List<MediaItem>> scrape(ContentSource source) async {
    try {
      if (source.type == SourceType.reddit) {
        return _parseRedditJson(source);
      } else {
        // Universal HTML Parser for TG Web, Nitter, etc.
        return _parseHtml(source);
      }
    } catch (e) {
      AppLogger.log("SCRAPER", "Error parsing ${source.name}: $e");
      return [];
    }
  }

  static Future<List<MediaItem>> _parseRedditJson(ContentSource source) async {
    // Reddit JSON API is cleaner than HTML scraping
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
      final bool over18 = d['over_18'] ?? false;
      
      // NSFW Check at item level
      final bool itemIsNSFW = source.isNSFW || over18;

      ContentType type = ContentType.image;
      if (u.contains('.gif') || u.contains('.mp4') || d['is_video'] == true) {
        type = ContentType.gif;
      }

      if (u.contains('i.redd.it') || u.contains('v.redd.it') || u.contains('imgur')) {
        items.add(MediaItem(
          url: u, 
          type: type, 
          sourceName: source.name,
          isNSFW: itemIsNSFW
        ));
      }
    }
    return items;
  }

  static Future<List<MediaItem>> _parseHtml(ContentSource source) async {
    // Powerful Regex-based HTML scraper for TG Web / Nitter
    AppLogger.log("NET", "GET HTML: ${source.url}");
    final resp = await http.get(Uri.parse(source.url), headers: {'User-Agent': _userAgent});
    if (resp.statusCode != 200) throw Exception("HTTP ${resp.statusCode}");
    
    final html = resp.body;
    List<MediaItem> items = [];

    // 1. Find Images (CSS background or img src)
    // Telegram Web uses background-image:url('...')
    final bgImgRegex = RegExp(r"background-image:url\('([^']+)'\)");
    final imgTagRegex = RegExp(r'<img[^>]+src="([^">]+)"');
    
    // 2. Find Videos/GIFs
    final videoTagRegex = RegExp(r'<video[^>]+src="([^">]+)"');

    // Parse Images
    for (var m in bgImgRegex.allMatches(html)) {
      _addItem(items, m.group(1), ContentType.image, source);
    }
    for (var m in imgTagRegex.allMatches(html)) {
      _addItem(items, m.group(1), ContentType.image, source);
    }

    // Parse Videos
    for (var m in videoTagRegex.allMatches(html)) {
      _addItem(items, m.group(1), ContentType.gif, source); // Treat short videos as gifs
    }

    AppLogger.log("SCRAPER", "Found ${items.length} items in HTML");
    return items;
  }

  static void _addItem(List<MediaItem> list, String? url, ContentType type, ContentSource source) {
    if (url == null) return;
    if (url.startsWith('//')) url = 'https:$url'; // Fix relative protocol
    if (url.contains('emoji') || url.contains('icon') || url.contains('logo')) return; // Filter junk
    
    // Basic dup check
    if (!list.any((i) => i.url == url)) {
      list.add(MediaItem(
        url: url, 
        type: type, 
        sourceName: source.name,
        isNSFW: source.isNSFW
      ));
    }
  }
}

// --- 4. UI MAIN ---

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Translucent system bars for edge-to-edge look
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
      title: 'Lunya Hub 6.0',
      // Strict Dark Theme
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C4DFF), // Deep Purple Accent
          secondary: Color(0xFF64FFDA), // Teal Accent
          surface: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
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

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Data
  List<MediaItem> _imgQueue = [];
  List<MediaItem> _gifQueue = [];
  MediaItem? _currentImg;
  MediaItem? _currentGif;
  
  // Settings
  bool _isLoading = false;
  bool _allowNSFW = false; 
  String _loadingText = "Initializing...";

  // Sources (Mixed: Reddit + Web Parsing)
  List<ContentSource> sources = [
    ContentSource(id: 'r1', name: 'r/Furry', url: 'https://www.reddit.com/r/furry', type: SourceType.reddit),
    ContentSource(id: 'r2', name: 'r/FurryArt', url: 'https://www.reddit.com/r/furryart', type: SourceType.reddit),
    // TG Web example (using /s/ preview)
    ContentSource(id: 'tg1', name: 'TG: Furry Archive', url: 'https://t.me/s/furry_art_archive', type: SourceType.telegram),
    // NSFW Sources (Disabled by default)
    ContentSource(id: 'r3', name: 'r/Yiff', url: 'https://www.reddit.com/r/yiff', type: SourceType.reddit, isNSFW: true, isActive: false),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AppLogger.log("SYS", "Lunya Hub 6.0 Started");
    _fetchBatch();
  }

  // --- LOGIC ---

  Future<void> _fetchBatch() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _loadingText = getLoadingPhrase();
    });

    final active = sources.where((s) => s.isActive && (s.isNSFW == false || _allowNSFW == true)).toList();
    
    if (active.isEmpty) {
      _showToast("No active sources! Check settings.");
      setState(() => _isLoading = false);
      return;
    }

    // Pick random source
    final source = active[Random().nextInt(active.length)];
    AppLogger.log("CORE", "Fetching from ${source.name}...");

    final newItems = await ScraperEngine.scrape(source);

    if (newItems.isNotEmpty) {
      newItems.shuffle();
      setState(() {
        for (var item in newItems) {
          // Global NSFW Filter Logic:
          // If NSFW is OFF, we strictly skip any item marked NSFW
          if (!_allowNSFW && item.isNSFW) continue;

          if (item.type == ContentType.image) {
            _imgQueue.add(item);
          } else {
            _gifQueue.add(item);
          }
        }
        
        // Auto-fill current if empty
        if (_currentImg == null && _imgQueue.isNotEmpty) _currentImg = _imgQueue.removeAt(0);
        if (_currentGif == null && _gifQueue.isNotEmpty) _currentGif = _gifQueue.removeAt(0);
      });
    } else {
      AppLogger.log("CORE", "Source returned 0 valid items.");
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
      final dir = await getApplicationDocumentsDirectory(); // Safe public dir on Android
      // On Android 10+ scoped storage, this goes to App Data. 
      // For Gallery access, we'd need MediaStore API (complex), but this saves to accessible file.
      final ext = item.url.split('.').last.substring(0, 3);
      final file = File('${dir.path}/lunya_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(resp.bodyBytes);
      _showToast("Saved to: ${file.path}");
      AppLogger.log("IO", "File saved");
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

  // --- UI COMPONENTS ---

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.deepPurpleAccent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  // Custom Source Dialog
  void _addCustomSourceDialog() {
    String url = "";
    String name = "";
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E1E24),
      title: const Text("Add Custom Source"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Supports: Reddit URL, Telegram Web (t.me/s/...), Nitter", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: "Name (e.g. My Channel)", filled: true),
            onChanged: (v) => name = v,
          ),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(labelText: "URL (https://...)", filled: true),
            onChanged: (v) => url = v,
          ),
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
                url: url, // User provided raw URL
                type: SourceType.custom, // Scraper will handle as HTML
              ));
            });
            AppLogger.log("CFG", "Added custom source: $url");
            Navigator.pop(ctx);
            _showToast("Source Added!");
          }
        }, child: const Text("Add")),
      ],
    ));
  }

  // Log Screen
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
      extendBody: true, // For gesture area
      drawer: Drawer(
        backgroundColor: const Color(0xFF101014),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Lunya Hub v6.0"),
              accountEmail: const Text("Ultimate Edition"),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.deepPurple, child: Icon(Icons.pets, color: Colors.white)),
              decoration: const BoxDecoration(color: Colors.black),
            ),
            SwitchListTile(
              title: const Text("NSFW Filter"),
              subtitle: Text(_allowNSFW ? "Status: UNLOCKED 🔞" : "Status: SAFE ✅", style: TextStyle(color: _allowNSFW ? Colors.red : Colors.green)),
              value: _allowNSFW,
              activeColor: Colors.red,
              secondary: const Icon(Icons.lock_open),
              onChanged: (val) {
                setState(() {
                  _allowNSFW = val;
                  _imgQueue.clear(); _gifQueue.clear();
                  _currentImg = null; _currentGif = null;
                });
                _fetchBatch();
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(title: const Text("SOURCES"), trailing: IconButton(icon: const Icon(Icons.add), onPressed: _addCustomSourceDialog)),
            ...sources.map((s) => CheckboxListTile(
              title: Text(s.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(s.type.name, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              value: s.isActive,
              activeColor: Colors.deepPurple,
              onChanged: (v) => setState(() => s.isActive = v!),
            )),
            const Divider(color: Colors.white24),
            ListTile(leading: const Icon(Icons.terminal), title: const Text("System Logs"), onTap: _openLogs),
          ],
        ),
      ),
      body: GestureDetector(
        // GESTURES for easier navigation
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) _next(); // Swipe Left -> Next
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) _download(); // Swipe Down -> Download
        },
        onDoubleTap: () => _showToast("Added to Favorites (Simulated) ❤️"),
        
        child: Stack(
          children: [
            // 1. BACKGROUND
            Container(color: Colors.black),
            if (item != null)
               Positioned.fill(
                 child: Opacity(
                   opacity: 0.3, 
                   child: Image.network(item.url, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const SizedBox())
                 )
               ),

            // 2. MAIN CONTENT AREA
            SafeArea(
              child: Column(
                children: [
                  // HEADER
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
                          unselectedLabelColor: Colors.grey,
                          dividerColor: Colors.transparent,
                          onTap: (_) => setState((){}),
                          tabs: const [Tab(text: "ART"), Tab(text: "GIF")],
                        ),
                        IconButton(icon: const Icon(Icons.public), onPressed: _addCustomSourceDialog), // Quick Add
                      ],
                    ),
                  ),

                  // IMAGE VIEWER
                  Expanded(
                    child: Center(
                      child: _isLoading 
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            const CircularProgressIndicator(), 
                            const SizedBox(height: 20),
                            Text(_loadingText, style: const TextStyle(color: Colors.white54))
                          ])
                        : item == null 
                          ? const Text("Queue empty. Check sources.") 
                          : Image.network(
                              item.url, 
                              fit: BoxFit.contain,
                              loadingBuilder: (c,child,p) => p==null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorBuilder: (c,e,s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                    ),
                  ),

                  // BOTTOM CONTROLS (Padding for Android Gestures)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), // Bottom padding ensures buttons aren't on nav bar
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                         _CircleButton(icon: Icons.download, onTap: _download),
                         // BIG NEXT BUTTON
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
