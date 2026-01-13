import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sources_provider.dart';
import '../models/content_source.dart';

class SourcesScreen extends StatefulWidget {
  const SourcesScreen({super.key});

  @override
  State<SourcesScreen> createState() => _SourcesScreenState();
}

class _SourcesScreenState extends State<SourcesScreen> {
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showAddSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('➕ Добавить источник'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Поддерживаемые типы:'),
            const SizedBox(height: 8),
            const Text('🔴 Reddit: https://reddit.com/r/furry'),
            const Text('🐦 Twitter: https://twitter.com/username'),
            const Text('✈️ Telegram: https://t.me/channelname'),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL источника',
                hintText: 'https://reddit.com/r/furry',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_urlController.text.isEmpty) return;

              try {
                await context.read<SourcesProvider>().addSource(_urlController.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Источник добавлен')),
                  );
                  _urlController.clear();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Ошибка: $e')),
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

  String _getSourceIcon(SourceType type) {
    switch (type) {
      case SourceType.reddit:
        return '🔴';
      case SourceType.twitter:
        return '🐦';
      case SourceType.telegram:
        return '✈️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('🌐 Источники'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.green),
            onPressed: _showAddSourceDialog,
            tooltip: 'Добавить источник',
          ),
        ],
      ),
      body: Consumer<SourcesProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.sources.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.source, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Нет источников', style: TextStyle(color: Colors.white, fontSize: 18)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddSourceDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить первый источник'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: provider.sources.length,
            itemBuilder: (context, index) {
              final source = provider.sources[index];
              return Card(
                color: source.isActive ? Colors.grey.shade800 : Colors.grey.shade900,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Text(_getSourceIcon(source.type), style: const TextStyle(fontSize: 24)),
                  title: Text(
                    source.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: source.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.url,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (source.lastParsed != null)
                        Text(
                          'Парсингов: ${source.parsedCount} | Последний: ${_formatDate(source.lastParsed!)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 11),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Переключатель активности
                      Switch(
                        value: source.isActive,
                        onChanged: (_) => provider.toggleSource(source),
                        activeColor: Colors.green,
                      ),
                      // Удалить
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Удалить источник?'),
                              content: Text('${source.name} будет удалён'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Отмена'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await provider.deleteSource(source.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSourceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Добавить источник'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    return '${diff.inDays} дн назад';
  }
}
