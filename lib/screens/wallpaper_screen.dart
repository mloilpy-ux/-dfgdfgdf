import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/content_provider.dart';
import '../providers/sources_provider.dart';
import '../providers/settings_provider.dart';
import '../models/content_item.dart';

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  int _currentIndex = 0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContent();
    });
  }

  Future<void> _loadContent() async {
    final contentProvider = context.read<ContentProvider>();
    final sourcesProvider = context.read<SourcesProvider>();
    
    await contentProvider.loadContent();
    
    if (contentProvider.items.isEmpty) {
      await contentProvider.parseAllActiveSources(sourcesProvider);
    }
  }

  void _nextImage() {
    final contentProvider = context.read<ContentProvider>();
    final settings = context.read<SettingsProvider>();
    
    final items = settings.showNsfw
        ? contentProvider.items
        : contentProvider.items.where((item) => !item.isNsfw).toList();

    if (items.isEmpty) return;

    setState(() {
      _currentIndex = (_currentIndex + 1) % items.length;
    });
  }

  Future<void> _downloadImage(ContentItem item) async {
    setState(() => _isDownloading = true);
    
    try {
      final response = await http.get(Uri.parse(item.mediaUrl));
      final dir = await getExternalStorageDirectory();
      final file = File('${dir!.path}/wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _setWallpaper(ContentItem item) async {
    // Для установки обоев понадобится пакет wallpaper_manager
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Функция установки обоев в разработке')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐾 Furry Wallpapers'),
        actions: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton(
              icon: Icon(
                settings.showNsfw ? Icons.visibility : Icons.visibility_off,
                color: settings.showNsfw ? Colors.red : Colors.grey,
              ),
              onPressed: settings.toggleNsfw,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContent,
          ),
        ],
      ),
      body: Consumer2<ContentProvider, SettingsProvider>(
        builder: (context, contentProvider, settings, _) {
          final items = settings.showNsfw
              ? contentProvider.items
              : contentProvider.items.where((item) => !item.isNsfw).toList();

          if (contentProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wallpaper, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Нет обоев', style: TextStyle(fontSize: 20)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadContent,
                    icon: const Icon(Icons.download),
                    label: const Text('Загрузить обои'),
                  ),
                ],
              ),
            );
          }

          final currentItem = items[_currentIndex];

          return Column(
            children: [
              // Изображение во весь экран
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity! > 0) {
                      // Свайп вправо - предыдущее
                      setState(() {
                        _currentIndex = (_currentIndex - 1 + items.length) % items.length;
                      });
                    } else if (details.primaryVelocity! < 0) {
                      // Свайп влево - следующее
                      _nextImage();
                    }
                  },
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: currentItem.mediaUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (_, __, ___) => const Center(
                            child: Icon(Icons.error, size: 64, color: Colors.red),
                          ),
                        ),
                        // Счётчик изображений
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${items.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        // Заголовок внизу
                        Positioned(
                          bottom: 100,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentItem.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (currentItem.author != null)
                                  Text(
                                    'by ${currentItem.author}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Три кнопки
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Кнопка "Далее"
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nextImage,
                        icon: const Icon(Icons.navigate_next),
                        label: const Text('Далее'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Кнопка "Установить"
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _setWallpaper(currentItem),
                        icon: const Icon(Icons.wallpaper),
                        label: const Text('Установить'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Кнопка "Скачать"
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isDownloading
                            ? null
                            : () => _downloadImage(currentItem),
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download),
                        label: const Text('Скачать'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
