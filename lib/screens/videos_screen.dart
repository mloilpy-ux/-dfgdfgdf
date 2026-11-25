import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../models/content_item.dart';
import '../widgets/media_video_preview.dart';
import 'package:url_launcher/url_launcher.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  int _currentIndex = 0;
  bool _isDownloading = false;
  final List<int> _history = [];

  void _nextImage() {
    HapticFeedback.selectionClick();

    final items = _getFilteredItems();
    if (items.isEmpty) return;

    _history.add(_currentIndex.clamp(0, items.length - 1));

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

    return provider.itemsFor(MediaKind.video, showNsfw: settings.showNsfw);
  }

  Future<void> _downloadImage(ContentItem item) async {
    HapticFeedback.mediumImpact();
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final response = await http.get(
        Uri.parse(item.mediaUrl),
        headers: item.mediaHeaders,
      );
      final dir = await getExternalStorageDirectory();
      final fileName =
          'furry_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
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
                  const Icon(Icons.video_library, size: 80, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет видео',
                    style: TextStyle(color: Colors.white),
                  ),
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
                MediaVideoPreview(
                  key: ValueKey(currentItem.mediaUrl),
                  url: currentItem.mediaUrl,
                  headers: currentItem.mediaHeaders,
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
                          'Видео',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: _history.isEmpty ? null : _previousImage,
                        tooltip: 'Предыдущее видео',
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: items.length < 2 ? null : _nextImage,
                        tooltip: 'Следующее видео',
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
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
