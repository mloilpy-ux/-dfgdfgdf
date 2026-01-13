import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../models/content_item.dart';
import '../widgets/furry_loading.dart';
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
  final Set<String> _errorUrls = {}; // Пропускать ошибочные

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
    
    var items = provider.items.where((item) => item.isGif).toList();
    
    if (!settings.showNsfw) {
      items = items.where((item) => !item.isNsfw).toList();
    }
    
    // Убрать ошибочные
    items = items.where((item) => !_errorUrls.contains(item.mediaUrl)).toList();
    
    return items;
  }

  Future<void> _downloadImage(ContentItem item) async {
    HapticFeedback.mediumImpact();
    setState(() => _isDownloading = true);
    
    try {
      final response = await http.get(Uri.parse(item.mediaUrl));
      final dir = await getExternalStorageDirectory();
      final fileName = 'furry_gif_${DateTime.now().millisecondsSinceEpoch}.mp4';
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

  void _handleError(String url) {
    setState(() {
      _errorUrls.add(url);
    });
    
    // Автоматически следующее
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _nextImage();
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
                    icon: const Icon(Icons.arrow_back, size: 40, color: Colors.deepOrange),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          }

          final currentItem = items[_currentIndex];

          return GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 500) {
                _nextImage();
              } else if (details.primaryVelocity! < -500) {
                _previousImage();
              }
            },
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! < -500) {
                _saveToFavorites(currentItem);
              } else if (details.primaryVelocity! > 500) {
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
                  errorWidget: (_, url, __) {
                    _handleError(url);
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.skip_next, size: 64, color: Colors.orange),
                          SizedBox(height: 8),
                          Text('Пропуск...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  },
                ),
                
                // МЕНЮ
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('GIF', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(
                            settings.showNsfw ? Icons.visibility : Icons.visibility_off,
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
                
                // ИСТОЧНИК
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
