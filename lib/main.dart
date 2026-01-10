import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:async_wallpaper/async_wallpaper.dart';

void main() => runApp(const MaterialApp(home: FurryRedditApp()));

class FurryRedditApp extends StatefulWidget {
  const FurryRedditApp({super.key});
  @override
  State<FurryRedditApp> createState() => _FurryRedditAppState();
}

class _FurryRedditAppState extends State<FurryRedditApp> {
  String imageUrl = "";
  bool isLoading = false;

  // Прямая загрузка из Reddit r/furry
  Future<void> fetchFromReddit() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('https://www.reddit.com/r/furry/hot.json?limit=50'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final posts = data['data']['children'] as List;
        
        // Фильтруем только посты с картинками (i.redd.it)
        final imagePosts = posts.where((post) {
          final url = post['data']['url'] as String;
          return url.contains('i.redd.it') && (url.endsWith('.jpg') || url.endsWith('.png'));
        }).toList();

        if (imagePosts.isNotEmpty) {
          final randomPost = imagePosts[Random().nextInt(imagePosts.length)];
          setState(() => imageUrl = randomPost['data']['url']);
        }
      } else {
        throw Exception("Ошибка Reddit: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> setWallpaper() async {
    if (imageUrl.isEmpty) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Установка обоев...")));
      // Используем плагин async_wallpaper для установки
      await AsyncWallpaper.setWallpaper(
        url: imageUrl,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        toastMessage: "Обои установлены!",
        errorToastMessage: "Ошибка установки",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Не удалось установить")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("r/Furry Wallpapers"), backgroundColor: Colors.orange),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imageUrl.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(imageUrl, fit: BoxFit.contain),
                  ),
                ),
              )
            else
              const Icon(Icons.pets, size: 100, color: Colors.orange),
            
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator(color: Colors.orange)
            else ...[
              ElevatedButton(
                onPressed: fetchFromReddit,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text("Загрузить из Reddit"),
              ),
              const SizedBox(height: 10),
              if (imageUrl.isNotEmpty)
                ElevatedButton(
                  onPressed: setWallpaper,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Установить как обои"),
                ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
