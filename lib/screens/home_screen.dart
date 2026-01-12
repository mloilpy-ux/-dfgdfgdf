import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../widgets/swipeable_card.dart';

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
    // Загружаем контент при старте
    Future.microtask(() {
      context.read<ContentProvider>().loadNewContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Furry Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilters(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Навигация к настройкам
            },
          ),
        ],
      ),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.unseenItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.unseenItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 100, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text(
                    'Весь контент просмотрен!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text('Подгружаем новые арты...'),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () => provider.loadNewContent(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Обновить'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // Показываем только текущую и следующую карточку для плавности
              for (int i = _currentIndex; i < _currentIndex + 2 && i < provider.unseenItems.length; i++)
                SwipeableCard(
                  key: ValueKey(provider.unseenItems[i].id),
                  item: provider.unseenItems[i],
                  index: i,
                  currentIndex: _currentIndex,
                  onSwipeLeft: () => _handleSwipe(provider, SwipeDirection.left),
                  onSwipeRight: () => _handleSwipe(provider, SwipeDirection.right),
                  onSwipeUp: () => _handleSwipe(provider, SwipeDirection.up),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  void _handleSwipe(ContentProvider provider, SwipeDirection direction) {
    final item = provider.unseenItems[_currentIndex];

    switch (direction) {
      case SwipeDirection.left:
        // Пропустить - просто отмечаем как показанный
        provider.markAsSeen(item.id);
        break;
      case SwipeDirection.right:
        // Лайк - сохраняем
        provider.saveItem(item);
        break;
      case SwipeDirection.up:
        // Открыть полностью
        _openFullScreen(item);
        return; // Не двигаем индекс
    }

    setState(() {
      _currentIndex++;
      // Подгружаем новый контент, если осталось мало
      if (_currentIndex >= provider.unseenItems.length - 3) {
        provider.loadNewContent();
      }
    });
  }

  void _openFullScreen(item) {
    // TODO: Открыть полноэкранный просмотр
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            Center(
              child: Image.network(item.mediaUrl),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final provider = context.watch<ContentProvider>();
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Пропустить
          IconButton(
            icon: const Icon(Icons.close, size: 35, color: Colors.red),
            onPressed: () => _handleSwipe(provider, SwipeDirection.left),
          ),
          // Информация
          IconButton(
            icon: const Icon(Icons.info_outline, size: 30, color: Colors.blue),
            onPressed: () {
              if (provider.unseenItems.isNotEmpty) {
                _showInfo(provider.unseenItems[_currentIndex]);
              }
            },
          ),
          // Лайк
          IconButton(
            icon: const Icon(Icons.favorite, size: 35, color: Colors.pink),
            onPressed: () => _handleSwipe(provider, SwipeDirection.right),
          ),
        ],
      ),
    );
  }

  void _showInfo(item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Автор: ${item.author ?? "Unknown"}'),
            Text('Источник: ${item.postUrl ?? "N/A"}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Открыть в браузере
              },
              child: const Text('Открыть источник'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Фильтры', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Показывать NSFW'),
              value: context.watch<ContentProvider>().showNsfw,
              onChanged: (value) {
                context.read<ContentProvider>().toggleNsfwFilter();
              },
            ),
            SwitchListTile(
              title: const Text('Только GIF'),
              value: context.watch<ContentProvider>().onlyGifs,
              onChanged: (value) {
                context.read<ContentProvider>().toggleGifFilter();
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum SwipeDirection { left, right, up }
