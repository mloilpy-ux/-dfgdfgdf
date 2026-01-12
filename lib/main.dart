import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  // Настройка системной панели (прозрачный статус-бар)
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
      title: 'Lunya Feed',
      themeMode: ThemeMode.dark,
      // Темная тема в стиле Material 3
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EA), // Deep Purple
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
          secondary: const Color(0xFF03DAC6),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A12),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
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
  String currentImageUrl = "";
  bool isLoading = false;
  List<String> imageQueue = [];
  String redditAfterToken = "";
  String debugLog = "System initialized...";

  // --- ЛОГИКА (Та же, что и раньше) ---
  void addToLog(String message) {
    print(message);
    setState(() {
      debugLog += "\n> $message";
    });
  }

  Future<void> fetchBatchFromReddit() async {
    addToLog("Fetching furry mix...");
    try {
      final sources = "furry+furry_irl+furrymemes+furryart";
      final url = 'https://www.reddit.com/r/$sources/hot.json?limit=30&after=$redditAfterToken';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter:LunyaApp:v2.0 (Material)'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        redditAfterToken = data['data']['after'] ?? "";
        final posts = data['data']['children'] as List;
        
        int count = 0;
        for (var post in posts) {
          final u = post['data']['url'] as String;
          if (u.contains('i.redd.it') && 
             (u.endsWith('.jpg') || u.endsWith('.png') || u.endsWith('.jpeg'))) {
            if (!imageQueue.contains(u) && u != currentImageUrl) {
               imageQueue.add(u);
               count++;
            }
          }
        }
        addToLog("Loaded +$count arts.");
      }
    } catch (e) {
      addToLog("Err: $e");
    }
  }

  Future<void> showNextImage() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    if (imageQueue.isEmpty) await fetchBatchFromReddit();

    if (imageQueue.isNotEmpty) {
      final next = imageQueue.removeAt(0);
      setState(() {
        currentImageUrl = next;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      if (mounted) _showSnack("Пусто... Попробуй еще раз!", isError: true);
    }
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    addToLog("Setting wallpaper...");
    try {
      var file = await _downloadFile(currentImageUrl);
      if (file != null) {
        await AsyncWallpaper.setWallpaperFromFile(
          filePath: file.path,
          wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
          goToHome: true,
        );
        _showSnack("Обои установлены! UwU");
      }
    } catch (e) {
      _showSnack("Ошибка: $e", isError: true);
    }
  }

  Future<File?> _downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/wall_temp.jpg');
        return await file.writeAsBytes(response.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  void _showSnack(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // --- UI (МАТЕРИАЛ ДИЗАЙН 3) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // Картинка заезжает под статус-бар
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            const Text("Lunya Feed", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal),
            onPressed: () => _showLogModal(context),
            tooltip: 'Debug Log',
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Фон (размытая копия текущей картинки для атмосферы)
          if (currentImageUrl.isNotEmpty)
            Image.network(
              currentImageUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.8),
              colorBlendMode: BlendMode.darken,
            ),
          
          SafeArea(
            child: Column(
              children: [
                // Основная карточка с картинкой
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        width: double.infinity,
                        color: Colors.black26,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: currentImageUrl.isNotEmpty
                            ? Image.network(
                                currentImageUrl,
                                key: ValueKey(currentImageUrl), // Для анимации смены
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (_, child, p) => p == null ? child : 
                                  const Center(child: CircularProgressIndicator()),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white24),
                                  SizedBox(height: 16),
                                  Text("Жми кнопку внизу!", style: TextStyle(color: Colors.white54))
                                ],
                              ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Панель управления
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      // Кнопка NEXT (Большая)
                      Expanded(
                        child: SizedBox(
                          height: 64,
                          child: FilledButton.tonal(
                            onPressed: isLoading ? null : showNextImage,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            child: isLoading 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.pets), // Иконка лапки
                                    SizedBox(width: 12),
                                    Text("NEXT ART", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),

                      // Кнопка WALLPAPER (Круглая/Квадратная)
                      if (currentImageUrl.isNotEmpty)
                        SizedBox(
                          height: 64,
                          width: 64,
                          child: FilledButton(
                            onPressed: setWallpaper,
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.wallpaper, size: 28),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(verticalTop: Radius.circular(20)),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("DEBUG CONSOLE", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.greenAccent)),
            const Divider(color: Colors.white24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(debugLog, style: const TextStyle(fontFamily: 'monospace', color: Colors.white70)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
