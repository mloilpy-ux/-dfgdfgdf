import '../services/media_download.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../models/content_item.dart';
import '../widgets/furry_loading.dart';
import '../widgets/media_video_preview.dart';
import '../services/wallpaper_service.dart';
import 'package:url_launcher/url_launcher.dart';

class GifsScreen extends StatefulWidget {
  const GifsScreen({super.key});

  @override
  State<GifsScreen> createState() => _GifsScreenState();
}

class _GifsScreenState extends State<GifsScreen> {
  int _currentIndex = 0;
  bool _isDownloading = false;
  final List<int> _history = [];
  final Set<String> _errorUrls = {};

  void _nextImage() {
    HapticFeedback.selectionClick();

    final items = _getFilteredItems();
    if (items.isEmpty) return;

    _history.add(_currentIndex);

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

  List<ContentItem> _getFilteredItems() {
    final provider = context.read<ContentProvider>();
    final settings = context.read<SettingsProvider>();

    return provider
        .itemsFor(MediaKind.gif, showNsfw: settings.showNsfw)
        .where((item) => !_errorUrls.contains(item.mediaUrl))
        .toList();
  }

  Future<void> _downloadImage(ContentItem item) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final location = await MediaDownload.save(item);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Сохранено: $location')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось скачать медиа. Подробности в журнале.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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

  Future<void> _setWallpaper(ContentItem item) async {
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.purple),
            SizedBox(height: 16),
            Text(
              'Установка... 🐾',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );

    try {
      final success = await WallpaperService.setWallpaper(
        item.mediaUrl,
        headers: item.mediaHeaders,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '🖼️' : '❌'),
            duration: const Duration(seconds: 1),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _handleError(String url) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_errorUrls.contains(url)) {
        setState(() => _errorUrls.add(url));
      }
    });
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
          final items = _getFilteredItems();

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gif_box, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Нет GIF', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 24),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 40,
                      color: Colors.deepOrange,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          }

          final currentItem = items[_currentIndex.clamp(0, items.length - 1)];

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 500) {
                _nextImage();
              } else if ((details.primaryVelocity ?? 0) < -500) {
                _previousImage();
              }
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -500) {
                _saveToFavorites(currentItem);
              } else if ((details.primaryVelocity ?? 0) > 500) {
                _downloadImage(currentItem);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (currentItem.usesVideoPlayer)
                  MediaVideoPreview(
                    key: ValueKey(currentItem.mediaUrl),
                    muted: true,
                    url: currentItem.mediaUrl,
                    headers: currentItem.mediaHeaders,
                  )
                else
                  CachedNetworkImage(
                    imageUrl: currentItem.mediaUrl,
                    httpHeaders: currentItem.mediaHeaders,
                    fit: BoxFit.contain,
                    placeholder: (_, __) =>
                        const Center(child: FurryLoadingIndicator()),
                    errorWidget: (_, url, __) {
                      _handleError(url);
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.skip_next,
                              size: 64,
                              color: Colors.orange,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Пропуск...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'GIF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            settings.showNsfw
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: settings.showNsfw ? Colors.red : Colors.grey,
                          ),
                          onPressed: () {
                            settings.toggleNsfw();
                            setState(() {
                              _currentIndex = 0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

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

                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _setWallpaper(currentItem),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.wallpaper,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 20,
                  right: 20,
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
