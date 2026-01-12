import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../models/content_item.dart';
import '../models/content_source.dart';
import 'sources_provider.dart';
import 'settings_provider.dart';
import 'logger_provider.dart';

class ContentProvider extends ChangeNotifier {
  late Box<ContentItem> contentsBox = Hive.box<ContentItem>('contents');
  late Box<String> seenBox = Hive.box<String>('seen');
  List<ContentItem> _contents = [];
  bool loading = false;
  List<ContentItem> get contents => _contents;

  ContentProvider();

  Future<void> fetchContent(BuildContext context) async {
    loading = true;
    notifyListeners();
    final sourcesProv = context.read<SourcesProvider>();
    final settings = context.read<SettingsProvider>();
    final logger = context.read<LoggerProvider>();
    logger.addLog('Начало парсинга...');
    int newCount = 0;
    for (final source in sourcesProv.sources.where((s) => s.active)) {
      logger.addLog('Парсинг ${source.name}');
      try {
        final response = await http.get(Uri.parse(source.url));
        if (response.statusCode == 200) {
          final jsonData = json.decode(response.body);
          final children = jsonData['data']['children'] as List<dynamic>? ?? [];
          for (final child in children) {
            final item = ContentItem.fromRedditJson(child['data'], source.name);
            if (item != null && !seenBox.containsKey(item.imageUrl)) {
              if (!settings.showNsfw && item.isNsfw) continue;
              if (settings.gifOnly && !item.isGif) continue;
              seenBox.put(item.imageUrl, 'seen');
              contentsBox.put(item.id, item);
              newCount++;
            }
          }
        }
      } catch (e) {
        logger.addLog('Ошибка ${source.name}: $e');
      }
    }
    logger.addLog('Добавлено $newCount новых');
    _contents = contentsBox.values.toList()
      ..sort((a, b) => b.created.compareTo(a.created));
    loading = false;
    notifyListeners();
  }

  Future<void> saveImage(BuildContext context, String imageUrl) async {
    final logger = context.read<LoggerProvider>();
    try {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          logger.addLog('Нет разрешения на хранение');
          return;
        }
      }
      final dir
