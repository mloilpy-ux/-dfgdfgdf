import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../models/content_item.dart';
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
      // Prefetch a small image batch; videos remain on demand to limit traffic.
      for (final item
          in content.items
              .where((i) => i.kind == MediaKind.image && !i.isNsfw)
              .take(8)) {
        try {
          await DefaultCacheManager()
              .downloadFile(item.mediaUrl, authHeaders: item.mediaHeaders)
              .timeout(const Duration(seconds: 12));
        } catch (e) {
          log.log('Предзагрузка: ${e.runtimeType}', isError: true);
        }
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
