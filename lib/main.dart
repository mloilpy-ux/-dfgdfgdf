import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. DATA MODELS
// ==========================================

enum SourceType { reddit, twitter, telegram, custom }
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
    'id': id, 'name': name, 'url': url,
    'type': type.index, 'isActive': isActive, 'isNSFW': isNSFW
  };

  factory ContentSource.fromJson(Map<String, dynamic> json) => ContentSource(
    id: json['id'], name: json['name'], url: json['url'],
    type: SourceType.values[json['type']],
    isActive: json['isActive'], isNSFW: json['isNSFW'],
  );
}

class MediaItem {
  final String id;
  final String url;
  final String previewUrl;
  final String title;
  final ContentType type;
  final String sourceName;
  final bool isNSFW;

  MediaItem({
    required this.id,
    required this.url,
    required this.previewUrl,
    required this.title,
    required this.type,
    required this.sourceName,
    required this.isNSFW,
  });
}

class LogEntry {
  final String time;
  final String tag;
  final String message;
  final Color color;

  LogEntry(this.tag, this.message, {this.color = Colors.white}) 
      : time = DateTime.now().toIso8601String().substring(11, 19);
}

// ==========================================
// 2. STATE MANAGEMENT (PROVIDER)
// ==========================================

class AppState extends ChangeNotifier {
  // --- SETTINGS ---
  bool _globalNSFW = false;
  bool _onlyGifs = false;
  
  // --- DATA ---
  List<ContentSource> _sources = [];
  final List<MediaItem> _feed = [];
  final List<MediaItem> _favorites = [];
  final Set<String> _seenIds = {}; // Anti-duplicate system
  final List<LogEntry> _logs = [];

  // --- GETTERS ---
  bool get isNSFWAllowed => _globalNSFW;
  bool get onlyGifs => _onlyGifs;
  List<ContentSource> get sources => _sources;
  List<MediaItem> get feed => _feed;
  List<MediaItem> get favorites => _favorites;
  List<LogEntry> get logs => List.from(_logs.reversed); // Newest first

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AppState() {
    _init();
  }

  void _init() async {
    log("SYS", "Initializing Lunya Hub 7.0...", color: Colors.cyan);
    await _loadSources();
    if (_sources.isEmpty) {
      _addDefaultSources();
    }
  }

  // --- LOGGING ---
  void log(String tag, String msg, {Color color = Colors.white}) {
    _logs.add(LogEntry(tag, msg, color: color));
    if (_logs.length > 500) _logs.removeAt(0);
    notifyListeners();
  }

  // --- SOURCE MANAGEMENT ---
  void _addDefaultSources() {
    log("CFG", "Adding default furry sources...");
    addSource(ContentSource(id: 'r_furry_irl', name: 'r/furry_irl', url: 'https://www.reddit.com/r/furry_irl', type: SourceType.reddit));
    addSource(ContentSource(id: 'r_furrymemes', name: 'r/furrymemes', url: 'https://www.reddit.com/r/furrymemes', type: SourceType.reddit));
    addSource(ContentSource(id: 'r_furryart', name: 'r/furryart', url: 'https://www.reddit.com/r/furryart', type: SourceType.reddit));
    saveSources();
  }

  void addSource(ContentSource source) {
    _sources.add(source);
    log("SRC", "Added source: ${source.name}", color: Colors.green);
    saveSources();
    notifyListeners();
  }

  void toggleSource(String id) {
    final s = _sources.firstWhere((e) => e.id == id);
    s.isActive = !s.isActive;
    log("SRC", "${s.name} is now ${s.isActive ? 'ACTIVE' : 'INACTIVE'}");
    saveSources();
    notifyListeners();
  }

  void removeSource(String id) {
    _sources.removeWhere((e) => e.id == id);
    saveSources();
    notifyListeners();
  }

  // --- FILTERS ---
  void toggleNSFW() {
    _globalNSFW = !_globalNSFW;
    log("FLT", "Global NSFW set to: $_globalNSFW", color: Colors.pinkAccent);
    // Clear feed to force refresh with new rules
    _feed.clear();
    _seenIds.clear(); 
    fetchContent();
    notifyListeners();
  }

  void toggleGifFilter() {
    _onlyGifs = !_onlyGifs;
    log("FLT", "GIF Only Mode: $_onlyGifs", color: Colors.purpleAccent);
    _feed.clear();
    _seenIds.clear();
    fetchContent();
    notifyListeners();
  }

  // --- CONTENT FETCHING ---
  Future<void> fetchContent() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    log("NET", "Starting batch fetch...", color: Colors.blue);
    
