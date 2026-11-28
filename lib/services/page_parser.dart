import 'dart:convert';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import '../models/content_item.dart';
import '../models/content_source.dart';
import 'browser_media.dart';
import 'source_response.dart';

class PageBatch {
  const PageBatch(this.items, this.next);
  final List<ContentItem> items;
  final Uri? next;
}

/// Reads public HTML only. A login/challenge is a failure, never an empty success.
class PageParser {
  static Future<PageBatch> fetch(
    http.Client client,
    ContentSource source, {
    Uri? page,
  }) async {
    final uri = page ?? Uri.parse(source.url);
    final response = await fetchSource(
      client,
      uri,
      service: source.type.name,
      headers: const {'Accept': 'text/html'},
    );
    return parse(
      utf8.decode(response.bodyBytes, allowMalformed: true),
      source,
      uri,
    );
  }

  static PageBatch parse(String body, ContentSource source, Uri page) {
    final doc = html.parse(body);
    final text = doc.body?.text.toLowerCase() ?? '';
    if (doc.querySelector('input[name="js_challenge"]') != null ||
        text.contains('blocked by network security') ||
        text.contains('access is denied') ||
        text.contains('verify you are human')) {
      throw const SourceFailure(
        'Сайт ограничил доступ: требуется проверка в браузере',
      );
    }
    final media = <Map<String, dynamic>>[];
    final title = doc.querySelector('title')?.text ?? source.name;
    void add(String? raw, {String? kind, String? label, bool adult = false}) {
      final url = mediaUri(raw, page);
      if (url == null || url.scheme != 'https') return;
      final type = MediaKind.fromUrl(url.toString())?.name ?? kind;
      if (type == null) return;
      media.add({
        'url': url.toString(),
        'kind': type,
        'title': label ?? title,
        'adult':
            adult ||
            RegExp(
              r'\b(nsfw|over18|yiff|hentai)\b|18\+',
              caseSensitive: false,
            ).hasMatch(label ?? title),
        'post': page.toString(),
      });
    }

    for (final post in doc.querySelectorAll('shreddit-post, div.thing')) {
      add(
        post.attributes['content-href'] ?? post.attributes['data-url'],
        label:
            post.attributes['post-title'] ??
            post.querySelector('a.title')?.text,
        adult:
            post.attributes['nsfw'] == 'true' ||
            post.classes.contains('over18'),
      );
    }
    for (final node in doc.querySelectorAll(
      'meta[property="og:image"],meta[property="og:video"],meta[name="twitter:image"]',
    )) {
      add(
        node.attributes['content'],
        kind: (node.attributes['property'] ?? '').contains('video')
            ? 'video'
            : 'image',
      );
    }
    for (final node in doc.querySelectorAll(
      'main img, article img, img[data-src], video, video source, a[href]',
    )) {
      if (node.localName == 'a') {
        add(node.attributes['href']);
        continue;
      }
      final w = int.tryParse(node.attributes['width'] ?? '');
      final h = int.tryParse(node.attributes['height'] ?? '');
      if ((w != null && w < 100) || (h != null && h < 100)) continue;
      add(
        node.attributes['data-src'] ?? node.attributes['src'],
        kind: node.localName == 'img' ? 'image' : 'video',
        label: node.attributes['alt'],
      );
    }
    final items = BrowserMedia.fromPage(
      jsonEncode({'page': page.toString(), 'items': media}),
      source,
      page,
    );
    if (items.isEmpty) {
      throw SourceFailure(
        doc.querySelector('input[type="password"]') != null
            ? 'Сайт требует вход: откройте источник в браузере'
            : 'HTML не содержит медиа. Возможно, нужен JavaScript: откройте источник в браузере',
      );
    }
    final candidate = mediaUri(
      doc.querySelector('a[rel="next"]')?.attributes['href'] ??
          doc.querySelector('link[rel="next"]')?.attributes['href'],
      page,
    );
    final next =
        candidate != null &&
            candidate.scheme == 'https' &&
            candidate.host == page.host &&
            candidate != page
        ? candidate
        : null;
    return PageBatch(items, next);
  }
}
