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
import 'package:xml/xml.dart'; 

// --- 1. MODELS ---

enum SourceType { reddit, telegram, twitter, custom }

class ImageSource {
  String id;
  String name;      
  String identifier; 
  SourceType type;
  bool isActive;

  ImageSource({
    required this.id,
    required this.name,
    required this.identifier,
    required this.type,
    this.isActive = true,
  });
}

// --- 2. LOGGER ---

class AppLogger {
  static final List<String> logs = [];
  static final StreamController<List<String>> _controller = StreamController.broadcast();

  static Stream<List<String>> get stream => _controller.stream;

  static void log(String message) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    final entry = "[$timeStr] $message";
    
    print(entry);
    logs.add(entry);
    if (logs.length > 300) logs.removeAt(0); 
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
      title: 'Lunya Hub 4.0',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EA), 
          brightness: Brightness.dark,
          surface: const Color(0xFF101014),
        ),
        scaffoldBackgroundColor: const Color(0xFF050508),
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
  // --- STATE ---
  String currentImageUrl = "";
  bool isLoading = false;
  List<String> imageQueue = [];
  
  List<ImageSource> sources = [
    ImageSource(id: 'r1', name: 'Reddit: r/Furry', identifier: 'furry', type: SourceType.reddit),
    ImageSource(id: 'r2', name: 'Reddit: r/FurryArt', identifier: 'furryart', type: SourceType.reddit),
    ImageSource(id: 'tg1', name: 'TG: Furry Art Archive', identifier: 'furry_art_archive', type: SourceType.telegram),
    ImageSource(id: 'tg2', name: 'TG: Random Furry', identifier: 'random_furry_art', type: SourceType.telegram, isActive: false),
  ];

  @override
  void initState() {
    super.initState();
    AppLogger.log("SYSTEM: App initialized.");
    fetchContent();
  }

  // --- LOGIC ---

  Future<void> fetchContent() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    
    final activeSources = sources.where((s) => s.isActive).toList();
    
    if (activeSources.isEmpty) {
      AppLogger.log("WARNING: No active sources selected!");
      setState(() => isLoading = false);
      _showSnack("Select sources in menu!", isError: true);
      return;
    }

    AppLogger.log("Fetching from ${activeSources.length} sources...");
    final source = activeSources[Random().nextInt(activeSources.length)];
    AppLogger.log("Selected Source: [${source.type.name.toUpperCase()}] ${source.name}");

    try {
      List<String> newImages = [];
      
      switch (source.type) {
        case SourceType.reddit:
          newImages = await _fetchReddit(source.identifier);
          break;
        case SourceType.telegram:
          newImages = await _fetchTelegramWeb(source.identifier);
          break;
        case SourceType.twitter:
          AppLogger.log("Twitter parsing skipped (API restriction).");
          break;
        default:
          break;
      }

      if (newImages.isNotEmpty) {
        newImages.shuffle(); 
        setState(() {
          imageQueue.addAll(newImages);
          imageQueue = imageQueue.toSet().toList(); // Remove dupes
          
          if (currentImageUrl.isEmpty && imageQueue.isNotEmpty) {
            currentImageUrl = imageQueue.removeAt(0);
          }
        });
        AppLogger.log("Success: Added ${newImages.length} images.");
      } else {
        AppLogger.log("Source returned 0 images.");
        if (activeSources.length > 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

    } catch (e) {
      AppLogger.log("CRITICAL ERROR: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<List<String>> _fetchReddit(String subreddit) async {
    final url = 'https://www.reddit.com/r/$subreddit/hot.json?limit=25';
    AppLogger.log("NET: GET $url");
    
    try {
      final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'LunyaHub/4.0'});
      if (response.statusCode != 200) {
        AppLogger.log("Reddit HTTP Error: ${response.statusCode}");
        return [];
      }

      final data = json.decode(response.body);
      final posts = data['data']['children'] as List;
      List<String> result = [];

      for (var post in posts) {
        final u = post['data']['url'] as String;
        if (u.contains('i.redd.it') && (u.endsWith('.jpg') || u.endsWith('.png'))) {
          result.add(u);
        }
      }
      return result;
    } catch (e) {
      AppLogger.log("Reddit Parse Error: $e");
      return [];
    }
  }

  Future<List<String>> _fetchTelegramWeb(String channel) async {
    final cleanId = channel.replaceAll('@', '').trim();
    final url = 'https://t.me/s/$cleanId';
    AppLogger.log("NET: Scraping TG Web $url");

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];

      final regExp = RegExp(r"background-image:url\('([^']+)'\)");
      final matches = regExp.allMatches(response.body);
      
      List<String> result = [];
      for (var m in matches) {
        String? link = m.group(1);
        if (link != null && !link.contains("emoji") && !link.contains("svg")) {
             result.add(link);
        }
      }
      AppLogger.log("TG Parser found ${result.length} images.");
      return result;
    } catch (e) {
      AppLogger.log("TG Parse Error: $e");
      return [];
    }
  }

  void showNextImage() {
    if (imageQueue.isNotEmpty) {
      setState(() {
        currentImageUrl = imageQueue.removeAt(0);
      });
      AppLogger.log("UI: Next image loaded. Queue: ${imageQueue.length}");
    } else {
      AppLogger.log("UI: Queue empty. Fetching more...");
      fetchContent();
    }
  }

  Future<void> saveToGallery() async {
    if (currentImageUrl.isEmpty) return;
    AppLogger.log("ACTION: Saving to gallery...");
    try {
      final response = await http.get(Uri.parse(currentImageUrl));
      if (response.statusCode == 200) {
        final dir = await getExternalStorageDirectory(); 
        // Если getExternalStorageDirectory null (на iOS), используем документы
        final saveDir = dir ?? await getApplicationDocumentsDirectory();
        
        final fileName = "lunya_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        AppLogger.log("FILE: Saved to ${file.path}");
        _showSnack("Файл сохранен: ${file.path}");
      }
    } catch (e) {
      AppLogger.log("Save Error: $e");
    }
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    AppLogger.log("ACTION: Setting wallpaper...");
    try {
      final response = await http.get(Uri.parse(currentImageUrl));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wall_temp.jpg');
      await file.writeAsBytes(response.bodyBytes);
      
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      AppLogger.log("SYSTEM: Wallpaper updated!");
      _showSnack("Обои установлены успешно!");
    } catch (e) {
      AppLogger.log("Wallpaper Error: $e");
      _showSnack("Ошибка установки: $e", isError: true);
    }
  }

  void _showSnack(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? Colors.redAccent : Colors.teal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // --- UI SCREENS ---

  void _openSourcesManager() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF18181F),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Sources", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              const SizedBox(height: 10),
              
              Expanded(
                child: ListView.builder(
                  itemCount: sources.length,
                  itemBuilder: (context, index) {
                    final s = sources[index];
                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        activeColor: Colors.deepPurpleAccent,
                        title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          s.type == SourceType.reddit ? "r/${s.identifier}" : 
                          s.type == SourceType.telegram ? "t.me/${s.identifier}" : "@${s.identifier}",
                          style: const TextStyle(color: Colors.white54)
                        ),
                        secondary: Icon(
                          s.type == SourceType.reddit ? Icons.reddit : 
                          s.type == SourceType.telegram ? Icons.send : Icons.link,
                          color: s.isActive ? Colors.white : Colors.white30,
                        ),
                        value: s.isActive,
                        onChanged: (val) {
                          setModalState(() => s.isActive = val ?? false);
                          setState(() {}); 
                          AppLogger.log("Config: '${s.name}' active=${s.isActive}");
                        },
                      ),
                    );
                  },
                ),
              ),
              
              const Divider(),
              const Text("Add new Source:", style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "e.g. furry_irl",
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10)
                      ),
                      onSubmitted: (val) => _addNewSource(val, setModalState),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed: () {}, 
                  )
                ],
              ),
              const Text("Enter ID (no @ or r/) and press Enter", style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewSource(String val, StateSetter setModalState) {
    if (val.isEmpty) return;
    
    final newSource = ImageSource(
      id: DateTime.now().toString(),
      name: "Custom: $val",
      identifier: val,
      type: SourceType.telegram 
    );
    
    setModalState(() {
      sources.add(newSource);
    });
    setState(() {}); 
    AppLogger.log("Config: Added new source $val");
    _showSnack("Source $val added!");
  }

  void _openLogViewer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      builder: (_) => StreamBuilder<List<String>>(
        stream: AppLogger.stream,
        initialData: AppLogger.logs,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("LIVE LOGS", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    Text("${logs.length} events", style: const TextStyle(color: Colors.white38))
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView.builder(
                    reverse: true, 
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final log = logs[logs.length - 1 - i]; 
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(log, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 11)),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF121216),
        child: Column(
          children: [
             UserAccountsDrawerHeader(
               accountName: const Text("Lunya Hub 4.0"),
               accountEmail: const Text("Content Aggregator"),
               currentAccountPicture: const CircleAvatar(
                 backgroundColor: Colors.white,
                 child: Icon(Icons.pets, color: Colors.black),
               ),
               decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
             ),
             ListTile(
               leading: const Icon(Icons.dashboard_customize),
               title: const Text("Source Manager"),
               onTap: () {
                 Navigator.pop(context);
                 _openSourcesManager();
               },
             ),
             ListTile(
               leading: const Icon(Icons.terminal),
               title: const Text("System Log"),
               onTap: () {
                 Navigator.pop(context);
                 _openLogViewer();
               },
             ),
             const Spacer(),
             const ListTile(
               leading: Icon(Icons.info_outline),
               title: Text("v4.0.1 (Stable)"),
             )
          ],
        ),
      ),
      
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: showNextImage, 
              child: Container(
                color: Colors.black, 
                child: currentImageUrl.isNotEmpty
                  ? Image.network(
                      currentImageUrl,
                      fit: BoxFit.contain, 
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (c,e,s) => const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            Text("Image load error", style: TextStyle(color: Colors.grey))
                          ],
                        )
                      ),
                    )
                  : const Center(child: Text("Loading content...", style: TextStyle(color: Colors.white54))),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12)
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.rss_feed, size: 14, color: Colors.greenAccent),
                            const SizedBox(width: 6),
                            Text("${imageQueue.length} items", style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: const Icon(Icons.save_alt, color: Colors.white),
                          onPressed: saveToGallery,
                          tooltip: "Save to Gallery",
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter
                    )
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FloatingActionButton.extended(
                          heroTag: "nextBtn",
                          onPressed: showNextImage,
                          label: const Text("NEXT"),
                          icon: const Icon(Icons.arrow_forward),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        heroTag: "wallBtn",
                        onPressed: setWallpaper,
                        backgroundColor: Colors.deepPurpleAccent,
                        child: const Icon(Icons.wallpaper),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
          
          Positioned(
            bottom: 5, left: 20, right: 20,
            child: IgnorePointer(
              child: StreamBuilder<List<String>>(
                stream: AppLogger.stream,
                builder: (context, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                  return Text(
                    snap.data!.last,
                    style: TextStyle(
                      color: Colors.greenAccent.withOpacity(0.8), 
                      fontSize: 10, 
                      fontFamily: 'monospace',
                      shadows: const [Shadow(offset: Offset(1,1), blurRadius: 2, color: Colors.black)]
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
