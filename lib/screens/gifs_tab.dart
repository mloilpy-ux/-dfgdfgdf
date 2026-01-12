import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/content_grid_widget.dart';

class GifsTab extends StatefulWidget {
  const GifsTab({super.key});

  @override
  State<GifsTab> createState() => _GifsTabState();
}

class _GifsTabState extends State<GifsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContentProvider>().loadContent(onlyGifs: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ContentProvider, SettingsProvider>(
      builder: (context, contentProvider, settings, _) {
        final items = settings.showNsfw
            ? contentProvider.items.where((item) => item.isGif).toList()
            : contentProvider.items.where((item) => item.isGif && !item.isNsfw).toList();

        if (items.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.gif_box_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('GIF не найдены'),
              ],
            ),
          );
        }

        return ContentGridWidget(items: items);
      },
    );
  }
}
