import 'package:http/http.dart' as http;

import '../models/content_item.dart';
import '../models/content_source.dart';
import 'source_response.dart';

class XParser {
  final http.Client _client;

  XParser(this._client);

  Future<List<ContentItem>> parse(ContentSource source, String token) async {
    final username = Uri.parse(
      ContentSource.fromUrl(source.url).url,
    ).pathSegments.first;
    final headers = {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
    final user = await fetchSource(
      _client,
      Uri.https('api.x.com', '/2/users/by/username/$username'),
      service: 'X',
      headers: headers,
    );
    final id = decodeSourceJson(user, 'X')['data']?['id'];
    if (id is! String) throw const SourceFailure('X: профиль не найден');
    final response = await fetchSource(
      _client,
      Uri.https('api.x.com', '/2/users/$id/tweets', {
        'max_results': '15',
        'exclude': 'retweets,replies',
        'expansions': 'attachments.media_keys',
        'tweet.fields': 'created_at,possibly_sensitive',
        'media.fields': 'media_key,type,url,preview_image_url,variants',
      }),
      service: 'X',
      headers: headers,
    );
    final data = decodeSourceJson(response, 'X');
    if (data['data'] == null && data['errors'] is List) {
      throw const SourceFailure(
        'X не предоставил доступ к публикациям профиля',
      );
    }
    final posts = data['data'] as List? ?? [];
    final media = {
      for (final item in (data['includes']?['media'] as List? ?? []))
        item['media_key']: item as Map,
    };
    final items = <ContentItem>[];
    for (final post in posts) {
      for (final key in (post['attachments']?['media_keys'] as List? ?? [])) {
        final asset = media[key];
        if (asset == null) continue;
        final kind = switch (asset['type']) {
          'photo' => MediaKind.image,
          'animated_gif' => MediaKind.gif,
          'video' => MediaKind.video,
          _ => null,
        };
        if (kind == null) continue;
        final mp4s = (asset['variants'] as List? ?? [])
            .where((variant) => variant['content_type'] == 'video/mp4')
            .toList();
        mp4s.sort(
          (a, b) => ((b['bit_rate'] as int?) ?? 0).compareTo(
            (a['bit_rate'] as int?) ?? 0,
          ),
        );
        final url = mediaUri(
          (asset['url'] ?? mp4s.firstOrNull?['url']) as String?,
        );
        if (url == null) continue;
        items.add(
          ContentItem(
            id: 'x_${post['id']}_$key',
            sourceId: source.id,
            title: post['text'] as String? ?? 'Публикация X',
            author: '@$username',
            mediaUrl: url.toString(),
            thumbnailUrl: mediaUri(
              asset['preview_image_url'] as String?,
            )?.toString(),
            kind: kind,
            isNsfw: source.isNsfw || post['possibly_sensitive'] == true,
            createdAt:
                DateTime.tryParse(post['created_at'] as String? ?? '') ??
                source.addedAt,
            postUrl: 'https://x.com/$username/status/${post['id']}',
          ),
        );
      }
    }
    return items;
  }
}
