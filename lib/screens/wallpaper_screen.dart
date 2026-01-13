import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../providers/content_provider.dart';
import '../providers/sources_provider.dart';
import '../providers/settings_provider.dart';
import '../models/content_item.dart';
import '../widgets/furry_loading.dart';
import 'logs_screen.dart';
import 'favorites_screen.dart';
import 'sources_screen.dart';
import 'gifs_screen.dart';
import 'videos_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class WallpaperScreen extends StatefulWidget {
  const WallpaperScreen({super.key});

  @override
  State<WallpaperScreen> createState() => _WallpaperScreenState();
}

class _WallpaperScreenState extends State<WallpaperScreen> {
  int _currentIndex = 0;
  bool _isDownloading = false;
  final List<int> _history = [];

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
    HapticFeedback.selectionClick();
    
    final contentProvider = context.read<ContentProvider>();
    final settings = context.read<SettingsProvider>();
    
    final items = _getFilteredItems(contentProvider, settings);
    if (items.isEmpty) return;

    _history.add(_currentIndex);
    contentProvider.markAsShown(items[_currentIndex].id);

    setState(() {
      _currentIndex = (_currentIndex + 1) % items.length;
    });
  }

  void _previousImage() {
    if (_history.isEmpty) return;
    setState(() {
      _currentIndex = _history.removeLast();
    });
  }

  List<ContentItem> _getFilteredItems(ContentProvider provider, SettingsProvider settings) {
    var items = provider.items;
    
    // Фильтр NSFW
    if (!settings.showNsfw) {
      items = items.where((item) => !item.isNsfw).toList();
    }
    
    // Только фото (без GIF и видео)
    items = items.where((item) => !item.isGif).toList();
    
    return items;
  }

  Future<void> _downloadImage(ContentItem item) async {
    HapticFeedback.mediumImpact();
    setState(() => _isDownloading = true);
    
    try {
      final response = await http.get(Uri.parse(item.mediaUrl));
      final dir = await getExternalStorageDirectory();
      final ext = item.isGif ? 'mp4' : 'jpg';
      final fileName = 'furry_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${dir!.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('💾 $fileName'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isDownloading = false);
    }
  }

  Future<void> _saveToFavorites(ContentItem item) async {
    HapticFeedback.lightImpact();
    
    final contentProvider = context.read<ContentProvider>();
    await contentProvider.toggleSave(item);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item.isSaved ? '💜' : '💔'),
          duration: const Duration(milliseconds: 500),
          backgroundColor: item.isSaved ? Colors.pink : Colors.grey,
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
      body: Consumer2<ContentProvider, SettingsProvider>(
        builder: (context, contentProvider, settings, _) {
          final items = _getFilteredItems(contentProvider, settings);

          if (contentProvider.isLoading) {
            return const Center(child: FurryLoadingIndicator());
          }

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wallpaper, size: 80, color: Colors.grey),
                  const SizedBox(height: 24),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 40, color: Colors.deepOrange),
                    onPressed: _loadContent,
                  ),
                ],
              ),
            );
          }

          final currentItem = items[_currentIndex];

          return GestureDetector(
            // СВАЙП СЛЕВА → НАПРАВО = ДАЛЕЕ
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 500) {
                // СЛЕВА → НАПРАВО
                _nextImage();
              } else if (details.primaryVelocity! < -500) {
                // СПРАВА → НАЛЕВО
                _previousImage();
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < -500) {
                // ВВЕРХ
                _saveToFavorites(currentItem);
              } else if (details.primaryVelocity! > 500) {
                // ВНИЗ
                _downloadImage(currentItem);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: currentItem.mediaUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(child: FurryLoadingIndicator()),
                  errorWidget: (_, __, ___) => const Center(child: Icon(Icons.error, size: 64, color: Colors.red)),
                ),
                
                // МЕНЮ ВВЕРХУ
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.source, color: Colors.white),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const SourcesScreen()));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.gif_box, color: Colors.white),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const GifsScreen()));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.video_library, color: Colors.white),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const VideosScreen()));
                              },
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.pink),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen()));
                              },
                            ),
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
                              icon: const Icon(Icons.article, color: Colors.amber),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const LogsScreen()));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: _loadContent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // КНОПКА ИСТОЧНИКА
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: GestureDetector(
                    onTap: () async {
                      if (currentItem.postUrl != null) {
                        await launchUrl(Uri.parse(currentItem.postUrl!));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _getSourceIcon(currentItem.sourceId),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                ),
                
                // СЧЁТЧИК
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${items.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
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