    int newItemsCount = 0;
    final activeSources = _sources.where((s) => s.isActive).toList();

    if (activeSources.isEmpty) {
      log("ERR", "No active sources selected!", color: Colors.red);
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Shuffle sources to mix content
    activeSources.shuffle();

    for (var source in activeSources) {
      if (newItemsCount >= 10) break; // Fetch limit per batch

      try {
        log("NET", "Scanning ${source.name}...");
        List<MediaItem> items = [];
        
        if (source.type == SourceType.reddit) {
          items = await _scrapeReddit(source);
        } else {
          // Placeholder for complex scraping (requires backend usually)
          log("WRN", "Browser parsing for ${source.name} not fully implemented in client-only mode", color: Colors.orange);
        }

        for (var item in items) {
          // 1. De-duplication
          if (_seenIds.contains(item.id)) continue;
          
          // 2. NSFW Filter
          if (item.isNSFW && !_globalNSFW) continue;

          // 3. GIF Filter
          if (_onlyGifs && item.type != ContentType.gif) continue;

          _feed.add(item);
          _seenIds.add(item.id);
          newItemsCount++;
        }
      } catch (e) {
        log("ERR", "Failed to scrape ${source.name}: $e", color: Colors.red);
      }
    }

    _feed.shuffle(); // Randomize feed
    log("NET", "Batch complete. Added $newItemsCount new items.", color: Colors.green);
    _isLoading = false;
    notifyListeners();
  }

  Future<List<MediaItem>> _scrapeReddit(ContentSource source) async {
    final url = '${source.url}/hot.json?limit=25';
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'LunyaHub/7.0'});
    
    if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
    
    final data = json.decode(response.body);
    final children = data['data']['children'] as List;
    List<MediaItem> results = [];

    for (var child in children) {
      final d = child['data'];
      final String u = d['url_overridden_by_dest'] ?? d['url'];
      final bool over18 = d['over_18'] ?? false;
      
      // Determine type
      ContentType type = ContentType.image;
      if (u.endsWith('.gif') || d['is_video'] == true) type = ContentType.gif;

      // Basic filtering for images/gifs
      if (!u.contains('.jpg') && !u.contains('.png') && !u.contains('.gif') && !u.contains('i.redd.it')) continue;

      results.add(MediaItem(
        id: d['id'], // Reddit ID used for deduplication
        url: u,
        previewUrl: d['thumbnail'] != 'self' ? d['thumbnail'] : u,
        title: d['title'],
        type: type,
        sourceName: source.name,
        isNSFW: over18 || source.isNSFW,
      ));
    }
    return results;
  }

  // --- FAVORITES ---
  void addToFavorites(MediaItem item) {
    if (!_favorites.any((i) => i.id == item.id)) {
      _favorites.add(item);
      log("USR", "Saved to gallery: ${item.title}", color: Colors.yellow);
      notifyListeners();
    }
  }

  void removeFromFavorites(String id) {
    _favorites.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  // --- PERSISTENCE (Basic implementation) ---
  Future<void> saveSources() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_sources.map((e) => e.toJson()).toList());
    await prefs.setString('sources', encoded);
  }

  Future<void> _loadSources() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('sources')) {
      final String? encoded = prefs.getString('sources');
      if (encoded != null) {
        final List objects = json.decode(encoded);
        _sources = objects.map((e) => ContentSource.fromJson(e)).toList();
        notifyListeners();
      }
    }
  }
}

// ==========================================
// 3. UI COMPONENTS
// ==========================================

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: const LunyaApp(),
    ),
  );
}

class LunyaApp extends StatelessWidget {
  const LunyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lunya Hub 7.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
          primary: const Color(0xFFD0BCFF),
          secondary: const Color(0xFFCCC2DC),
        ),
        scaffoldBackgroundColor: const Color(0xFF141218),
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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final List<Widget> pages = [
      const FeedPage(),
      const SourcesPage(),
      const FavoritesPage(),
      const LogsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(FontAwesomeIcons.paw, size: 20),
            const SizedBox(width: 10),
            const Text("Lunya Hub"),
            const Spacer(),
            // NSFW Toggle
            IconButton(
              icon: Icon(
                state.isNSFWAllowed ? Icons.visibility : Icons.visibility_off,
                color: state.isNSFWAllowed ? Colors.redAccent : Colors.grey,
              ),
              onPressed: () => context.read<AppState>().toggleNSFW(),
              tooltip: "Toggle NSFW",
            ),
            // GIF Toggle
            IconButton(
              icon: Icon(
                Icons.gif_box,
                color: state.onlyGifs ? Colors.greenAccent : Colors.grey,
              ),
              onPressed: () => context.read<AppState>().toggleGifFilter(),
              tooltip: "GIFs Only",
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.black26,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.source),
            label: 'Sources',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}

