import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Убедитесь, что этот пакет в pubspec.yaml

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Важно для инициализации каналов
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
    // В релизе print может быть вырезан, но для дебага оставим
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
      if (imageQueue.length > 5) {
        int index = Random().nextInt(3); 
        final next = imageQueue.removeAt(index);
        setState(() => currentImageUrl = next);
      } else {
         final next = imageQueue.removeAt(0);
         setState(() => currentImageUrl = next);
      }
    }
  }

  void _showAddCustomLinkDialog() {
    // Контроллер создаем локально
    final TextEditingController urlController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить свой источник"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Вставьте прямую ссылку:", style: TextStyle(fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
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
                  onPressed: () => _launchExternal("https://twitter.com"), 
                ),
                TextButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text("TG Web"),
                  onPressed: () => _launchExternal("https://web.telegram.org"), 
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
                setState(() {
                  customUrls.add(urlController.text);
                  imageQueue.insert(0, urlController.text); 
                  currentImageUrl = urlController.text; 
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

  // Безопасный запуск URL
  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      addToLog("Could not launch $url");
    }
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Обои установлены!")));
      }
    } catch (e) {
      addToLog("Wall Err: $e");
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
              title: const Text("Добавить ссылку"),
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
