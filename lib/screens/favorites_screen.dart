import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../widgets/content_grid_widget.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().loadContent(onlySaved: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('❤️ Избранное'),
      ),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          final savedItems = provider.items.where((item) => item.isSaved).toList();

          if (savedItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Нет сохранённых артов', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Свайпните вверх на арте чтобы сохранить'),
                ],
              ),
            );
          }

          return ContentGridWidget(items: savedItems);
        },
      ),
    );
  }
}
