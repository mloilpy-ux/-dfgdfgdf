import 'package:http/http.dart' as http;

import '../models/content_item.dart';
import '../models/content_source.dart';
import 'source_response.dart';

class RedditParser {
  final http.Client _client;

  RedditParser(this._client);

  Future<List<ContentItem>> parse(ContentSource source, String token) async {
    final community = Uri.parse(
      ContentSource.fromUrl(source.url).url,
    ).pathSegments[1];
    final response = await fetchSource(
      _client,
      Uri.https('oauth.reddit.com', '/r/$community/hot', {
        'limit': '35',
        'raw_json': '1',
      }),
      service: 'Reddit',
      headers: {
        'Authorization': 'Bearer $token',
        'User-Agent': 'android:com.example.furry_content_hub:1.1.0',
        'Accept': 'application/json',
      },
    );
    final posts = decodeSourceJson(response, 'Reddit')['data']?['children'];
    if (posts is! List)
      throw const SourceFailure('Reddit не вернул список публикаций');

    final items = <ContentItem>[];
    for (final post in posts) {
      if (post is! Map || post['data'] is! Map) continue;
      final data = post['data'] as Map;
      final postId = data['id'];
      if (postId is! String) continue;
      final thumbnail = mediaUri(data['thumbnail'] as String?);
      final timestamp = data['created_utc'];
      final crossposts = data['crosspost_parent_list'];
      final mediaData = crossposts is List && crossposts.firstOrNull is Map
          ? crossposts.first as Map
          : data;
      var index = 0;
      for (final (url, kind) in _media(mediaData)) {
        final suffix = index == 0 ? '' : '_$index';
        items.add(
          ContentItem(
            id: 'reddit_$postId$suffix',
            sourceId: source.id,
            title: data['title'] as String? ?? 'Публикация Reddit',
            author: data['author'] as String?,
            mediaUrl: url.toString(),
            thumbnailUrl: thumbnail?.toString(),
            kind: kind,
            isNsfw:
                source.isNsfw ||
                data['over_18'] == true ||
                mediaData['over_18'] == true,
            createdAt: timestamp is num
                ? DateTime.fromMillisecondsSinceEpoch(
                    (timestamp * 1000).round(),
                    isUtc: true,
                  )
                : source.addedAt,
            postUrl: mediaUri(
              data['permalink'] as String?,
              Uri.https('www.reddit.com', '/'),
            )?.toString(),
          ),
        );
        index++;
      }
    }
    return items;
  }

  Iterable<(Uri, MediaKind)> _media(Map data) sync* {
    final video =
        data['secure_media']?['reddit_video'] ?? data['media']?['reddit_video'];
    final videoUrl = mediaUri(video?['fallback_url'] as String?);
    if (videoUrl != null) {
      yield (videoUrl, MediaKind.video);
      return;
    }

    final gallery = data['gallery_data']?['items'];
    final metadata = data['media_metadata'];
    if (gallery is List && metadata is Map) {
      for (final element in gallery) {
        final entry = metadata[element['media_id']]?['s'];
        final gif = mediaUri(entry?['gif'] as String?);
        final image = mediaUri(entry?['u'] as String?);
        final mp4 = mediaUri(entry?['mp4'] as String?);
        if (gif != null) {
          yield (gif, MediaKind.gif);
        } else if (mp4 != null) {
          yield (mp4, MediaKind.gif);
        } else if (image != null) {
          yield (image, MediaKind.image);
        }
      }
      return;
    }

    final url = mediaUri(
      (data['url_overridden_by_dest'] ?? data['url']) as String?,
    );
    if (url == null) return;
    if (url.host == 'i.imgur.com' && url.path.endsWith('.gifv')) {
      yield (
        url.replace(path: url.path.replaceFirst(RegExp(r'\.gifv$'), '.mp4')),
        MediaKind.gif,
      );
      return;
    }
    final kind = MediaKind.fromUrl(url.toString());
    if (kind != null) yield (url, kind);
  }
}
