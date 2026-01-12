import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/source_provider.dart';
import '../models/content_source.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SourceProvider>();

    return Scaffold(
      body: ListView.builder(
        itemCount: provider.sources.length,
        itemBuilder: (context, index) {
          final source = provider.sources[index];
          return ListTile(
            leading: Icon(_getIconForType(source.type)),
            title: Text(source.name),
            subtitle: Text(source.url),
            trailing: Switch(
              value: source.isActive,
              onChanged: (_) => provider.toggleSource(source.id),
            ),
            onLongPress: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Удалить источник?'),
                  content: Text(source.name),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.deleteSource(source.id);
                        Navigator.pop(context);
                      },
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSourceDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getIconForType(SourceType type) {
    switch (type) {
      case SourceType.reddit:
        return Icons.reddit;
      case SourceType.twitter:
        return Icons.tag;
      case SourceType.telegram:
        return Icons.send;
    }
  }

  void _showAddSourceDialog(BuildContext context) {
    final urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить источник'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            labelText: 'URL (например, r/furry_irl)',
            hintText: 'https://reddit.com/r/...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              final url = urlController.text;
              if (url.isNotEmpty) {
                final source = ContentSource(
                  id: const Uuid().v4(),
                  name: _extractName(url),
                  url: url,
                  type: _detectType(url),
                );
                context.read<SourceProvider>().addSource(source);
                Navigator.pop(context);
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  String _extractName(String url) {
    if (url.contains('reddit.com/r/')) {
      final match = RegExp(r'/r/([^/]+)').firstMatch(url);
      return 'r/${match?.group(1) ?? 'unknown'}';
    }
    return url;
  }

  SourceType _detectType(String url) {
    if (url.contains('reddit.com')) return SourceType.reddit;
    if (url.contains('twitter.com') || url.contains('x.com')) return SourceType.twitter;
    if (url.contains('t.me')) return SourceType.telegram;
    return SourceType.reddit;
  }
}
