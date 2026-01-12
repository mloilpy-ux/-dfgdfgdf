import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/source_provider.dart';
import '../widgets/content_grid.dart';
import 'sources_screen.dart';
import 'logs_screen.dart';
import 'saved_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialContent();
  }

  Future<void> _loadInitialContent() async {
    final sourceProvider = context.read<SourceProvider>();
    await sourceProvider.loadSources();
    
    final contentProvider = context.read<ContentProvider>();
    await contentProvider.loadContent(sourceProvider.sources);
  }

  @override
  Widget build(BuildContext context) {
    final contentProvider = context.watch<ContentProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🐾'),
            SizedBox(width: 8),
            Text('Furry Content Hub'),
          ],
        ),
        actions: [
          // NSFW Toggle
          IconButton(
            icon: Icon(contentProvider.showNsfw ? Icons.visibility_off : Icons.visibility),
            onPressed: contentProvider.toggleNsfwFilter,
            tooltip: contentProvider.showNsfw ? 'Скрыть NSFW' : 'Показать NSFW',
          ),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final sources = context.read<SourceProvider>().sources;
              await contentProvider.loadContent(sources);
            },
          ),
          // Logs
          IconButton(
            icon: const Icon(Icons.assignment),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          ContentGrid(showOnlyGifs: false),
          ContentGrid(showOnlyGifs: true),
          SavedScreen(),
          SourcesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: 'Лента',
          ),
          NavigationDestination(
            icon: Icon(Icons.gif_box),
            label: 'GIF',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite),
            label: 'Сохранённое',
          ),
          NavigationDestination(
            icon: Icon(Icons.source),
            label: 'Источники',
          ),
        ],
      ),
      floatingActionButton: contentProvider.isLoading
          ? const CircularProgressIndicator()
          : null,
    );
  }
}
