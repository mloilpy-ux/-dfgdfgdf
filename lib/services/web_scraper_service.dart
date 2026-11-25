import 'dart:convert';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import '../models/content_item.dart';
import '../models/content_source.dart';
import 'source_response.dart';

class WebScraperService {
  final http.Client _client;

  WebScraperService(this._client);

  Future<List<ContentItem>> parseTelegram(ContentSource source) async {
    final channel = Uri.parse(
      ContentSource.fromUrl(source.url).url,
    ).pathSegments.first;
    final page = Uri.https('t.me', '/s/$channel');
    final response = await fetchSource(
      _client,
      page,
      service: 'Telegram',
      headers: {'Accept': 'text/html'},
    );
    final document = html.parse(utf8.decode(response.bodyBytes));
    if (document.querySelector(
          '.tgme_channel_history, .tgme_widget_message[data-post]',
        ) ==
        null) {
      throw const SourceFailure('Telegram не показал публичную ленту канала');
    }

    final items = <ContentItem>[];
    for (final message in document.querySelectorAll(
      '.tgme_widget_message[data-post]',
    )) {
      final post = message.attributes['data-post']!;
      final title = message
          .querySelector('.tgme_widget_message_text')
          ?.text
          .trim();
      final date = message.querySelector('time')?.attributes['datetime'];
      final postUrl =
          mediaUri(
            message
                .querySelector('.tgme_widget_message_date')
                ?.attributes['href'],
            page,
          ) ??
          Uri.https('t.me', '/$post');
      final seen = <Uri>{};
      var index = 0;
      for (final node in message.querySelectorAll(
        '.tgme_widget_message_photo_wrap, video',
      )) {
        final isVideo = node.localName == 'video';
        final raw = isVideo
            ? node.attributes['src'] ??
                  node.querySelector('source')?.attributes['src']
            : _backgroundUrl(node.attributes['style'] ?? '');
        final url = mediaUri(raw, page);
        if (url == null || !seen.add(url)) continue;
        final animated =
            node.classes.any(
              (name) => name.contains('animation') || name.contains('gif'),
            ) ||
            node.parent?.classes.any(
                  (name) => name.contains('animation') || name.contains('gif'),
                ) ==
                true;
        final kind = isVideo
            ? (animated ? MediaKind.gif : MediaKind.video)
            : MediaKind.fromUrl(url.toString()) ?? MediaKind.image;
        items.add(
          ContentItem(
            id: 'telegram_${post}_${index++}',
            sourceId: source.id,
            title: title == null || title.isEmpty
                ? 'Публикация Telegram'
                : title,
            author: '@$channel',
            mediaUrl: url.toString(),
            thumbnailUrl: mediaUri(node.attributes['poster'], page)?.toString(),
            kind: kind,
            isNsfw: source.isNsfw || _nsfw.hasMatch(title ?? ''),
            createdAt: DateTime.tryParse(date ?? '') ?? source.addedAt,
            postUrl: postUrl.toString(),
          ),
        );
      }
    }
    return items;
  }

  static final _background = RegExp(
    r"""background-image\s*:\s*url\(\s*(['"]?)(.*?)\1\s*\)""",
    caseSensitive: false,
  );
  static final _nsfw = RegExp(
    r'\b(nsfw|yiff|hentai|rule34|xxx)\b|18\+|нсфв|порно',
    caseSensitive: false,
  );

  String? _backgroundUrl(String style) =>
      _background.firstMatch(style)?.group(2);
}
