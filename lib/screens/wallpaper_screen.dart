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
import 'logs_screen.dart';
import 'favorites_screen.dart';

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

    // Отметить текущее как просмотренное
    contentProvider.markAsShown(items[_currentIndex].id);

    setState(() {
      _currentIndex = (_currentIndex + 1) % items.length;
    });
  }

  Future<void> _downloadImage(ContentItem item) async {
    setState(() => _isDownloading = true);
    
    try {
      final response = await http.get(Uri.parse(item.mediaUrl));
      final dir = await getExternalStorageDirectory();
      final fileName = 'furry_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir!.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 Сохранено: $fileName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _saveToFavorites(ContentItem item) async {
    final contentProvider = context.read<ContentProvider>();
    await contentProvider.toggleSave(item);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item.isSaved ? '❤️ Добавлено в избранное' : '💔 Удалено из избранного'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  String _getSourceIcon(String sourceId) {
    if (sourceId.contains('reddit')) return '🔴';
    if (sourceId.contains('twitter')) return '🐦';
    if (sourceId.contains('telegram')) return '✈️';
    return '🌐';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        title: const Text('🐾 Furry Wallpapers'),
        actions: [
          // Кнопка избранного
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pink),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          // NSFW фильтр
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton(
              icon: Icon(
                settings.showNsfw ? Icons.visibility : Icons.visibility_off,
                color: settings.showNsfw ? Colors.red : Colors.grey,
              ),
              onPressed: settings.toggleNsfw,
              tooltip: settings.showNsfw ? 'Скрыть NSFW' : 'Показать NSFW',
            ),
          ),
          // Кнопка логов
          IconButton(
            icon: const Icon(Icons.article, color: Colors.amber),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              );
            },
          ),
          // Обновление
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
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepOrange),
                  SizedBox(height: 16),
                  Text('Загрузка артов...', style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wallpaper, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет обоев',
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadContent,
                    icon: const Icon(Icons.download),
                    label: const Text('Загрузить обои'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                    ),
                  ),
                ],
              ),
            );
          }

          final currentItem = items[_currentIndex];

          return GestureDetector(
            // Свайпы: вверх = сохранить, вниз = скачать, вправо = далее
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < -500) {
                // Свайп вверх - сохранить
                _saveToFavorites(currentItem);
              } else if (details.primaryVelocity! > 500) {
                // Свайп вниз - скачать
                _downloadImage(currentItem);
              }
            },
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 500) {
                // Свайп вправо - далее
                _nextImage();
              }
            },
            child: Column(
              children: [
                // Изображение
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: currentItem.mediaUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Colors.deepOrange),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.error, size: 64, color: Colors.red),
                        ),
                      ),
                      // Счётчик и источник
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            const SizedBox(height: 8),
                            // Источник
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_getSourceIcon(currentItem.sourceId)} Источник',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Информация внизу
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
                                Colors.black.withOpacity(0.9),
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
                              const SizedBox(height: 4),
                              Text(
                                '💡 Свайп ⬆️ сохранить | ⬇️ скачать | ➡️ далее',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Три кнопки
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Далее
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
                      // Сохранить
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _saveToFavorites(currentItem),
                          icon: Icon(currentItem.isSaved ? Icons.favorite : Icons.favorite_border),
                          label: const Text('Сохранить'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.pink,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Скачать
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isDownloading ? null : () => _downloadImage(currentItem),
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
            ),
          );
        },
      ),
    );
  }
}
