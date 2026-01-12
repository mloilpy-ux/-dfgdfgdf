import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:path_provider/path_provider.dart'; 

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
  
  List<String> imageQueue = []; 
  String redditAfterToken = ""; 
  
  String debugLog = "Log started...";

  void addToLog(String message) {
    print(message); 
    setState(() {
      debugLog += "\n[${DateTime.now().toString().split(' ')[1].split('.')[0]}] $message";
    });
  }

  // Обновленная функция с новыми источниками
  Future<void> fetchBatchFromReddit() async {
    addToLog("Fetching mix (furry+irl+memes+art)...");
    try {
      // ИСПОЛЬЗУЕМ МУЛЬТИ-РЕДДИТ URL: объединяем источники через "+"
      // Это дает смешанную ленту "Горячего" из всех 4 сабреддитов
      final sources = "furry+furry_irl+furrymemes+furryart";
      final url = 'https://www.reddit.com/r/$sources/hot.json?limit=30&after=$redditAfterToken';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Flutter:LunyaApp:v1.2 (by /u/Lunya)'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        redditAfterToken = data['data']['after'] ?? "";
        
        final posts = data['data']['children'] as List;
        int count = 0;
        
        for (var post in posts) {
          final postData = post['data'];
          final postUrl = postData['url'] as String;
          
          // Дополнительная проверка: иногда картинки в furry_irl это gif, 
          // для обоев лучше пока оставить jpg/png.
          if (postUrl.contains('i.redd.it') && 
             (postUrl.endsWith('.jpg') || postUrl.endsWith('.png') || postUrl.endsWith('.jpeg'))) {
            
            // Проверка на дубликаты (если вдруг Reddit вернет то же самое)
            if (!imageQueue.contains(postUrl) && postUrl != currentImageUrl) {
               imageQueue.add(postUrl);
               count++;
            }
          }
        }
        addToLog("Batch loaded: +$count images. Total in queue: ${imageQueue.length}");
      } else {
        addToLog("Reddit Error: ${response.statusCode}");
      }
    } catch (e) {
      addToLog("Net Exception: $e");
    }
  }

  Future<void> showNextImage() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    if (imageQueue.isEmpty) {
      await fetchBatchFromReddit();
    }

    if (imageQueue.isNotEmpty) {
      final nextImage = imageQueue.removeAt(0);
      setState(() {
        currentImageUrl = nextImage;
        isLoading = false;
      });
      // Показываем в логе, откуда примерно файл
      addToLog("Showing: ...${nextImage.substring(nextImage.lastIndexOf('/'))}");
    } else {
      setState(() => isLoading = false);
      addToLog("Queue is empty! Try again.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Пусто... Попробуйте нажать еще раз!"))
        );
      }
    }
  }

  Future<void> setWallpaper() async {
    if (currentImageUrl.isEmpty) return;
    addToLog("Downloading image...");
    
    try {
      var file = await _downloadFile(currentImageUrl);
      if (file == null) return;

      addToLog("Setting wallpaper...");

      bool result = await AsyncWallpaper.setWallpaperFromFile(
        filePath: file.path,
        wallpaperLocation: AsyncWallpaper.BOTH_SCREENS,
        goToHome: true,
      );

      addToLog("Result: $result");
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Готово! Обои обновлены."), backgroundColor: Colors.green),
      );

    } catch (e) {
      addToLog("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Ошибка: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<File?> _downloadFile(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getTemporaryDirectory();
        final fileName = "wall_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final file = File('${directory.path}/$fileName');
        return await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      addToLog("Download failed: $e");
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
                const Text("System Log", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF121212), // Более темный фон
      appBar: AppBar(
        title: const Text("Lunya Mix Feed", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo[900],
        actions: [IconButton(onPressed: showLog, icon: const Icon(Icons.data_object, color: Colors.white54))],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white10,
                  width: double.infinity,
                  child: currentImageUrl.isNotEmpty
                      ? Image.network(
                          currentImageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
                          },
                          errorBuilder: (context, error, stack) => 
                            const Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.redAccent, size: 40),
                                SizedBox(height: 10),
                                Text("Не удалось загрузить картинку", style: TextStyle(color: Colors.white54))
                              ],
                            )),
                        )
                      : const Center(
                          child: Icon(Icons.layers, size: 80, color: Colors.white12)
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
                  flex: 3,
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : showNextImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      icon: isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.shuffle, color: Colors.white), // Иконка shuffle так как это микс
                      label: Text(
                        isLoading ? "Загрузка..." : "Микс Арт/Мемы", 
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  width: 60,
                  child: ElevatedButton(
                    onPressed: currentImageUrl.isNotEmpty ? setWallpaper : null, // Блокируем, если пусто
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                    child: const Icon(Icons.wallpaper, color: Colors.white, size: 28),
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
