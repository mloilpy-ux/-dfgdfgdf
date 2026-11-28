import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'source_response.dart';
import '../providers/content_provider.dart';
import '../providers/sources_provider.dart';
import 'logger_service.dart';

@pragma('vm:entry-point')
void syncDispatcher() {
  Workmanager().executeTask((task, data) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('backgroundSync') ?? true)) return true;
    final log = LoggerService.instance;
    await log.init(background: true);
    final sources = SourcesProvider();
    final content = ContentProvider();
    try {
      log.log('Фоновая загрузка: начало');
      await sources.loadSources();
      final active = sources.activeSources;
      final offset = prefs.getInt('syncOffset') ?? 0;
      for (var i = 0; i < active.length && i < 6; i++) {
        final source = active[(offset + i) % active.length];
        final result = await content.importSource(source, sources);
        if (!result.failed)
          await content.importSource(source, sources, more: true);
      }
      if (active.isNotEmpty)
        await prefs.setInt('syncOffset', (offset + 6) % active.length);
      // Share the image/video cache with the UI. Bound network and RAM per run.
      final client = http.Client();
      var budget = 24 * 1024 * 1024;
      try {
        for (final item
            in content.items
                .where((i) => !i.isNsfw || (prefs.getBool('showNsfw') ?? false))
                .take(8)) {
          if (budget <= 0) break;
          try {
            if (await DefaultCacheManager().getFileFromCache(item.mediaUrl) !=
                null)
              continue;
            final response = await fetchSource(
              client,
              Uri.parse(item.mediaUrl),
              service: 'Предзагрузка',
              headers: item.mediaHeaders,
              maxBytes: budget < 6 * 1024 * 1024 ? budget : 6 * 1024 * 1024,
            );
            final type = response.headers['content-type'] ?? '';
            if (!type.startsWith('image/') && !type.startsWith('video/'))
              continue;
            budget -= response.bodyBytes.length;
            await DefaultCacheManager().putFile(
              item.mediaUrl,
              response.bodyBytes,
              maxAge: const Duration(days: 7),
            );
            log.log(
              'Предзагрузка ${item.kind.name}: ${response.bodyBytes.length} байт',
            );
          } catch (e) {
            log.log('Предзагрузка: $e', isError: true);
          }
        }
      } finally {
        client.close();
      }
      log.log('Фоновая загрузка: завершена');
      await prefs.setString(
        'lastBackgroundSync',
        DateTime.now().toIso8601String(),
      );
      return true;
    } catch (e, stack) {
      log.log('Фоновая ошибка: $e\n$stack', isError: true);
      return false;
    } finally {
      await log.flush();
      content.dispose();
      sources.dispose();
    }
  });
}

class BackgroundSync {
  static Future<void> configure(bool enabled) async {
    await Workmanager().initialize(syncDispatcher);
    if (!enabled) {
      await Workmanager().cancelByUniqueName('media-periodic');
      return;
    }
    await Workmanager().registerPeriodicTask(
      'media-periodic',
      'media-sync',
      frequency: const Duration(minutes: 30),
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresBatteryNotLow: true,
      ),
    );
  }
}
