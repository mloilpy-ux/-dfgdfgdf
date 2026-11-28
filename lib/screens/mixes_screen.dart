import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/content_provider.dart';
import '../providers/settings_provider.dart';
import 'media_viewer.dart';

class MixesScreen extends StatefulWidget {
  const MixesScreen({super.key});
  @override
  State<MixesScreen> createState() => _MixesScreenState();
}

class _MixesScreenState extends State<MixesScreen> {
  String mix = 'Сюрприз';
  int seed = DateTime.now().millisecondsSinceEpoch;
  final controller = PageController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final adult = context.watch<SettingsProvider>().showNsfw;
    final patterns = {
      'Ночь': 'night|dark|moon|ноч|тём',
      'Неон': 'neon|cyber|неон|кибер',
      'Уют': 'cozy|soft|sleep|уют|мяг|сон',
    };
    final items =
        content.items
            .where(
              (i) =>
                  (adult || !i.isNsfw) &&
                  (mix != 'Избранное' || i.isSaved) &&
                  (!patterns.containsKey(mix) ||
                      RegExp(
                        patterns[mix]!,
                        caseSensitive: false,
                      ).hasMatch(i.title)),
            )
            .toList()
          ..shuffle(Random(seed));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Миксы'),
        actions: [
          IconButton(
            tooltip: 'Перемешать',
            icon: const Icon(Icons.shuffle),
            onPressed: () => setState(() => seed++),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Сюрприз', 'Избранное', ...patterns.keys]
                  .map(
                    (name) => Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: mix == name,
                        onSelected: (_) {
                          setState(() => mix = name);
                          if (controller.hasClients) controller.jumpToPage(0);
                        },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Подборки из коллекции · темы по названиям · свайп вверх',
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text('Для этого микса пока нет материалов'),
                  )
                : PageView.builder(
                    controller: controller,
                    scrollDirection: Axis.vertical,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return GestureDetector(
                        onDoubleTap: () => content.toggleSave(item),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MediaViewer(item: item),
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: item.usesVideoPlayer
                                  ? Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        size: 80,
                                      ),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: item.mediaUrl,
                                      httpHeaders: item.mediaHeaders,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                            ListTile(
                              title: Text(item.title, maxLines: 2),
                              subtitle: Text(
                                '${item.kind.name} · ${index + 1}/${items.length}',
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  item.isSaved
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                                onPressed: () => content.toggleSave(item),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
