import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/content_provider.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({Key? key}) : super(key: key);

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ContentProvider>().loadSavedItems());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сохранённые')),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          if (provider.savedItems.isEmpty) {
            return const Center(child: Text('Нет сохранённых артов'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: provider.savedItems.length,
            itemBuilder: (context, index) {
              final item = provider.savedItems[index];
              return CachedNetworkImage(
                imageUrl: item.thumbnailUrl ?? item.mediaUrl,
                fit: BoxFit.cover,
              );
            },
          );
        },
      ),
    );
  }
}
