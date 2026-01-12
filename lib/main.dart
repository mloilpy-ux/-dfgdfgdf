import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Добавить в pubspec.yaml

void main() {
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
  // --- STATE ---
  String currentImageUrl = "";
  bool isLoading = false;
  List<String> imageQueue = [];
  String redditAfterToken = "";
  
  // --- SETTINGS ---
  bool allowNSFW = false; // Фильтр по умолчанию включен (SFW only)
  List<String> customUrls = []; // Пользовательские ссылки

  String debugLog = "System initialized...";

  @override
  void initState() {
    super.initState();
    // Сразу грузим первую пачку
    fetchBatchFromReddit();
  }

  void addToLog(String message) {
    setState(() {
      debugLog += "\n> $message";
    });
  }

  // --- LOGIC ---
  
  void toggleNSFW(bool value) {
    setState(() {
      allowNSFW = value;
      // При смене режима очищаем очередь, чтобы загрузить новый контент
      imageQueue.clear();
      redditAfterToken = "";
      currentImageUrl = ""; 
    });
    fetchBatchFromReddit();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? "NSFW режим: ВКЛЮЧЕН (Осторожно!)" : "NSFW режим: ВЫКЛЮЧЕН (Safe Mode)"))
    );
  }

  Future<void> fetchBatchFromReddit() async {
    addToLog("Fetching content (NSFW: $allowNSFW)...");
    try {
      // Меняем источники в зависимости от режима
      String sources = "furry+furryart"; // Базовые SFW
      if (allowNSFW) {
        sources += "+furry_irl+furrymemes+yiff"; // Добавляем перчинку
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

          // ГЛАВНЫЙ ФИЛЬТР
          if (!allowNSFW && isOver18) continue; // Пропускаем NSFW если режим выключен

          if (u.contains('i.redd.it') && 
             (u.endsWith('.jpg') || u.endsWith('.png') || u.endsWith('.jpeg'))) {
            if (!imageQueue.contains(u)) {
               imageQueue.add(u);
               count++;
            }
          }
        }
        
        // Подмешиваем кастомные ссылки пользователя (если есть)
        if (customUrls.isNotEmpty) {
           imageQueue.insertAll(0, customUrls); // Ставим их в начало
           addToLog("Mixed in ${customUrls.length} custom user links");
        }

        addToLog("Loaded +$count suitable images.");
        // Если ничего не загрузилось и очередь пуста (из-за фильтров)
        if (imageQueue.isEmpty && count == 0) {
           addToLog("No images found with current filter. Retrying...");
           fetchBatchFromReddit(); // Рекурсия (опасно, но для примера пойдет)
        }
        
        // Если это первый запуск, сразу показываем
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
      // Перемешиваем немного для разнообразия, если это Reddit
      if (imageQueue.length > 5) {
        int index = Random().nextInt(3); // Берем одну из первых 3
        final next = imageQueue.removeAt(index);
        setState(() => currentImageUrl = next);
      } else {
         final next = imageQueue.removeAt(0);
         setState(() => currentImageUrl = next);
      }
    }
  }

  // Диалог добавления кастомной ссылки
  void _showAddCustomLinkDialog() {
    TextEditingController _urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить свой источник"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Вставьте прямую ссылку на картинку (Twitter/Telegram требуют Web-граббера, но пока можно прямые ссылки):", style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 10),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: "https://example.com/image.jpg",
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.public),
                  label: const Text("Twitter"),
                  onPressed: () => launchUrl(Uri.parse("https://twitter.com")), // Открыть браузер
                ),
                TextButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text("TG Web"),
                  onPressed: () => launchUrl(Uri.parse("https://web.telegram.org")), // Открыть браузер
                ),
              ],
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Отмена")),
          FilledButton(
            onPressed: () {
              if (_urlController.text.isNotEmpty) {
                setState(() {
                  customUrls.add(_urlController.text);
                  imageQueue.insert(0, _urlController.text); // Добавляем в начало очереди
                  currentImageUrl = _urlController.text; // Сразу показываем
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ссылка добавлена!")));
              }
            },
            child: const Text("Добавить"),
          )
        ],
      ),
    );
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    try {
      // Скачиваем
      final response = await http.get(Uri.parse(currentImageUrl));
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wall_temp.jpg');
      await file.writeAsBytes(response.bodyBytes);
      
      // Ставим
      await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Обои установлены!")));
    } catch (e) {
      addToLog("Wall Err: $e");
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Сайдбар (Drawer) для настроек
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
              title: const Text("Добавить ссылку"),
              subtitle: const Text("Twitter / Telegram / Web"),
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
          // Background
          if (currentImageUrl.isNotEmpty)
            Positioned.fill(
              child: Image.network(
                currentImageUrl, 
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.9),
                colorBlendMode: BlendMode.darken,
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                // AppBar Custom
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

                // Image Card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: showNextImage, // Тап по картинке = след.
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
                              )
                            else 
                              const Center(child: Icon(Icons.downloading, size: 50)),
                              
                            // NSFW Badge
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

                // Buttons
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
