import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sources_provider.dart';
import '../models/content_source.dart';

class SourcesTab extends StatelessWidget {
  const SourcesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SourcesProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () => _showAddSourceDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Добавить источник'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: provider.sources.length,
                itemBuilder: (context, index) {
                  final source = provider.sources[index];
                  return _SourceCard(source: source);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddSourceDialog(BuildContext context) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить источник'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://www.reddit.com/r/furry/',
            labelText: 'URL источника',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await context.read<SourcesProvider>().addSource(controller.text);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e')),
                  );
                }
              }
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final ContentSource source;

  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getSourceIcon(source.type),
        title: Text(source.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (source.lastParsed != null)
              Text(
                'Последний парсинг: ${_formatDateTime(source.lastParsed!)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: source.isActive,
              onChanged: (_) => context.read<SourcesProvider>().toggleSource(source),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, source.id),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getSourceIcon(SourceType type) {
    switch (type) {
      case SourceType.reddit:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.reddit, color: Colors.white),
        );
      case SourceType.twitter:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.flutter_dash, color: Colors.white),
        );
      case SourceType.telegram:
        return const CircleAvatar(
          backgroundColor: Colors.cyan,
          child: Icon(Icons.send, color: Colors.white),
        );
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute}';
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить источник?'),
        content: const Text('Весь контент из этого источника будет удален'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              context.read<SourcesProvider>().deleteSource(id);
              Navigator.pop(context);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
