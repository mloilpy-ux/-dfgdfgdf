import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/content_grid_widget.dart';

class FeedTab extends StatefulWidget {
  const FeedTab({super.key});

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().loadContent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ContentProvider, SettingsProvider>(
      builder: (context, contentProvider, settings, _) {
        final items = settings.showNsfw
            ? contentProvider.items
            : contentProvider.items.where((item) => !item.isNsfw).toList();

        if (contentProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Контент не найден', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('Нажмите кнопку обновления'),
              ],
            ),
          );
        }

        return ContentGridWidget(items: items);
      },
    );
  }
}
