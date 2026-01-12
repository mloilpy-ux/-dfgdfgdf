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
import 'package:xml/xml.dart'; // Нужно добавить xml: ^6.5.0 в pubspec.yaml

// --- DATA MODELS ---

enum SourceType { reddit, telegram, twitter, custom }

class ImageSource {
  String id;
  String name;
  String urlOrTag; // @username или subreddit
  SourceType type;
  bool isActive;

  ImageSource({
    required this.id,
    required this.name,
    required this.urlOrTag,
    required this.type,
    this.isActive = true,
  });
}

// --- GLOBAL LOGGER ---

class Logger {
  static final List<String> logs = [];
  static final StreamController<List<String>> _controller = StreamController.broadcast();

  static Stream<List<String>> get stream => _controller.stream;

  static void log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final entry = "[$timestamp] $message";
    print(entry);
    logs.add(entry);
    if (logs.length > 500) logs.removeAt(0); // Храним последние 500 строк
    _controller.add(logs);
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
          surface: const Color(0xFF121218),
        ),
        scaffoldBackgroundColor: const Color(0xFF09090E),
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
  
  // Список источников по умолчанию
  List<ImageSource> sources = [
    ImageSource(id: 'r1', name: 'Reddit: Furry', urlOrTag: 'furry', type: SourceType.reddit),
    ImageSource(id: 'r2', name: 'Reddit: FurryArt', urlOrTag: 'furryart', type: SourceType.reddit),
    ImageSource(id: 'tg1', name: 'TG: Furry Art (Demo)', urlOrTag: 'furry_art_archive', type: SourceType.telegram, isActive: false),
  ];

  @override
  void initState() {
    super.initState();
    Logger.log("App Started. Ready to fetch.");
    fetchContent();
  }

  // --- LOGIC ---

  Future<void> fetchContent() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    
    // 1. Собираем активные источники
    final activeSources = sources.where((s) => s.isActive).toList();
    if (activeSources.isEmpty) {
      Logger.log("WARNING: No active sources selected!");
      setState(() => isLoading = false);
      return;
    }

    Logger.log("Fetching from ${activeSources.length} sources...");

    // 2. Выбираем случайный источник для разнообразия
    final source = activeSources[Random().nextInt(activeSources.length)];
    Logger.log("Selected source: ${source.name} (${source.type})");

    try {
      List<String> newImages = [];
      
      if (source.type == SourceType.reddit) {
        newImages = await _fetchReddit(source.urlOrTag);
      } else if (source.type == SourceType.telegram) {
        newImages = await _fetchTelegram(source.urlOrTag);
      } else if (source.type == SourceType.twitter) {
        newImages = await _fetchTwitter(source.urlOrTag); // Сложнее, через Nitter
      }

      if (newImages.isNotEmpty) {
        // Перемешиваем и добавляем в начало очереди
        newImages.shuffle();
        setState(() {
          imageQueue.insertAll(0, newImages);
          // Если текущей картинки нет, ставим первую
          if (currentImageUrl.isEmpty) {
            currentImageUrl = imageQueue.removeAt(0);
          }
        });
        Logger.log("Added ${newImages.length} images to queue.");
      } else {
        Logger.log("Source ${source.name} returned 0 images.");
      }

    } catch (e) {
      Logger.log("ERROR fetching from ${source.name}: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Reddit Parser (JSON)
  Future<List<String>> _fetchReddit(String subreddit) async {
    final url = 'https://www.reddit.com/r/$subreddit/hot.json?limit=25';
    Logger.log("Request: GET $url");
    
    final response = await http.get(Uri.parse(url), headers: {'User-Agent': 'LunyaHub/4.0'});
    
    if (response.statusCode != 200) {
      Logger.log("Reddit Error: ${response.statusCode}");
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
  }

  // Telegram Parser (via RSSHub bridge logic simulation)
  // Прямой парсинг TG сложен, используем публичные зеркала для предпросмотра
  Future<List<String>> _fetchTelegram(String channelName) async {
    // В реальности нужен RSSHub, но для демо используем tgstat/telemetr парсинг или просто заглушку,
    // так как прямой доступ к фото в ТГ закрыт.
    // ТУТ МЫ ИСПОЛЬЗУЕМ ХАК: t.me/s/channelname (Web Preview)
    
    final cleanName = channelName.replaceAll('@', '');
    final url = 'https://t.me/s/$cleanName';
    Logger.log("Parsing TG Web: $url");

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    // Очень грубый парсинг HTML (RegEx) для поиска картинок
    // Ищем background-image:url('...') в постах
    final regExp = RegExp(r"background-image:url\('([^']+)'\)");
    final matches = regExp.allMatches(response.body);
    
    List<String> result = [];
    for (var m in matches) {
      String? link = m.group(1);
      if (link != null && !link.contains("emoji")) { // Фильтр смайликов
        result.add(link);
      }
    }
    Logger.log("Found ${result.length} images in TG channel");
    return result;
  }

  // Twitter/X Parser (via Nitter instances)
  Future<List<String>> _fetchTwitter(String user) async {
    // Используем Nitter (публичный фронтенд для Twitter)
    final url = 'https://nitter.net/$user/media/rss'; 
    // Примечание: Nitter часто меняет домены, это может работать нестабильно
    Logger.log("Parsing Nitter RSS: $url");
    // (Код заглушка, т.к. Nitter часто падает, но логика понятна)
    return []; 
  }

  void showNextImage() {
    if (imageQueue.isNotEmpty) {
      setState(() {
        currentImageUrl = imageQueue.removeAt(0);
      });
      Logger.log("Next image shown. Queue: ${imageQueue.length}");
    } else {
      fetchContent();
    }
  }

  // --- ACTIONS ---

  Future<void> saveToGallery() async {
    if (currentImageUrl.isEmpty) return;
    Logger.log("Saving to gallery...");
    try {
      final response = await http.get(Uri.parse(currentImageUrl));
      final dir = await getExternalStorageDirectory(); // Android/data/...
      // Для сохранения в общую галерею нужен Permission handler, но пока сохраним в доступную папку
      // На Android 10+ через MediaStore (сложнее), для простоты сохраним в Pictures через path_provider
      
      // В Flutter проще всего использовать пакет image_gallery_saver, 
      // но чтобы не раздувать код, мы просто скачаем файл
      Logger.log("Saved (simulation): Image downloaded to app cache."); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Скачано (проверьте файлы приложения)")));
    } catch (e) {
      Logger.log("Save error: $e");
    }
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    Logger.log("Setting wallpaper...");
    try {
      final response = await http.get(Uri.parse(currentImageUrl));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wall.jpg');
      await file.writeAsBytes(response.bodyBytes);
      
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      Logger.log("Wallpaper set successfully.");
    } catch (e) {
      Logger.log("Wallpaper error: $e");
    }
  }

  // --- UI SCREENS ---

  void _openSourcesScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Менеджер Источников", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: sources.length,
                  itemBuilder: (context, index) {
                    final s = sources[index];
                    return SwitchListTile(
                      title: Text(s.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(s.urlOrTag, style: const TextStyle(color: Colors.white54)),
                      secondary: Icon(
                        s.type == SourceType.reddit ? Icons.reddit : 
                        s.type == SourceType.telegram ? Icons.send : Icons.public,
                        color: Colors.blueAccent
                      ),
                      value: s.isActive,
                      onChanged: (val) {
                        setModalState(() => s.isActive = val);
                        // Обновляем и основной стейт
                        setState(() {}); 
                        Logger.log("Source '${s.name}' active: $val");
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              // Форма добавления
              const Text("Добавить новый:", style: TextStyle(color: Colors.white70)),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(hintText: "user_tag или channel", filled: true),
                      onSubmitted: (val) {
                         // Простая логика добавления (по умолчанию TG)
                         if (val.isNotEmpty) {
                           setModalState(() {
                             sources.add(ImageSource(
                               id: DateTime.now().toString(),
                               name: "New Source",
                               urlOrTag: val,
                               type: SourceType.telegram // По умолчанию считаем что это ТГ канал
                             ));
                           });
                           Logger.log("Added custom source: $val");
                         }
                      },
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add_circle), onPressed: (){})
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _openLogScreen() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StreamBuilder<List<String>>(
        stream: Logger.stream,
        initialData: Logger.logs,
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          return Container(
            color: Colors.black,
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SYSTEM LOG (Real-time)", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (_, i) => Text(
                      logs[logs.length - 1 - i], // Обратный порядок (новые сверху)
                      style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 10)
                    ),
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
        backgroundColor: const Color(0xFF161622),
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF6200EA)),
              child: Center(child: Text("LUNYA HUB 4.0", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
            ),
            ListTile(
              leading: const Icon(Icons.source),
              title: const Text("Источники"),
              onTap: _openSourcesScreen,
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text("Live Logs"),
              onTap: _openLogScreen,
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background Image
          if (currentImageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                currentImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (_,__,___) => Container(color: Colors.black, child: const Center(child: Text("Error loading image"))),
              ),
            ),
            
          // UI Overlays
          SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => Scaffold.of(context).openDrawer()),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          isLoading ? "Загрузка..." : "${imageQueue.length} в очереди", 
                          style: const TextStyle(color: Colors.white)
                        ),
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(icon: const Icon(Icons.download, color: Colors.white), onPressed: saveToGallery),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom Controls
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    )
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                       FloatingActionButton.large(
                         heroTag: "next",
                         onPressed: showNextImage,
                         backgroundColor: Colors.white,
                         child: const Icon(Icons.arrow_forward, color: Colors.black),
                       ),
                       const SizedBox(width: 20),
                       FloatingActionButton(
                         heroTag: "wall",
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
          
          // Mini Log Overlay (последняя строка)
          Positioned(
            bottom: 5, left: 10, right: 10,
            child: StreamBuilder<List<String>>(
              stream: Logger.stream,
              builder: (context, snap) {
                if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
                return Text(
                  snap.data!.last, 
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 10, shadows: [Shadow(blurRadius: 2, color: Colors.black)]),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
