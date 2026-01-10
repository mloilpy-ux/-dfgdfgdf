import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:async_wallpaper/async_wallpaper.dart';

void main() => runApp(const MaterialApp(home: FurryWallpaperApp()));

class FurryWallpaperApp extends StatefulWidget {
  const FurryWallpaperApp({super.key});
  @override
  State<FurryWallpaperApp> createState() => _FurryWallpaperAppState();
}

class _FurryWallpaperAppState extends State<FurryWallpaperApp> {
  String imageUrl = "";
  bool isLoading = false;
  String debugLog = "Log started...";

  void addToLog(String message) {
    setState(() {
      debugLog += "\n[${DateTime.now().toString().split(' ')[1].split('.')[0]}] $message";
    });
  }

  Future<void> fetchFromReddit() async {
    setState(() => isLoading = true);
    addToLog("Fetching from r/furry...");
    try {
      // ОБХОД ОГРАНИЧЕНИЙ: User-Agent обязателен для Reddit
      final response = await http.get(
        Uri.parse('https://www.reddit.com/r/furry/hot.json?limit=30'),
        headers: {'User-Agent': 'Flutter:LunyaApp:v1.0 (by /u/Lunya)'},
      ).timeout(const Duration(seconds: 15));

      addToLog("Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        final imagePosts = posts.where((post) {
          final url = post['data']['url'] as String;
          return url.contains('i.redd.it') && (url.endsWith('.jpg') || url.endsWith('.png'));
        }).toList();

        if (imagePosts.isNotEmpty) {
          final newUrl = imagePosts[Random().nextInt(imagePosts.length)]['data']['url'];
          setState(() => imageUrl = newUrl);
          addToLog("Found image: $newUrl");
        } else {
          addToLog("No image posts found in Hot.");
        }
      } else {
        addToLog("Reddit Error: ${response.body}");
      }
    } catch (e) {
      addToLog("Exception: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> setWallpaper() async {
    if (imageUrl.isEmpty) return;
    addToLog("Starting wallpaper set...");
    try {
      // ИСПРАВЛЕНИЕ: Убрали toastMessage для совместимости с v2.1.0
      await AsyncWallpaper.setWallpaper(
        url: imageUrl,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );
      addToLog("Success: Wallpaper set!");
    } catch (e) {
      addToLog("Wallpaper Error: $e");
    }
  }

  void showLog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black87,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Debug Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blue),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: debugLog));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(debugLog, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text("Lunya r/Furry"),
        backgroundColor: Colors.deepPurple,
        actions: [IconButton(onPressed: showLog, icon: const Icon(Icons.terminal))],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.contain)
                  : const Icon(Icons.pets, size: 100, color: Colors.white24),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : fetchFromReddit,
                    child: Text(isLoading ? "Загрузка..." : "Найти арт"),
                  ),
                ),
                if (imageUrl.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: setWallpaper,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Icon(Icons.wallpaper),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
