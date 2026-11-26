import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/content_source.dart';
import '../providers/content_provider.dart';
import '../providers/sources_provider.dart';
import '../services/browser_media.dart';
import '../theme.dart';

class BrowserSourceScreen extends StatefulWidget {
  const BrowserSourceScreen({super.key, required this.source});

  final ContentSource source;

  static Future<SourceImport> open(
    BuildContext context,
    ContentSource source,
  ) async {
    if (!context.mounted)
      return const SourceImport(message: 'Обновление отменено', failed: true);
    context.read<ContentProvider>().clearResult(source.id);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BrowserSourceScreen(source: source)),
    );
    if (!context.mounted)
      return const SourceImport(message: 'Обновление отменено', failed: true);
    return context.read<ContentProvider>().resultFor(source.id) ??
        const SourceImport(
          message: 'Страница закрыта без импорта',
          failed: true,
        );
  }

  @override
  State<BrowserSourceScreen> createState() => _BrowserSourceScreenState();
}

class _BrowserSourceScreenState extends State<BrowserSourceScreen> {
  final _controller = WebViewController();
  String? _script;
  String? _message;
  Uri? _page;
  int _progress = 0;
  bool _importing = false;
  Timer? _scanTimer;
  String? _lastBatch;
  int _generation = 0;

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final page = BrowserMedia.httpsUri(widget.source.url);
      if (page == null)
        throw const FormatException('Для страницы нужна HTTPS-ссылка');
      _script = await BrowserMedia.loadScript();
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      final platform = _controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setAllowFileAccess(false);
        await platform.setAllowContentAccess(false);
      }
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              BrowserMedia.httpsUri(request.url) != null
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _generation++;
              _lastBatch = null;
              _scanTimer?.cancel();
              _page = BrowserMedia.httpsUri(url);
              _progress = 0;
              _message = null;
            });
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() {
              _page = BrowserMedia.httpsUri(url);
              _progress = 100;
            });
            _scanTimer?.cancel();
            _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
              if (mounted && (ModalRoute.of(context)?.isCurrent ?? false))
                _import(automatic: true);
            });
            _import(automatic: true);
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(
                () => _message = 'Страница не загрузилась (${error.errorCode})',
              );
            }
          },
        ),
      );
      if (mounted) await _controller.loadRequest(page);
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted)
        setState(() => _message = 'Не удалось открыть встроенный браузер');
    }
  }

  Future<void> _import({bool automatic = false}) async {
    if (_importing || _script == null) return;
    final sources = context.read<SourcesProvider>();
    final content = context.read<ContentProvider>();
    final generation = _generation;
    setState(() => _importing = true);
    try {
      final page =
          BrowserMedia.httpsUri(await _controller.currentUrl()) ?? _page;
      if (page == null)
        throw const FormatException('Сначала откройте страницу');
      final response = await _controller.runJavaScriptReturningResult(_script!);
      if (!mounted || generation != _generation) return;
      final items = BrowserMedia.fromPage(response, widget.source, page);
      final batch = items.map((item) => item.id).join('|');
      if (automatic && items.isNotEmpty && batch == _lastBatch) return;
      final message = items.isEmpty
          ? (widget.source.type == SourceType.reddit
                ? 'Reddit не показал доступные ссылки на медиа. Откройте публикацию или переключите версию Reddit в меню.'
                : 'Здесь не найдено видимых медиа. Прокрутите страницу или откройте публикацию.')
          : (await content.importBrowserMedia(
              widget.source,
              sources,
              items,
            )).message;
      if (items.isEmpty && _lastBatch == null)
        content.reportBrowserFailure(widget.source.id, message);
      if (items.isNotEmpty) _lastBatch = batch;
      if (mounted) setState(() => _message = message);
    } on FormatException catch (error) {
      if (mounted) {
        content.reportBrowserFailure(widget.source.id, error.message);
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted) {
        content.reportBrowserFailure(
          widget.source.id,
          'Не удалось прочитать страницу',
        );
        setState(() => _message = 'Не удалось прочитать страницу');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openReddit(String action) async {
    final original = BrowserMedia.httpsUri(widget.source.url);
    if (original == null) return;
    try {
      if (action == 'external') {
        if (await launchUrl(original, mode: LaunchMode.externalApplication))
          return;
      } else if (original.host == 'reddit.com' ||
          original.host.endsWith('.reddit.com')) {
        await _controller.loadRequest(original.replace(host: action));
        return;
      } else {
        await _controller.loadRequest(original);
        return;
      }
    } catch (_) {
      // A browser may be unavailable on the device.
    }
    if (mounted) setState(() => _message = 'Не удалось открыть Reddit');
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: wallpaperTheme,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _page?.host ?? widget.source.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (widget.source.type == SourceType.reddit)
            PopupMenuButton<String>(
              tooltip: 'Варианты просмотра Reddit',
              onSelected: _openReddit,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'www.reddit.com',
                  child: Text('Новый Reddit'),
                ),
                PopupMenuItem(
                  value: 'old.reddit.com',
                  child: Text('Старый Reddit'),
                ),
                PopupMenuItem(
                  value: 'external',
                  child: Text('Открыть в обычном браузере'),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Назад по странице',
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () async {
              if (await _controller.canGoBack()) await _controller.goBack();
            },
          ),
          IconButton(
            tooltip: 'Перезагрузить страницу',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _controller.reload,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100 && _message == null)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress / 100 : null,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Медиа сохраняются автоматически. Прокрутите страницу для загрузки следующих публикаций.',
              textAlign: TextAlign.center,
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_message!, textAlign: TextAlign.center),
              ),
            FilledButton.icon(
              onPressed: !_importing && _progress >= 55 ? _import : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _importing ? 'Импортируем…' : 'Проверить медиа сейчас',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
