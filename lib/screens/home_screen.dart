import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/source_provider.dart';
import '../widgets/content_card.dart';
import '../models/content_item.dart';
import 'saved_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<SourceProvider>().loadSources();
      context.read<ContentProvider>().loadNewContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Furry Hub', style: TextStyle(color: Colors.white)),
        actions: [
          PopupMenuButton<ContentType>(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onSelected: (type) {
              setState(() => _currentIndex = 0);
              context.read<ContentProvider>().setContentType(type);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: ContentType.all, child: Text('Всё')),
              PopupMenuItem(value: ContentType.images, child: Text('Картинки')),
              PopupMenuItem(value: ContentType.gifs, child: Text('GIF')),
              PopupMenuItem(value: ContentType.videos, child: Text('Видео')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.filteredItems.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          if (provider.filteredItems.isEmpty) {
            return _buildEmptyState(provider);
          }

          if (_currentIndex >= provider.filteredItems.length) {
            setState(() => _currentIndex = 0);
          }

          final item = provider.filteredItems[_currentIndex];

          return Column(
            children: [
              // Индикатор прогресса
              _buildProgressIndicator(provider),
              
              // Основная картинка
              Expanded(
                child: ContentCard(
                  item: item,
                  onTap: () => _showFullscreen(item),
                ),
              ),
              
              // Кнопки управления
              _buildControlButtons(provider, item),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(ContentProvider provider) {
    final total = provider.filteredItems.length;
    final current = _currentIndex + 1;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: current / total,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
              minHeight: 4,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$current / $total',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ContentProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 100, color: Colors.green),
          const SizedBox(height: 20),
          const Text(
            'Весь контент просмотрен!',
            style: TextStyle(fontSize: 24, color: Colors.white),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _currentIndex = 0);
              provider.loadNewContent();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Обновить'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(ContentProvider provider, ContentItem item) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Кнопка: ДАЛЕЕ (пропустить)
            _buildButton(
              icon: Icons.skip_next,
              label: 'Далее',
              color: Colors.grey,
              onPressed: () => _nextImage(provider, false),
            ),
            
            // Кнопка: УСТАНОВИТЬ ОБОИ
            if (!item.isGif && !item.mediaUrl.contains('.mp4'))
              _buildButton(
                icon: Icons.wallpaper,
                label: 'Обои',
                color: Colors.blue,
                onPressed: () => _setWallpaper(item),
              ),
            
            // Кнопка: СОХРАНИТЬ
            _buildButton(
              icon: Icons.favorite,
              label: 'Сохранить',
              color: Colors.pink,
              onPressed: () => _nextImage(provider, true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextImage(ContentProvider provider, bool save) {
    final item = provider.filteredItems[_currentIndex];

    if (save) {
      provider.saveItem(item);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💾 Сохранено!'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      provider.markAsSeen(item.id);
    }

    setState(() {
      _currentIndex++;
      
      if (_currentIndex >= provider.filteredItems.length) {
        _currentIndex = 0;
        provider.loadNewContent();
      } else if (_currentIndex >= provider.filteredItems.length - 3) {
        provider.loadNewContent();
      }
    });
  }

  void _setWallpaper(ContentItem item) async {
    final location = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Установить обои'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Главный экран'),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Экран блокировки'),
              onTap: () => Navigator.pop(context, 2),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Оба экрана'),
              onTap: () => Navigator.pop(context, 3),
            ),
          ],
        ),
      ),
    );

    if (location != null) {
      _applyWallpaper(item, location);
    }
  }

  void _applyWallpaper(ContentItem item, int location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );

    try {
      final AsyncWallpaper = (await import('package:async_wallpaper/async_wallpaper.dart')).AsyncWallpaper;
      
      bool result = false;
      switch (location) {
        case 1:
          result = await AsyncWallpaper.setWallpaperFromUrl(
            item.mediaUrl,
            AsyncWallpaper.HOME_SCREEN,
          );
          break;
        case 2:
          result = await AsyncWallpaper.setWallpaperFromUrl(
            item.mediaUrl,
            AsyncWallpaper.LOCK_SCREEN,
          );
          break;
        case 3:
          result = await AsyncWallpaper.setWallpaperFromUrl(
            item.mediaUrl,
            AsyncWallpaper.BOTH_SCREENS,
          );
          break;
      }

      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result ? '✅ Обои установлены!' : '❌ Ошибка установки'),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showFullscreen(ContentItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullscreenViewer(item: item),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Настройки',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Consumer<ContentProvider>(
              builder: (context, provider, _) => SwitchListTile(
                title: const Text('Показывать NSFW', style: TextStyle(color: Colors.white)),
                subtitle: const Text('18+ контент', style: TextStyle(color: Colors.grey)),
                value: provider.showNsfw,
                onChanged: (value) => provider.toggleNsfwFilter(),
                activeColor: Colors.orange,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.collections, color: Colors.orange),
              title: const Text('Сохранённые', style: TextStyle(color: Colors.white)),
              trailing: Chip(
                label: Text('${context.watch<ContentProvider>().savedItems.length}'),
                backgroundColor: Colors.orange,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Полноэкранный просмотр
class FullscreenViewer extends StatelessWidget {
  final ContentItem item;

  const FullscreenViewer({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Image.network(
                item.mediaUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Ce
