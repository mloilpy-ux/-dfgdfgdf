import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sources_provider.dart';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/logger_provider.dart';
import 'feed_tab.dart';
import 'gifs_tab.dart';
import 'sources_tab.dart';
import 'favorites_tab.dart';
import 'logs_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const FeedTab(),
    const GifsTab(),
    const SourcesTab(),
    const FavoritesTab(),
    const LogsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐾 Furry Content Hub'),
        actions: [
          Consumer<SettingsProvider>(
            builder: (context, settings, _) => IconButton(
              icon: Icon(
                settings.showNsfw ? Icons.visibility : Icons.visibility_off,
                color: settings.showNsfw ? Colors.red : Colors.grey,
              ),
              onPressed: settings.toggleNsfw,
              tooltip: settings.showNsfw ? 'NSFW включен' : 'NSFW выключен',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final sourcesProvider = context.read<SourcesProvider>();
              final contentProvider = context.read<ContentProvider>();
              await contentProvider.parseAllActiveSources(sourcesProvider);
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Лента',
          ),
          NavigationDestination(
            icon: Icon(Icons.gif_box),
            label: 'GIF',
          ),
          NavigationDestination(
            icon: Icon(Icons.source),
            label: 'Источники',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite),
            label: 'Избранное',
          ),
          NavigationDestination(
            icon: Icon(Icons.list),
            label: 'Логи',
          ),
        ],
      ),
    );
  }
}
