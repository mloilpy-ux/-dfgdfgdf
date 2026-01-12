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

// --- 1. DATA MODELS & ENUMS ---

enum SourceType { reddit, telegram, customUrl }
enum ContentType { image, gif }

class MediaItem {
  final String url;
  final ContentType type;
  final String sourceName;

  MediaItem(this.url, this.type, this.sourceName);
}

class ContentSource {
  String id;
  String name;
  String identifier; // subreddit or channel id
  SourceType type;
  bool isNSFW;
  bool isActive;

  ContentSource({
    required this.id,
    required this.name,
    required this.identifier,
    required this.type,
    this.isNSFW = false,
    this.isActive = true,
  });
}

// --- 2. ADVANCED LOGGER ---

class AppLogger {
  static final List<String> logs = [];
  static final StreamController<List<String>> _controller = StreamController.broadcast();
  static Stream<List<String>> get stream => _controller.stream;

  static void log(String tag, String message) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    final entry = "[$timeStr] [$tag] $message";
    
    // Print to console for dev
    print(entry);
    
    logs.add(entry);
    if (logs.length > 500) logs.removeAt(0);
    _controller.add(List.from(logs));
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const LunyaApp());
}

class LunyaApp extends StatelessWidget {
  const LunyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lunya Hub 5.0',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EA),
          brightness: Brightness.dark,
          surface: const Color(0xFF181820),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
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
  // --- STATE ---
  late TabController _tabController;
  
  // Media Queues
  List<MediaItem> imageQueue = [];
  List<MediaItem> gifQueue = [];
  
  MediaItem? currentImage;
  MediaItem? currentGif;
  
  bool isLoading = false;
  bool allowNSFW = false; // Global NSFW Filter

  // Initial Sources
  List<ContentSource> sources = [
    ContentSource(id: 'r1', name: 'Reddit: r/Furry', identifier: 'furry', type: SourceType.reddit),
    ContentSource(id: 'r2', name: 'Reddit: r/FurryArt', identifier: 'furryart', type: SourceType.reddit),
    ContentSource(id: 'r3', name: 'Reddit: r/Yiff', identifier: 'yiff', type: SourceType.reddit, isNSFW: true, isActive: false),
    ContentSource(id: 'r4', name: 'Reddit: r/Furry_IRL', identifier: 'furry_irl', type: SourceType.reddit),
    ContentSource(id: 'tg1', name: 'TG: Furry Art Archive', identifier: 'furry_art_archive', type: SourceType.telegram),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AppLogger.log("SYS", "App Initialized v5.0");
    _refreshContent();
  }

  // --- LOGIC: FETCHING ---

  Future<void> _refreshContent() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    AppLogger.log("NET", "Starting refresh cycle (NSFW: $allowNSFW)...");

    // Filter active sources based on settings
    final activeSources = sources.where((s) {
      if (!s.isActive) return false;
      if (s.isNSFW && !allowNSFW) return false; // Filter out NSFW sources if disabled
      return true;
    }).toList();

    if (activeSources.isEmpty) {
      AppLogger.log("WARN", "No suitable sources found. Please check settings.");
      _showSnack("No active sources! Check menu.", isError: true);
      setState(() => isLoading = false);
      return;
    }

    // Shuffle sources to get mix
    activeSources.shuffle();
    
    // Fetch from random source
    final source = activeSources.first;
    AppLogger.log("NET", "Fetching from: ${source.name} (${source.type})");

    try {
      List<MediaItem> newItems = [];
      
      if (source.type == SourceType.reddit) {
        newItems = await _fetchReddit(source);
      } else if (source.type == SourceType.telegram) {
        newItems = await _fetchTelegram(source);
      }

      // Distribute to queues
      int imgCount = 0;
      int gifCount = 0;
      
      for (var item in newItems) {
        if (item.type == ContentType.image) {
          imageQueue.add(item);
          imgCount++;
        } else {
          gifQueue.add(item);
          gifCount++;
        }
      }
      
      // Shuffle queues
      imageQueue.shuffle();
      gifQueue.shuffle();

      // Update Current Items if empty
      if (currentImage == null && imageQueue.isNotEmpty) {
        currentImage = imageQueue.removeAt(0);
      }
      if (currentGif == null && gifQueue.isNotEmpty) {
        currentGif = gifQueue.removeAt(0);
      }

      AppLogger.log("STATS", "Added $imgCount images, $gifCount GIFs.");
      
    } catch (e) {
      AppLogger.log("ERR", "Fetch failed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<MediaItem>> _fetchReddit(ContentSource source) async {
    final url = 'https://www.reddit.com/r/${source.identifier}/hot.json?limit=30';
    AppLogger.log("HTTP", "GET $url");
    
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'LunyaHub/5.0'});
    if (response.statusCode != 200) {
      AppLogger.log("HTTP", "Error ${response.statusCode}");
      return [];
    }

