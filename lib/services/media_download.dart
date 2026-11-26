import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/content_item.dart';
import 'logger_service.dart';

class MediaDownload {
  static Future<String> save(ContentItem item) async {
    final client = http.Client();
    File? file;
    try {
      final request = http.Request('GET', Uri.parse(item.mediaUrl))
        ..headers.addAll(item.mediaHeaders);
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200)
        throw HttpException('HTTP ${response.statusCode}');
      final mime = response.headers['content-type']?.split(';').first ?? '';
      if (!mime.startsWith('image/') && !mime.startsWith('video/'))
        throw const FormatException('Сервер не вернул медиа');
      final ext = switch (mime) {
        'image/gif' => 'gif',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'video/webm' => 'webm',
        'video/mp4' => 'mp4',
        _ => 'jpg',
      };
      final name = 'furry_${DateTime.now().millisecondsSinceEpoch}.$ext';
      file = File('${(await getTemporaryDirectory()).path}/$name');
      final sink = file.openWrite();
      var bytes = 0;
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 20),
        )) {
          bytes += chunk.length;
          if (bytes > 100 * 1024 * 1024)
            throw const FormatException('Файл больше 100 МБ');
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      final location = await const MethodChannel('com.furry.wallpaper/set')
          .invokeMethod<String>('saveMedia', {
            'path': file.path,
            'name': name,
            'mime': mime,
          });
      LoggerService.instance.log('Сохранение медиа: $bytes байт');
      return location ?? name;
    } catch (e) {
      LoggerService.instance.log('Загрузка медиа: $e', isError: true);
      rethrow;
    } finally {
      client.close();
      if (file != null && await file.exists()) await file.delete();
    }
  }
}
