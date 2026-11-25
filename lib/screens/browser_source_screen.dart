import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  State<BrowserSourceScreen> createState() => _BrowserSourceScreenState();
}

class _BrowserSourceScreenState extends State<BrowserSourceScreen> {
  final _controller = WebViewController();
  String? _script;
  String? _message;
  String? _address;
  int _progress = 0;
  bool _importing = false;

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
              _address = BrowserMedia.httpsUri(url)?.host;
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
              _address = BrowserMedia.httpsUri(url)?.host;
              _progress = 100;
            });
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

  Future<void> _import() async {
    if (_importing || _script == null) return;
    final sources = context.read<SourcesProvider>();
    final content = context.read<ContentProvider>();
    setState(() => _importing = true);
    try {
      final page = BrowserMedia.httpsUri(await _controller.currentUrl());
      if (page == null)
        throw const FormatException('Сначала откройте страницу');
      final response = await _controller.runJavaScriptReturningResult(_script!);
      final items = BrowserMedia.fromPage(response, widget.source, page);
      final message = items.isEmpty
          ? 'Здесь не найдено видимых медиа. Прокрутите страницу или откройте публикацию.'
          : (await content.importBrowserMedia(
              widget.source,
              sources,
              items,
            )).message;
      if (mounted) setState(() => _message = message);
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) setState(() => _message = 'Не удалось прочитать страницу');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: wallpaperTheme,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _address ?? widget.source.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
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
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_message!, textAlign: TextAlign.center),
              ),
            FilledButton.icon(
              onPressed: !_importing && _progress >= 55 ? _import : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_importing ? 'Импортируем…' : 'Импортировать медиа'),
            ),
          ],
        ),
      ),
    ),
  );
}
