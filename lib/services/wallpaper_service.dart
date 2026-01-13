import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class WallpaperService {
  static const platform = MethodChannel('com.furry.wallpaper/set');

  static Future<bool> setWallpaper(String imageUrl) async {
    try {
      // 1. Скачать изображение
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Ошибка загрузки');
      }

      // 2. Сохранить временно
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/temp_wallpaper.jpg');
      await file.writeAsBytes(response.bodyBytes);

      // 3. Установить через нативный код
      final result = await platform.invokeMethod('setWallpaper', {
        'path': file.path,
      });

      // 4. Удалить временный файл
      await file.delete();

      return true;
    } on PlatformException catch (e) {
      print('Ошибка установки обоев: ${e.message}');
      return false;
    } catch (e) {
      print('Ошибка: $e');
      return false;
    }
  }
}
