import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
      title: 'Lunya Hub',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6200EA),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E2C),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
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
  
  bool allowNSFW = false; 
  List<String> customUrls = []; 
  String debugLog = "System initialized...";

  @override
  void initState() {
    super.initState();
    fetchBatchFromReddit();
  }

  void addToLog(String message) {
    debugPrint(message); 
    if (mounted) {
      setState(() {
        debugLog += "\n> $message";
      });
    }
  }

  void toggleNSFW(bool value) {
    setState(() {
      allowNSFW = value;
      imageQueue.clear();
      redditAfterToken = "";
      currentImageUrl = ""; 
    });
    fetchBatchFromReddit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? "NSFW режим: ВКЛЮЧЕН" : "NSFW режим: ВЫКЛЮЧЕН"))
    );
  }

  Future<void> fetchBatchFromReddit() async {
    addToLog("Fetching content (NSFW: $allowNSFW)...");
    try {
      String sources = "furry+furryart"; 
      if (allowNSFW) {
        sources += "+furry_irl+furrymemes+yiff"; 
      }

      final url = 'https://www.reddit.com/r/$sources/hot.json?limit=40&after=$redditAfterToken';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter:LunyaApp:v3.0'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        redditAfterToken = data['data']['after'] ?? "";
        final posts = data['data']['children'] as List;
        
        int count = 0;
        for (var post in posts) {
          final postData = post['data'];
          final u = postData['url'] as String;
          final bool isOver18 = postData['over_18'] ?? false;

          if (!allowNSFW && isOver18) continue; 

          if (u.contains('i.redd.it') && 
             (u.endsWith('.jpg') || u.endsWith('.png') || u.endsWith('.jpeg'))) {
            if (!imageQueue.contains(u)) {
               imageQueue.add(u);
               count++;
            }
          }
        }
        
        if (customUrls.isNotEmpty) {
           imageQueue.insertAll(0, customUrls); 
        }

        addToLog("Loaded +$count suitable images.");
        
        if (currentImageUrl.isEmpty && imageQueue.isNotEmpty) {
          showNextImage();
        }

      }
    } catch (e) {
      addToLog("Err: $e");
    }
  }

  Future<void> showNextImage() async {
    if (imageQueue.isEmpty) {
      setState(() => isLoading = true);
      await fetchBatchFromReddit();
      setState(() => isLoading = false);
    }

    if (imageQueue.isNotEmpty) {
      // Логика перемешивания
      if (imageQueue.length > 5 && customUrls.isEmpty) {
        int index = Random().nextInt(3); 
        final next = imageQueue.removeAt(index);
        setState(() => currentImageUrl = next);
      } else {
         final next = imageQueue.removeAt(0);
         setState(() => currentImageUrl = next);
      }
    }
  }

  // --- ЛОГИКА ОБРАБОТКИ ССЫЛОК (TG/TWITTER) ---
  
  // Эта функция пытается превратить ссылку на пост в ссылку на картинку
  String _processLink(String input) {
    String clean = input.trim();
    
    // 1. Twitter / X Fix
    // x.com/user/status/123 -> d.fxtwitter.com/... (иногда работает как прямой линк на медиа)
    if (clean.contains("twitter.com") || clean.contains("x.com")) {
      // Пока что просто возвращаем как есть, так как без API ключа сложно вытащить картинку.
      // Но можно попробовать использовать сервисы-прокси, если они доступны.
      // Для надежности просим пользователя вставлять прямые ссылки (pbs.twimg.com)
      return clean;
    }

    // 2. Telegram Web
    // https://t.me/channelname/123 -> https://t.me/channelname/123?embed=1&mode=tme
    // Телеграм не отдает картинки по прямой ссылке просто так. 
    // Лучший способ - это user agent trick, но в рамках простого URL это сложно.
    
    return clean;
  }

  void _showAddCustomLinkDialog() {
    final TextEditingController urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить источник"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Вставьте ссылку на картинку (.jpg/.png).\n"
              "Для Twitter/X: Нажмите на картинку -> ПКМ -> Копировать адрес изображения.\n"
              "Для Telegram: Откройте в браузере, ПКМ по фото -> Копировать ссылку.",
              style: TextStyle(fontSize: 12, color: Colors.white60)
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: "https://...",
                border: OutlineInputBorder(),
                filled: true,
                labelText: "URL Картинки"
              ),
            ),
            const SizedBox(height: 15),
            const Text("Быстрый поиск:", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Кнопки открывают браузер для поиска контента
                IconButton.filledTonal(
                  icon: const Icon(Icons.close), // X logo replacement
                  onPressed: () => _launchExternal("https://x.com/search?q=furry%20art&src=typed_query&f=media"),
                  tooltip: "Search X (Twitter)",
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.send),
                  onPressed: () => _launchExternal("https://web.telegram.org"), 
                  tooltip: "Telegram Web",
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.image_search),
                  onPressed: () => _launchExternal("https://www.furaffinity.net"), 
                  tooltip: "FurAffinity",
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            onPressed: () {
              if (urlController.text.isNotEmpty) {
                final processed = _processLink(urlController.text);
                setState(() {
                  customUrls.add(processed);
                  imageQueue.insert(0, processed); 
                  currentImageUrl = processed; 
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Добавлено в очередь!")));
              }
            },
            child: const Text("Добавить"),
          )
        ],
      ),
    );
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    try {
      // Качаем байты
      final response = await http.get(Uri.parse(currentImageUrl));
      
      if (response.statusCode != 200) {
        throw Exception("Server Error: ${response.statusCode}");
      }
      
      final dir = await getTemporaryDirectory();
      // Определяем расширение
      String ext = ".jpg";
      if (currentImageUrl.endsWith(".png")) ext = ".png";
      
      final file = File('${dir.path}/wall_temp$ext');
      await file.writeAsBytes(response.bodyBytes);
      
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Обои установлены!")));
      }
    } catch (e) {
      addToLog("Wall Err: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка загрузки: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        backgroundColor: const Color(0xFF161622),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text("Lunya User"),
              accountEmail: Text(allowNSFW ? "Mode: Uncensored" : "Mode: Safe"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: allowNSFW ? Colors.redAccent : Colors.teal,
                child: Icon(allowNSFW ? Icons.warning : Icons.shield, color: Colors.white),
              ),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            ),
            SwitchListTile(
              title: const Text("NSFW Контент"),
              subtitle: const Text("Разрешить 18+ арты"),
              secondary: const Icon(Icons.explicit, color: Colors.red),
              value: allowNSFW,
              onChanged: toggleNSFW,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add_link),
              title: const Text("Добавить источник"),
              subtitle: const Text("Twitter / TG / FA"),
              onTap: () {
                Navigator.pop(context);
                _showAddCustomLinkDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.terminal),
              title: const Text("Логи"),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(context: context, builder: (c) => Container(
                   padding: const EdgeInsets.all(20),
                   color: Colors.black,
                   child: Text(debugLog, style: const TextStyle(color: Colors.green, fontFamily: 'monospace')),
                ));
              },
            ),
          ],
        ),
      ),
      
      body: Stack(
        children: [
          if (currentImageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                currentImageUrl, 
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.9),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (c, e, s) => Container(color: Colors.black),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Builder(builder: (context) => IconButton(
                        icon: const Icon(Icons.menu), 
                        onPressed: () => Scaffold.of(context).openDrawer()
                      )),
                      Text("LUNYA HUB", style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 2,
                        color: allowNSFW ? Colors.redAccent : Colors.tealAccent
                      )),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline), 
                        onPressed: _showAddCustomLinkDialog
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: showNextImage, 
                      child: Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black45),
                            if (currentImageUrl.isNotEmpty)
                              Image.network(
                                currentImageUrl, 
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, p) => p == null ? child : 
                                  const Center(child: CircularProgressIndicator()),
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 50, color: Colors.white38),
                                        SizedBox(height: 10),
                                        Text("Ошибка загрузки ссылки.\nПопробуйте прямой URL (.jpg)", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))
                                      ],
                                    )
                                  );
                                },
                              )
                            else 
                              const Center(child: Icon(Icons.downloading, size: 50)),
                              
                            if (allowNSFW)
                              const Positioned(
                                top: 10, right: 10,
                                child: Chip(label: Text("18+"), backgroundColor: Colors.red, labelStyle: TextStyle(fontSize: 10)),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: FloatingActionButton.extended(
                          heroTag: "next",
                          onPressed: showNextImage,
                          label: const Text("NEXT"),
                          icon: const Icon(Icons.arrow_forward),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: 16),
                      FloatingActionButton(
                        heroTag: "set",
                        onPressed: setWallpaper,
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        child: const Icon(Icons.wallpaper),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
