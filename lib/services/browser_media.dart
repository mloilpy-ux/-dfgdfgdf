import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../models/content_item.dart';
import '../models/content_source.dart';
import 'media_quality.dart';

class BrowserMedia {
  static Future<String> loadScript() =>
      rootBundle.loadString('assets/web_media.js');

  static Uri? httpsUri(Object? value) {
    if (value is! String || value.length > 4096) return null;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty)
      return null;
    return uri;
  }

  static List<ContentItem> fromPage(
    Object raw,
    ContentSource source,
    Uri page,
  ) {
    if (raw is! String || raw.length > 1000000) {
      throw const FormatException('Некорректный ответ страницы');
    }
    final decoded = jsonDecode(raw);
    final data = decoded is String ? jsonDecode(decoded) : decoded;
    if (data is! Map ||
        data['items'] is! List ||
        httpsUri(data['page'])?.removeFragment() != page.removeFragment()) {
      throw const FormatException('Страница изменилась. Повторите импорт');
    }

    switch (data['issue']) {
      case 'challenge':
        throw const FormatException(
          'Reddit показывает проверку браузера. Дождитесь открытия ленты и повторите импорт.',
        );
      case 'login':
        throw const FormatException(
          'Reddit открыл страницу входа. Сначала откройте публикацию.',
        );
      case 'blocked':
        throw const FormatException(
          'Reddit ограничил доступ к странице. Можно проверить эту ссылку в обычном браузере.',
        );
    }

    final items = <String, ContentItem>{};
    for (final candidate in (data['items'] as List).take(60)) {
      if (candidate is! Map) continue;
      final url = httpsUri(candidate['url'])?.removeFragment();
      final kind = MediaKind.values
          .where((kind) => kind.name == candidate['kind'])
          .firstOrNull;
      if (url == null || kind == null) continue;
      final key = _mediaKey(url);
      final previous = items[key];
      if (previous != null && preferredMediaUrl(previous.mediaUrl, url.toString()) != url.toString()) continue;
      final id = sha256.convert(utf8.encode('${source.id}\u0000$key'));
      final title = candidate['title'];
      final post = httpsUri(candidate['post']) ?? page;
      items[key] = ContentItem(
        id: 'web_$id',
        sourceId: source.id,
        title: title is String && title.trim().isNotEmpty
            ? title.trim().substring(0, title.trim().length.clamp(0, 180))
            : source.name,
        mediaUrl: url.toString(),
        kind: kind,
        thumbnailUrl: httpsUri(candidate['thumbnail'])?.toString(),
        isNsfw: source.isNsfw || candidate['adult'] == true,
        createdAt: DateTime.now(),
        postUrl: post.toString(),
      );
    }
    return items.values.toList();
  }

  static String _mediaKey(Uri url) {
    if (url.host == 'pbs.twimg.com' && url.path.startsWith('/media/'))
      return url.origin + url.path;
    if (url.host == 'preview.redd.it' || url.host == 'i.redd.it')
      return url.path;
    if (url.host == 'i.pinimg.com')
      return url.host + url.path.replaceFirst(RegExp(r'^/\d+x(?:\d+)?/'), '/');
    return url.toString();
  }
}
