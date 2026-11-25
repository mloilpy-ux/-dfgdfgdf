import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_item.dart';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sources_provider.dart';
import '../services/wallpaper_service.dart';
import '../theme.dart';
import 'favorites_screen.dart';
import 'gifs_screen.dart';
import 'logs_screen.dart';
import 'sources_screen.dart';
import 'videos_screen.dart';

enum _Destination { gifs, videos, sources, logs, filter }

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  int _index = 0;
  bool _refreshing = true;
  bool _downloading = false;
  bool _settingWallpaper = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnStart());
  }

  Future<void> _loadOnStart() async {
    if (!mounted) return;
    final content = context.read<ContentProvider>();
    final sources = context.read<SourcesProvider>();
    try {
      await sources.loadSources();
      await content.loadContent();
      if (content.items.isEmpty) await content.parseAllActiveSources(sources);
    } catch (_) {
      _showMessage('Не удалось загрузить обои');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    final content = context.read<ContentProvider>();
    final sources = context.read<SourcesProvider>();
    setState(() => _refreshing = true);
    try {
      final results = await content.parseAllActiveSources(sources);
      if (results.isEmpty) {
        _showMessage('Добавьте или включите источник');
      } else if (results.values.every((result) => result.failed)) {
        _showMessage(
          'Не удалось обновить источники. Подробности в разделе «Источники»',
        );
      }
      if (mounted) setState(() => _index = 0);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _move(List<ContentItem> items, int index, int offset) {
    if (items.length < 2) return;
    HapticFeedback.selectionClick();
    setState(() => _index = (index + offset) % items.length);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _download(ContentItem item) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final response = await http
          .get(Uri.parse(item.mediaUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw const HttpException('Image unavailable');
      }
      final directory =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final mediaType = response.headers['content-type']
          ?.split(';')
          .first
          .trim();
      final extension = switch (mediaType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      final name =
          'wallpaper_${DateTime.now().millisecondsSinceEpoch}.$extension';
      await File('${directory.path}/$name').writeAsBytes(response.bodyBytes);
      _showMessage('$name сохранён в папку приложения');
    } catch (_) {
      _showMessage('Не удалось скачать изображение');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _save(ContentItem item) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await context.read<ContentProvider>().toggleSave(item);
      _showMessage(
        saved
            ? (item.isSaved ? 'Удалено из избранного' : 'Добавлено в избранное')
            : 'Не удалось обновить избранное',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setWallpaper(ContentItem item) async {
    if (_settingWallpaper) return;
    setState(() => _settingWallpaper = true);
    try {
      final installed = await WallpaperService.setWallpaper(item.mediaUrl);
      _showMessage(
        installed ? 'Главный экран обновлён' : 'Не удалось установить обои',
      );
    } finally {
      if (mounted) setState(() => _settingWallpaper = false);
    }
  }

  Future<void> _openOriginal(String url) async {
    final uri = Uri.tryParse(url);
    try {
      if (uri != null &&
          (uri.scheme == 'https' || uri.scheme == 'http') &&
          await launchUrl(uri, mode: LaunchMode.externalApplication))
        return;
    } catch (_) {
      // The device may not have an app that can open the link.
    }
    _showMessage('Не удалось открыть публикацию');
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openSources() => _open(const SourcesScreen());

  Future<void> _chooseSource() async {
    final provider = context.read<ContentProvider>();
    final sources = context.read<SourcesProvider>().activeSources;
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Показывать источник'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Все источники'),
          ),
          for (final source in sources)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, source.id),
              child: Text(source.name),
            ),
        ],
      ),
    );
    if (chosen != null && mounted) {
      provider.selectSource(chosen.isEmpty ? null : chosen);
      setState(() => _index = 0);
    }
  }

  Future<void> _select(_Destination destination) async {
    switch (destination) {
      case _Destination.gifs:
        await _open(const GifsScreen());
      case _Destination.videos:
        await _open(const VideosScreen());
      case _Destination.sources:
        await _chooseSource();
      case _Destination.logs:
        await _open(const LogsScreen());
      case _Destination.filter:
        await context.read<SettingsProvider>().toggleNsfw();
        if (mounted) setState(() => _index = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final settings = context.watch<SettingsProvider>();
    final items = content.itemsFor(
      MediaKind.image,
      showNsfw: settings.showNsfw,
    );
    final loading = _refreshing || content.isLoading;

    return Theme(
      data: wallpaperTheme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Обои'),
          actions: [
            IconButton(
              onPressed: () => _open(const FavoritesScreen()),
              tooltip: 'Избранное',
              icon: const Icon(Icons.favorite_border_rounded),
            ),
            IconButton(
              onPressed: _openSources,
              tooltip: 'Источники',
              icon: const Icon(Icons.tune_rounded),
            ),
            PopupMenuButton<_Destination>(
              tooltip: 'Другие разделы',
              onSelected: _select,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _Destination.gifs,
                  child: Text('GIF'),
                ),
                const PopupMenuItem(
                  value: _Destination.videos,
                  child: Text('Видео'),
                ),
                CheckedPopupMenuItem(
                  value: _Destination.sources,
                  checked: content.selectedSourceId != null,
                  child: const Text('Фильтр по источнику'),
                ),
                const PopupMenuItem(
                  value: _Destination.logs,
                  child: Text('Журнал'),
                ),
                CheckedPopupMenuItem(
                  value: _Destination.filter,
                  checked: settings.showNsfw,
                  child: const Text('Показывать 18+'),
                ),
              ],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          top: false,
          child: items.isEmpty
              ? _emptyState(loading)
              : _gallery(items, loading),
        ),
      ),
    );
  }

  Widget _emptyState(bool loading) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Загрузка обоев'),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wallpaper_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              'Обоев пока нет',
              style: wallpaperTheme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Проверь источники, фильтр или обнови подборку.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Обновить подборку'),
            ),
            TextButton(
              onPressed: _openSources,
              child: const Text('Открыть источники'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gallery(List<ContentItem> items, bool loading) {
    final index = _index.clamp(0, items.length - 1);
    final item = items[index];
    final canBrowse = items.length > 1;
    final source = context
        .watch<SourcesProvider>()
        .sources
        .where((source) => source.id == item.sourceId)
        .firstOrNull;
    final colors = wallpaperTheme.colorScheme;
    final title = item.title.trim();
    final original = item.postUrl;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final speed = details.primaryVelocity ?? 0;
                    if (speed.abs() > 200)
                      _move(items, index, speed < 0 ? 1 : -1);
                  },
                  onVerticalDragEnd: (details) {
                    final speed = details.primaryVelocity ?? 0;
                    if (speed < -500) _save(item);
                    if (speed > 500) _download(item);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: colors.surfaceContainerLow),
                        CachedNetworkImage(
                          key: ValueKey(item.mediaUrl),
                          imageUrl: item.mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const Center(child: CircularProgressIndicator()),
                          errorWidget: (_, _, _) => const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image_outlined, size: 34),
                                SizedBox(height: 8),
                                Text('Изображение недоступно'),
                              ],
                            ),
                          ),
                        ),
                        if (loading)
                          const Align(
                            alignment: Alignment.topCenter,
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.isNotEmpty)
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: wallpaperTheme.textTheme.titleMedium,
                          ),
                        if (source != null)
                          Text(
                            source.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (original != null)
                    IconButton(
                      onPressed: () => _openOriginal(original),
                      tooltip: 'Открыть публикацию',
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  IconButton(
                    onPressed: loading ? null : _refresh,
                    tooltip: 'Обновить подборку',
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: canBrowse ? () => _move(items, index, -1) : null,
                    tooltip: 'Предыдущие обои',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      '${index + 1} из ${items.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: canBrowse ? () => _move(items, index, 1) : null,
                    tooltip: 'Следующие обои',
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _settingWallpaper
                          ? null
                          : () => _setWallpaper(item),
                      child: Text(
                        _settingWallpaper
                            ? 'Устанавливаем…'
                            : 'Установить обои',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: _saving ? null : () => _save(item),
                    tooltip: item.isSaved
                        ? 'Удалить из избранного'
                        : 'В избранное',
                    icon: Icon(
                      item.isSaved
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    onPressed: _downloading ? null : () => _download(item),
                    tooltip: 'Скачать',
                    icon: _downloading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