// --- FEED PAGE ---
class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AppState>().feed.isEmpty) {
        context.read<AppState>().fetchContent();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      context.read<AppState>().fetchContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.feed.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.feed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FontAwesomeIcons.cat, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No content found. Check filters or sources."),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<AppState>().fetchContent(),
              child: const Text("Refresh"),
            )
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Here you might want to clear list and refetch
        await context.read<AppState>().fetchContent();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.feed.length + (state.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.feed.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = state.feed[index];
          
          // Swipe Logic
          return Dismissible(
            key: Key(item.id),
            direction: DismissDirection.horizontal,
            background: Container(
              color: Colors.green,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.favorite, color: Colors.white, size: 32),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white, size: 32),
            ),
            onDismissed: (direction) {
              if (direction == DismissDirection.startToEnd) {
                // Save (Right Swipe)
                context.read<AppState>().addToFavorites(item);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Saved to Gallery!"), duration: Duration(seconds: 1)),
                );
              }
              // Item is visually removed, but we might want to keep it in memory
              // Ideally, you'd implement a "hidden" list. 
              // For now, Dismissible removes it from the widget tree only.
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.url, // Using full URL for quality. Optimized: use previewUrl
                        fit: BoxFit.cover,
                        height: 300,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          height: 300,
                          color: Colors.grey[900],
                          child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 300,
                          color: Colors.grey[900],
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                      if (item.type == ContentType.gif)
                        Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: const Text("GIF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      if (item.isNSFW)
                        Container(
                          margin: const EdgeInsets.all(8),
                          alignment: Alignment.topLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
                          child: const Text("NSFW", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(FontAwesomeIcons.reddit, size: 14, color: Colors.orange[400]),
                            const SizedBox(width: 4),
                            Text(item.sourceName, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.favorite_border),
                              onPressed: () => context.read<AppState>().addToFavorites(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- SOURCES PAGE ---
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final TextEditingController urlController = TextEditingController();

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Add Source"),
              content: TextField(
                controller: urlController,
                decoration: const InputDecoration(hintText: "Enter Subreddit (e.g., r/furry) or URL"),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                TextButton(
                  onPressed: () {
                    final text = urlController.text;
                    if (text.isNotEmpty) {
                      // Simple parser logic for demo
                      String name = text;
                      String url = text;
                      SourceType type = SourceType.custom;

                      if (text.startsWith("r/") || text.contains("reddit.com")) {
                        type = SourceType.reddit;
                        if (!text.startsWith("http")) {
                           url = "https://www.reddit.com/$text";
                        }
                        name = text.replaceAll("https://www.reddit.com/", "");
                      }

                      context.read<AppState>().addSource(ContentSource(
                        id: DateTime.now().millisecondsSinceEpoch.toString(), 
                        name: name, 
                        url: url, 
                        type: type
                      ));
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text("Add"),
                ),
              ],
            ),
          );
        },
      ),
      body: ListView.builder(
        itemCount: state.sources.length,
        itemBuilder: (context, index) {
          final source = state.sources[index];
          return ListTile(
            leading: Checkbox(
              value: source.isActive,
              onChanged: (_) => context.read<AppState>().toggleSource(source.id),
            ),
            title: Text(source.name),
            subtitle: Text(source.url, style: const TextStyle(fontSize: 10)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => context.read<AppState>().removeSource(source.id),
            ),
          );
        },
      ),
    );
  }
}

// --- LOGS PAGE ---
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Container(
      color: Colors.black,
      child: ListView.builder(
        reverse: true, // Keep scroll at bottom ideally, but list is reversed in getter
        itemCount: state.logs.length,
        itemBuilder: (context, index) {
          final log = state.logs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
                children: [
                  TextSpan(text: "[${log.time}] ", style: const TextStyle(color: Colors.grey)),
                  TextSpan(text: "[${log.tag}] ", style: TextStyle(color: log.color, fontWeight: FontWeight.bold)),
                  TextSpan(text: log.message, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- FAVORITES PAGE ---
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: state.favorites.length,
      itemBuilder: (context, index) {
        final item = state.favorites[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.cover,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.white))),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                        onPressed: () => context.read<AppState>().removeFromFavorites(item.id),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
