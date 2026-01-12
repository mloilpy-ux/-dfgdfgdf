import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/source_provider.dart';
import '../widgets/swipeable_card.dart';
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
      appBar: AppBar(
        title: const Text('Furry Hub'),
        actions: [
          PopupMenuButton<ContentType>(
            icon: const Icon(Icons.filter_alt),
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
          IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings),
        ],
      ),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.filteredItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.filteredItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, size: 100, color: Colors.green),
                  const SizedBox(height: 20),
                  const Text('Весь контент просмотрен!', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _currentIndex = 0);
                      provider.loadNewContent();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Обновить'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              for (int i = _currentIndex; i < _currentIndex + 2 && i < provider.filteredItems.length; i++)
                SwipeableCard(
                  key: ValueKey(provider.filteredItems[i].id),
                  item: provider.filteredItems[i],
                  index: i,
                  currentIndex: _currentIndex,
                  onSwipeLeft: () => _handleSwipe(provider, false),
                  onSwipeRight: () => _handleSwipe(provider, true),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  void _handleSwipe(ContentProvider provider, bool save) {
    if (_currentIndex >= provider.filteredItems.length) return;
    
    final item = provider.filteredItems[_currentIndex];

    if (save) {
      provider.saveItem(item);
    } else {
      provider.markAsSeen(item.id);
    }

    setState(() {
      _currentIndex++;
      if (_currentIndex >= provider.filteredItems.length - 3) {
        provider.loadNewContent();
      }
    });
  }

  Widget _buildBottomBar() {
    return Consumer<ContentProvider>(
      builder: (context, provider, _) {
        if (provider.filteredItems.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 40, color: Colors.red),
                onPressed: () => _handleSwipe(provider, false),
              ),
              IconButton(
                icon: const Icon(Icons.favorite, size: 40, color: Colors.pink),
                onPressed: () => _handleSwipe(provider, true),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Настройки', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Consumer<ContentProvider>(
              builder: (context, provider, _) => SwitchListTile(
                title: const Text('Показывать NSFW'),
                value: provider.showNsfw,
                onChanged: (value) => provider.toggleNsfwFilter(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.collections),
              title: const Text('Сохранённые'),
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

enum SwipeDirection { left, right }