    final data = json.decode(response.body);
    final posts = data['data']['children'] as List;
    List<MediaItem> items = [];

    for (var post in posts) {
      final d = post['data'];
      final u = d['url'] as String;
      final bool over18 = d['over_18'] ?? false;

      // Double check NSFW filter
      if (!allowNSFW && over18) continue;

      if (u.contains('.gif') || u.contains('.mp4')) {
         // Basic GIF detection (Reddit often hosts mp4 as gif)
         // For async_wallpaper support, we prefer static images, but for viewing we allow GIFs
         items.add(MediaItem(u, ContentType.gif, source.name));
      } else if (u.endsWith('.jpg') || u.endsWith('.png') || u.endsWith('.jpeg')) {
         items.add(MediaItem(u, ContentType.image, source.name));
      }
    }
    return items;
  }

  Future<List<MediaItem>> _fetchTelegram(ContentSource source) async {
    final clean = source.identifier.replaceAll('@', '');
    final url = 'https://t.me/s/$clean';
    AppLogger.log("HTTP", "Scraping TG: $url");
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final regExp = RegExp(r"background-image:url\('([^']+)'\)");
    final matches = regExp.allMatches(response.body);
    
    List<MediaItem> items = [];
    for (var m in matches) {
      String? link = m.group(1);
      if (link != null && !link.contains("emoji")) {
        items.add(MediaItem(link, ContentType.image, source.name));
      }
    }
    return items;
  }

  // --- ACTIONS ---

  void nextMedia() {
    setState(() {
      if (_tabController.index == 0) {
        // Image Tab
        if (imageQueue.isNotEmpty) {
          currentImage = imageQueue.removeAt(0);
          AppLogger.log("UI", "Next Image shown. Queue: ${imageQueue.length}");
        } else {
          _refreshContent();
        }
      } else {
        // GIF Tab
        if (gifQueue.isNotEmpty) {
          currentGif = gifQueue.removeAt(0);
          AppLogger.log("UI", "Next GIF shown. Queue: ${gifQueue.length}");
        } else {
          _refreshContent();
        }
      }
    });
  }

  Future<void> downloadMedia() async {
    final item = _tabController.index == 0 ? currentImage : currentGif;
    if (item == null) return;

    AppLogger.log("IO", "Downloading ${item.url}...");
    try {
      final response = await http.get(Uri.parse(item.url));
      final dir = await getApplicationDocumentsDirectory();
      final ext = item.url.split('.').last.substring(0, 3);
      final file = File('${dir.path}/lunya_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(response.bodyBytes);
      
      AppLogger.log("IO", "Saved to ${file.path}");
      _showSnack("Saved to app files!");
    } catch (e) {
      AppLogger.log("ERR", "Download failed: $e");
    }
  }

  Future<void> setWallpaper() async {
    if (currentImage == null) return;
    AppLogger.log("SYS", "Setting wallpaper...");
    try {
      final response = await http.get(Uri.parse(currentImage!.url));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wall_temp.jpg');
      await file.writeAsBytes(response.bodyBytes);
      
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      _showSnack("Wallpaper Updated!");
    } catch (e) {
      AppLogger.log("ERR", "Wallpaper set failed: $e");
    }
  }

  Future<void> launchBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      AppLogger.log("SYS", "Launched browser: $url");
    }
  }

  // --- DIALOGS & SCREENS ---

  void _openSourceManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E24),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Менеджер Источников", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: sources.length,
                  itemBuilder: (ctx, i) {
                    final s = sources[i];
                    return CheckboxListTile(
                      title: Text(s.name),
                      subtitle: Text("${s.type.name} • ${s.isNSFW ? 'NSFW' : 'SFW'}", style: TextStyle(color: s.isNSFW ? Colors.red : Colors.grey)),
                      value: s.isActive,
                      secondary: Icon(s.type == SourceType.reddit ? Icons.reddit : Icons.send),
                      onChanged: (val) {
                        setModalState(() => s.isActive = val!);
                        setState(() {});
                        AppLogger.log("CFG", "Source ${s.name} active: $val");
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              TextField(
                decoration: const InputDecoration(
                  hintText: "Добавить: ID канала или r/Subreddit",
                  filled: true,
                  border: OutlineInputBorder()
                ),
                onSubmitted: (val) {
                   if (val.isEmpty) return;
                   setModalState(() {
                     sources.add(ContentSource(
                       id: DateTime.now().toString(),
                       name: "Custom: $val",
                       identifier: val,
                       type: val.startsWith('r/') ? SourceType.reddit : SourceType.telegram
                     ));
                   });
                   AppLogger.log("CFG", "Added custom source: $val");
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openLogScreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text("System Logs")),
      backgroundColor: Colors.black,
      body: StreamBuilder<List<String>>(
        stream: AppLogger.stream,
        initialData: AppLogger.logs,
        builder: (ctx, snap) {
          final logs = snap.data ?? [];
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(logs[logs.length - 1 - i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)),
            ),
          );
        },
      ),
    )));
  }

  void _openBrowserTools() {
    showDialog(context: context, builder: (_) => SimpleDialog(
      title: const Text("Web Tools (External)"),
      children: [
        SimpleDialogOption(
          child: const Row(children: [Icon(Icons.public), SizedBox(width: 10), Text("Open Twitter Search")]),
          onPressed: () => launchBrowser("https://twitter.com/search?q=furry%20art&f=media"),
        ),
        SimpleDialogOption(
          child: const Row(children: [Icon(Icons.send), SizedBox(width: 10), Text("Open Telegram Web")]),
          onPressed: () => launchBrowser("https://web.telegram.org"),
        ),
        SimpleDialogOption(
          child: const Row(children: [Icon(Icons.image_search), SizedBox(width: 10), Text("Open FurAffinity")]),
          onPressed: () => launchBrowser("https://www.furaffinity.net"),
        ),
      ],
    ));
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.teal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF15151A),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Lunya Hub v5.0"),
              accountEmail: Text(allowNSFW ? "Mode: NSFW (Uncensored)" : "Mode: SFW (Safe)"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: allowNSFW ? Colors.red : Colors.green,
                child: Icon(allowNSFW ? Icons.warning : Icons.shield, color: Colors.white),
              ),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            ),
            SwitchListTile(
              title: const Text("NSFW Filter"),
              subtitle: const Text("Show 18+ Content"),
              value: allowNSFW,
              secondary: const Icon(Icons.explicit, color: Colors.red),
              onChanged: (val) {
                setState(() {
                  allowNSFW = val;
                  // Activate NSFW sources if true
                  for (var s in sources) {
                    if (s.isNSFW) s.isActive = val; 
                  }
                  imageQueue.clear(); 
                  gifQueue.clear();
                });
                _refreshContent();
                AppLogger.log("CFG", "NSFW Mode set to $val");
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.source),
              title: const Text("Источники (Sources)"),
              onTap: () { Navigator.pop(context); _openSourceManager(); },
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text("Веб-инструменты"),
              onTap: () { Navigator.pop(context); _openBrowserTools(); },
            ),
             ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text("Системный Лог"),
              onTap: () { Navigator.pop(context); _openLogScreen(); },
            ),
          ],
        ),
      ),
      
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            title: const Text("LUNYA HUB", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            centerTitle: true,
            actions: [
              IconButton(icon: const Icon(Icons.terminal), onPressed: _openLogScreen),
              IconButton(icon: const Icon(Icons.public), onPressed: _openBrowserTools),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.deepPurpleAccent,
              tabs: const [
                Tab(icon: Icon(Icons.image), text: "IMAGES"),
                Tab(icon: Icon(Icons.gif), text: "GIFS / ANIM"),
              ],
            ),
          )
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // IMAGE TAB
            _buildMediaView(currentImage, false),
            // GIF TAB
            _buildMediaView(currentGif, true),
          ],
        ),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            FloatingActionButton(
              heroTag: "dl",
              onPressed: downloadMedia,
              backgroundColor: Colors.blueGrey,
              child: const Icon(Icons.download),
            ),
            FloatingActionButton.extended(
              heroTag: "next",
              onPressed: nextMedia,
              label: const Text("NEXT"),
              icon: const Icon(Icons.skip_next),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            FloatingActionButton(
              heroTag: "wall",
              onPressed: setWallpaper,
              backgroundColor: Colors.deepPurpleAccent,
              child: const Icon(Icons.wallpaper),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaView(MediaItem? item, bool isGif) {
    if (isLoading && item == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (item == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.layers_clear, size: 64, color: Colors.grey),
            const SizedBox(height: 10),
            Text("No content loaded.\nCheck internet or Sources.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _refreshContent, child: const Text("Refresh"))
          ],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Blur
        Image.network(item.url, fit: BoxFit.cover, color: Colors.black.withOpacity(0.8), colorBlendMode: BlendMode.darken),
        
        // Main Content
        InteractiveViewer(
          child: Center(
            child: Image.network(
              item.url,
              fit: BoxFit.contain,
              loadingBuilder: (ctx, child, prog) => prog == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, size: 50, color: Colors.red),
            ),
          ),
        ),
        
        // Info Badge
        Positioned(
          top: 10, left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(item.sourceName.contains("Reddit") ? Icons.reddit : Icons.send, size: 12, color: Colors.white),
                const SizedBox(width: 5),
                Text(item.sourceName, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        )
      ],
    );
  }
}
