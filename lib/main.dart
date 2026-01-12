import 'dart:io'; // Для работы с файлами
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart'; // Обязательно добавьте этот пакет в pubspec.yaml

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: FurryWallpaperApp()
));

class FurryWallpaperApp extends StatefulWidget {
  const FurryWallpaperApp({super.key});
  @override
  State<FurryWallpaperApp> createState() => _FurryWallpaperAppState();
}

class _FurryWallpaperAppState extends State<FurryWallpaperApp> {
  String currentImageUrl = "";
  bool isLoading = false;
  
  // Логика очереди и пагинации
  List<String> imageQueue = []; // Очередь загруженных ссылок
  String redditAfterToken = ""; // Маркер для загрузки следующей страницы Reddit
  
  String debugLog = "Log started...";

  void addToLog(String message) {
    // Пишем лог только в дебаг-консоль и переменную
    print(message); 
    setState(() {
      debugLog += "\n[${DateTime.now().toString().split(' ')[1].split('.')[0]}] $message";
    });
  }

  // Загрузка пачки постов с Reddit
  Future<void> fetchBatchFromReddit() async {
    addToLog("Fetching new batch (after: $redditAfterToken)...");
    try {
      final url = 'https://www.reddit.com/r/furry/hot.json?limit=25&after=$redditAfterToken';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter:LunyaApp:v1.1 (by /u/Lunya)'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Обновляем токен для следующей страницы
        redditAfterToken = data['data']['after'] ?? "";
        
        final posts = data['data']['children'] as List;
        int count = 0;
        
        for (var post in posts) {
          final postUrl = post['data']['url'] as String;
          // Фильтруем только прямые ссылки на картинки
          if (postUrl.contains('i.redd.it') && 
             (postUrl.endsWith('.jpg') || postUrl.endsWith('.png'))) {
            imageQueue.add(postUrl);
            count++;
          }
        }
        addToLog("Batch loaded: +$count images. Queue size: ${imageQueue.length}");
      } else {
        addToLog("Reddit Error: ${response.statusCode}");
      }
    } catch (e) {
      addToLog("Net Exception: $e");
    }
  }

  // Главная кнопка "Найти арт"
  Future<void> showNextImage() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    // Если очередь пуста, грузим новую пачку
    if (imageQueue.isEmpty) {
      await fetchBatchFromReddit();
    }

    if (imageQueue.isNotEmpty) {
      // Берем первую картинку из очереди и удаляем её (First-In-First-Out)
      // Это гарантирует отсутствие повторов
      final nextImage = imageQueue.removeAt(0);
      setState(() {
        currentImageUrl = nextImage;
        isLoading = false;
      });
      addToLog("Showing: ...${nextImage.substring(nextImage.length - 15)}");
    } else {
      setState(() => isLoading = false);
      addToLog("Queue is empty even after fetch!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось найти картинки :("))
      );
    }
  }

  // Установка обоев через скачивание файла
  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    addToLog("Downloading image for wallpaper...");
    
    try {
      // 1. Скачиваем файл во временную папку
      var file = await _downloadFile(currentImageUrl);
      if (file == null) return;

      addToLog("File saved to: ${file.path}");

      // 2. Устанавливаем обои из файла
      // ВАЖНО: goToHome: true свернет приложение, чтобы вы увидели результат
      bool result = await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );

      addToLog("Wallpaper set result: $result");
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Обои успешно установлены!"), backgroundColor: Colors.green),
      );

    } catch (e) {
      addToLog("Wallpaper Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // Вспомогательная функция для скачивания
  Future<File?> _downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        // Генерируем уникальное имя файла
        final fileName = "wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final file = File('${directory.path}/$fileName');
        return await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      addToLog("Download error: $e");
    }
    return null;
  }

  void showLog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF0F0F1A),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Debug Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.blueAccent),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: debugLog));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Text(debugLog, style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
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
        title: const Text("Lunya Wallpaper", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple[900],
        elevation: 0,
        actions: [IconButton(onPressed: showLog, icon: const Icon(Icons.bug_report, color: Colors.white70))],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.black26,
                  width: double.infinity,
                  child: currentImageUrl.isNotEmpty
                      ? Image.network(
                          currentImageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) => 
                            const Center(child: Icon(Icons.broken_image, color: Colors.red, size: 50)),
                        )
                      : const Center(
                          child: Icon(Icons.image_search, size: 80, color: Colors.white12)
                        ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : showNextImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurpleAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      icon: isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.refresh, color: Colors.white),
                      label: Text(
                        isLoading ? "Загрузка..." : "Следующий арт", 
                        style: const TextStyle(color: Colors.white, fontSize: 16)
                      ),
                    ),
                  ),
                ),
                if (currentImageUrl.isNotEmpty) ...[
                  const SizedBox(width: 15),
                  SizedBox(
                    height: 55,
                    width: 55,
                    child: ElevatedButton(
                      onPressed: setWallpaper,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: const Icon(Icons.wallpaper, color: Colors.white),
                    ),
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
