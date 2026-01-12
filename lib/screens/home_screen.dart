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

    if (location != null && mounted) {
      _applyWallpaper(item, location);
    }
  }

  Widget _buildWallpaperOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int location,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: () => Navigator.pop(context, location),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      hoverColor: Colors.orange.withOpacity(0.1),
    );
  }

  Future<void> _applyWallpaper(ContentItem item, int location) async {
    // Показываем загрузку
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 20),
              Text(
                'Устанавливаем обои...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
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

      if (mounted) {
        Navigator.pop(context); // Закрываем диалог загрузки
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text(
                  result ? 'Обои установлены!' : 'Ошибка установки обоев',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: result ? Colors.green[700] : Colors.red[700],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Закрываем диалог загрузки
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ошибка: ${e.toString()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Настройки',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // NSFW фильтр
            Consumer<ContentProvider>(
              builder: (context, provider, _) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Показывать NSFW',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    '18+ контент',
                    style: TextStyle(color: Colors.grey),
                  ),
                  value: provider.showNsfw,
                  onChanged: (value) => provider.toggleNsfwFilter(),
                  activeColor: Colors.orange,
                  secondary: const Icon(Icons.explicit, color: Colors.orange),
                ),
              ),
            ),
            
            const SizedBox(height: 15),
            
            // Сохранённые
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: const Icon(Icons.collections, color: Colors.orange, size: 28),
                title: const Text(
                  'Сохранённые',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                trailing: Consumer<ContentProvider>(
                  builder: (context, provider, _) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${provider.savedItems.length}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SavedScreen()),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
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
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                item.mediaUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          loadingProgress.expectedTotalBytes != null
                              ? '${(loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).toInt()}%'
                              : 'Загрузка...',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 60, color: Colors.red),
                        SizedBox(height: 20),
                        Text(
                          'Ошибка загрузки изображения',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Кнопка закрытия
          Positioned(
            top: 40,
            left: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // Информация о картинке
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
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
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.author != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.orange, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            item.author!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
