import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../models/content_item.dart';
import 'sources_provider.dart';
import 'settings_provider.dart';
import 'logger_provider.dart';

class ContentProvider extends ChangeNotifier {
  late Box<ContentItem> contentsBox = Hive.box<ContentItem>('contents');
  late Box<String> seenBox = Hive.box<String>('seen');
  List<ContentItem> _contents = [];
  bool _loading = false;

  List<ContentItem> get contents => _contents;
  bool get loading => _loading;

  ContentProvider() {
    _loadContents();
  }

  void _loadContents() {
    _contents = contentsBox.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    notifyListeners();
  }

  Future<void> fetchContent(BuildContext context) async {
    _loading = true;
    notifyListeners();

    final sourcesProv = context.read<SourcesProvider>();
    final settingsProv = context.read<SettingsProvider>();
    final loggerProv = context.read<LoggerProvider>();

    loggerProv.addLog('🦊 Начало парсинга активных источников');

    int newCount = 0;
    for (final source in sourcesProv.sources.where((s) => s.active)) {
      loggerProv.addLog('📡 Парсинг ${source.name}');
      try {
        final response = await http.get(Uri.parse(source.url));
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final children = data['data']['children'] as List<dynamic>? ?? [];
          for (final child in children.take(20)) {  // Limit for perf
            final itemData = child['data'] as Map<String, dynamic>?;
            final item = ContentItem.fromRedditJson(itemData ?? {}, source.name);
            if (item == null || seenBox.containsKey(item.imageUrl)) continue;

            // Filters
            if (!settingsProv.showNsfw && item.isNsfw) continue;
            if (settingsProv.gifOnly && !item.isGif) continue;

            seenBox.put(item.imageUrl, DateTime.now().toIso8601String());
            contentsBox.put(item.id, item);
            newCount++;
          }
          loggerProv.addLog('✅ ${source.name}: +$newCount новых');
        } else {
          loggerProv.addLog('❌ ${source.name}: HTTP ${response.statusCode}');
        }
      } catch (e) {
        loggerProv.addLog('💥 Ошибка ${source.name}: $e');
      }
    }

    _contents = contentsBox.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    _loading = false;
    notifyListeners();
    loggerProv.addLog('🎉 Парсинг завершён: $newCount артов');
  }

  Future<void> saveImage(BuildContext context, String imageUrl) async {
    final loggerProv = context.read<LoggerProvider>();
    try {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
        if (!status.isGranted) {
          loggerProv.addLog('🚫 Нет разрешения на сохранение');
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Разрешение на хранение отклонено')));
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final filename = imageUrl.split('/').last.replaceAll(RegExp(r'[^a-zA-Z0-9\.]'), '_');
      final localPath = '${dir.path}/$filename';

      await Dio().download(imageUrl, localPath);
      final success = await Gal.putImage(localPath);

      if (success) {
        loggerProv.addLog('💾 Сохранено: $filename');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Арт сохранён в галерею! 🐾')));
      } else {
        loggerProv.addLog('❌ Не удалось сохранить $filename');
      }

      await File(localPath).delete();
    } catch (e) {
      loggerProv.addLog('💥 Ошибка сохранения: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void toggleFavorite(String id) {
    // TODO: добавить флаг favorite в модель ContentItem
    notifyListeners();
  }
}
