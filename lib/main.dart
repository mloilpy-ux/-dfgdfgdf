import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:async_wallpaper/async_wallpaper.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Furry Wallpaper',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        brightness: Brightness.dark,
      ),
      home: WallpaperPage(),
    );
  }
}

class WallpaperPage extends StatefulWidget {
  @override
  _WallpaperPageState createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<WallpaperPage> {
  String status = 'Ready to get fresh art!';
  bool isLoading = false;
  String? currentImageUrl;

  Future<void> setWallpaper() async {
    setState(() {
      isLoading = true;
      status = 'Looking for fresh art in r/furry...';
    });

    try {
      // Получаем ссылку на картинку
      final response = await http.get(
        Uri.parse('https://meme-api.com/gimme/furry'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = data['url'];

        setState(() {
          currentImageUrl = imageUrl;
          status = 'Downloading image...';
        });

        // Скачиваем картинку
        final imageResponse = await http.get(Uri.parse(imageUrl));

        if (imageResponse.statusCode == 200) {
          // Сохраняем во временную папку
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/furry_wallpaper.jpg';
          final file = File(filePath);
          await file.writeAsBytes(imageResponse.bodyBytes);

          setState(() {
            status = 'Setting wallpaper...';
          });

          // Устанавливаем обои
          bool result = await AsyncWallpaper.setWallpaper(
                url: filePath,
                wallpaperLocation: AsyncWallpaper.HOME_SCREEN,
                goToHome: false,
              ) ??
              false;

          setState(() {
            isLoading = false;
            status = result
                ? '✅ Success! New wallpaper set!'
                : '❌ Failed to set wallpaper';
          });
        } else {
          throw Exception('Failed to download image');
        }
      } else {
        throw Exception('Failed to fetch from Reddit');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        status = '❌ Error: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Furry Wallpaper'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wallpaper,
                size: 100,
                color: Colors.purpleAccent,
              ),
              SizedBox(height: 40),
              Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: isLoading ? null : setWallpaper,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                  textStyle: TextStyle(fontSize: 20),
                ),
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Get Fresh Wallpaper'),
              ),
              SizedBox(height: 20),
              if (currentImageUrl != null)
                Text(
                  'Last image from: r/furry',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
