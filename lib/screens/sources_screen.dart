import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/content_source.dart';
import '../providers/content_provider.dart';
import '../providers/sources_provider.dart';

class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  void _message(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<String?> _input(
    BuildContext context, {
    required String title,
    required String label,
    String? hint,
    bool secret = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _SourceInput(title: title, label: label, hint: hint, secret: secret),
    );
  }

  Future<void> _addSource(
    BuildContext context,
    SourcesProvider sources,
    ContentProvider content,
  ) async {
    final url = await _input(
      context,
      title: 'Добавить источник',
      label: 'Ссылка',
      hint:
          't.me/канал, reddit.com/r/сообщество, x.com/профиль или HTTPS-ссылка на медиафайл',
    );
    if (url == null || !context.mounted) return;
    try {
      final source = await sources.addSource(url);
      if (source.isActive && context.mounted)
        await _parse(context, source, sources, content);
      if (!source.isActive)
        _message(context, 'Источник уже добавлен и выключен');
    } on FormatException catch (error) {
      _message(context, error.message);
    } catch (_) {
      _message(context, 'Не удалось сохранить источник');
    }
  }

  Future<void> _parse(
    BuildContext context,
    ContentSource source,
    SourcesProvider sources,
    ContentProvider content,
  ) async {
    if (source.type.requiresToken && sources.tokenFor(source.type) == null) {
      _message(
        context,
        'Источник сохранён. Подключите API ${source.type.displayName} для загрузки',
      );
      return;
    }
    final result = await content.importSource(source, sources);
    _message(context, '${source.name}: ${result.message}');
  }

  Future<void> _connect(
    BuildContext context,
    ContentSource source,
    SourcesProvider sources,
    ContentProvider content,
  ) async {
    final token = await _input(
      context,
      title: 'Подключить API ${source.type.displayName}',
      label: 'Токен доступа',
      hint: 'Действует до закрытия приложения',
      secret: true,
    );
    if (token == null || !context.mounted) return;
    sources.setToken(source.type, token);
    if (source.isActive) await _parse(context, source, sources, content);
  }

  Future<void> _toggle(
    BuildContext context,
    ContentSource source,
    SourcesProvider sources,
    ContentProvider content,
  ) async {
    try {
      await sources.toggleSource(source);
      await content.sourceChanged(sources.activeSources);
      final enabled = sources.activeSources
          .where((item) => item.id == source.id)
          .firstOrNull;
      if (context.mounted && enabled != null)
        await _parse(context, enabled, sources, content);
    } catch (_) {
      _message(context, 'Не удалось изменить источник');
    }
  }

  Future<void> _delete(
    BuildContext context,
    ContentSource source,
    SourcesProvider sources,
    ContentProvider content,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить источник?'),
        content: Text(
          '${source.name} и загруженные из него материалы будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await sources.deleteSource(source.id);
      await content.sourceChanged(sources.activeSources);
    } catch (_) {
      _message(context, 'Не удалось удалить источник');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = context.watch<SourcesProvider>();
    final content = context.watch<ContentProvider>();
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Источники'),
        actions: [
          IconButton(
            tooltip: 'Обновить все источники',
            icon: const Icon(Icons.refresh),
            onPressed: content.isLoading || sources.activeSources.isEmpty
                ? null
                : () async {
                    final report = await content.parseAllActiveSources(sources);
                    final ok = report.values
                        .where((result) => !result.failed)
                        .length;
                    _message(
                      context,
                      'Обновлено источников: $ok из ${report.length}',
                    );
                  },
          ),
        ],
      ),
      body: sources.isLoading && sources.sources.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : sources.loadError != null
          ? Center(
              child: TextButton(
                onPressed: sources.loadSources,
                child: Text('${sources.loadError}. Повторить'),
              ),
            )
          : sources.sources.isEmpty
          ? const Center(
              child: Text(
                'Нет источников',
                style: TextStyle(color: Colors.white),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
              itemCount: sources.sources.length,
              itemBuilder: (context, index) {
                final source = sources.sources[index];
                final importing = content.isImporting(source.id);
                final result = content.resultFor(source.id);
                final needsToken =
                    source.type.requiresToken &&
                    sources.tokenFor(source.type) == null;
                final status = importing
                    ? 'Загрузка…'
                    : !source.isActive
                    ? 'Выключен'
                    : result?.message ??
                          (needsToken
                              ? 'Требуется токен API ${source.type.displayName}'
                              : 'Обновлений: ${source.parsedCount}');
                return Card(
                  color: source.isActive
                      ? Colors.grey.shade800
                      : Colors.grey.shade900,
                  child: ListTile(
                    leading: Text(
                      source.type.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      source.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.url,
                          style: const TextStyle(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          status,
                          style: TextStyle(
                            color: result?.failed == true
                                ? Colors.orange.shade200
                                : Colors.white70,
                          ),
                        ),
                        if (importing) const LinearProgressIndicator(),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: source.isActive,
                          onChanged: (_) =>
                              _toggle(context, source, sources, content),
                        ),
                        PopupMenuButton<String>(
                          iconColor: Colors.white,
                          tooltip: 'Действия источника',
                          onSelected: (action) => switch (action) {
                            'parse' => _parse(
                              context,
                              source,
                              sources,
                              content,
                            ),
                            'token' => _connect(
                              context,
                              source,
                              sources,
                              content,
                            ),
                            _ => _delete(context, source, sources, content),
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'parse',
                              enabled:
                                  source.isActive && !importing && !needsToken,
                              child: const Text('Обновить источник'),
                            ),
                            if (source.type.requiresToken)
                              PopupMenuItem(
                                value: 'token',
                                child: Text(
                                  'Подключить API ${source.type.displayName}',
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSource(context, sources, content),
        icon: const Icon(Icons.add),
        label: const Text('Добавить источник'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }
}

class _SourceInput extends StatefulWidget {
  const _SourceInput({
    required this.title,
    required this.label,
    required this.hint,
    required this.secret,
  });
  final String title;
  final String label;
  final String? hint;
  final bool secret;

  @override
  State<_SourceInput> createState() => _SourceInputState();
}

class _SourceInputState extends State<_SourceInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: widget.secret,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: widget.secret
          ? TextInputType.visiblePassword
          : TextInputType.url,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.hint,
        helperMaxLines: 3,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: _submit,
        child: Text(widget.secret ? 'Подключить' : 'Добавить'),
      ),
    ],
  );
}
