import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:async_wallpaper/async_wallpaper.dart';
import 'package:permission_handler/permission_handler.dart';
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
        title: const Text('Furry Hub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          // Фильтр типа контента
          PopupMenuButton<ContentType>(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onSelected: (type) {
              setState(() => _currentIndex = 0);
              context.read<ContentProvider>().setContentType(type);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ContentType.all,
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive),
                    SizedBox(width: 10),
                    Text('Всё'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ContentType.images,
                child: Row(
                  children: [
                    Icon(Icons.image),
                    SizedBox(width: 10),
                    Text('Картинки'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ContentType.gifs,
                child: Row(
                  children: [
                    Icon(Icons.gif_box),
                    SizedBox(width: 10),
                    Text('GIF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ContentType.videos,
                child: Row(
                  children: [
                    Icon(Icons.video_library),
                    SizedBox(width: 10),
                    Text('Видео'),
                  ],
                ),
              ),
            ],
          ),
          // Настройки
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          // Загрузка
          if (provider.isLoading && provider.filteredItems.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.orange),
            );
          }

          // Пустое состояние
          if (provider.filteredItems.isEmpty) {
            return _buildEmptyState(provider);
          }

          // Проверка индекса
          if (_currentIndex >= provider.filteredItems.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _currentIndex = 0);
              }
            });
            return const SizedBox.shrink();
          }

          final item = provider.filteredItems[_currentIndex];

          return Column(
            children: [
              // Индикатор прогресса
              _buildProgressIndicator(provider),
              
              // Основная картинка
              Expanded(
                child: ContentCard(
                  key: ValueKey(item.id),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: current / total,
                backgroundColor: Colors.grey[800],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$current / $total',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ContentProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 80,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Весь контент просмотрен!',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Подгружаем новые арты...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _currentIndex = 0);
                provider.loadNewContent();
              },
              icon: const Icon(Icons.refresh, size: 24),
              label: const Text(
                'Обновить контент',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons(ContentProvider provider, ContentItem item) {
    final isVideo = item.mediaUrl.contains('.mp4') || item.mediaUrl.contains('.webm');
    final showWallpaperButton = !item.isGif && !isVideo;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Кнопка: ДАЛЕЕ (пропустить)
            Expanded(
              child: _buildButton(
                icon: Icons.skip_next,
                label: 'Далее',
                color: Colors.grey[700]!,
                onPressed: () => _nextImage(provider, false),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Кнопка: УСТАНОВИТЬ ОБОИ (только для картинок)
            if (showWallpaperButton) ...[
              Expanded(
                child: _buildButton(
                  icon: Icons.wallpaper,
                  label: 'Обои',
                  color: Colors.blue[700]!,
                  onPressed: () => _setWallpaper(item),
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            // Кнопка: СОХРАНИТЬ
            Expanded(
              child: _buildButton(
                icon: Icons.favorite,
                label: 'Сохранить',
                color: Colors.pink[700]!,
                onPressed: () => _nextImage(provider, true),
              ),
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
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: Colors.white),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextImage(ContentProvider provider, bool save) {
    if (_currentIndex >= provider.filteredItems.length) return;
    
    final item = provider.filteredItems[_currentIndex];

    if (save) {
      provider.saveItem(item);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Сохранено!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Future<void> _setWallpaper(ContentItem item) async {
    // Проверяем разрешения
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Требуется разрешение на доступ к хранилищу'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Показываем диалог выбора
    final location = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Установить обои',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildWallpaperOption(
              context: context,
              icon: Icons.home,
              title: 'Главный экран',
              location: 1,
            ),
            const Divider(color: Colors.grey),
            _buildWallpaperOption(
              context: context,
              icon: Icons.lock,
              title: 'Экран блокировки',
              location: 2,
            ),
            const Divider(color: Colors.grey),
            _buildWallpaperOption(
              context: context,
              icon: Icons.phone_android,
              title: 'Оба экрана',
              location: 3,
            ),
          ],
        ),
      ),
    );

    if (location != null && mounted)
