import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/content_item.dart';
import 'logger_service.dart';

class RedditParser {
  final LoggerService _logger = LoggerService.instance;

  Future<List<ContentItem>> parseSubreddit(String subredditUrl, String sourceId) async {
    try {
      final url = subredditUrl.endsWith('/') ? '${subredditUrl}hot.json?limit=50' : '$subredditUrl/hot.json?limit=50';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'FurryContentHub/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final json = jsonDecode(response.body);
      final posts = json['data']['children'] as List;

      final items = <ContentItem>[];

      for (var post in posts) {
        try {
          final data = post['data'];
          
          if (data['is_video'] == true || data['post_hint'] == 'image' || data['post_hint'] == 'link') {
            String? mediaUrl;
            String? thumbnailUrl = data['thumbnail'];
            bool isGif = false;

            if (data['is_video'] == true) {
              mediaUrl = data['media']?['reddit_video']?['fallback_url'];
            } else if (data['url'] != null) {
              mediaUrl = data['url'];
              // ИСПРАВЛЕНО: проверка на null
              if (mediaUrl != null && (mediaUrl.endsWith('.gif') || mediaUrl.endsWith('.gifv'))) {
                isGif = true;
              }
            }

            if (mediaUrl == null || mediaUrl.isEmpty) continue;

            items.add(ContentItem(
              id: 'reddit_${data['id']}',
              sourceId: sourceId,
              title: data['title'] ?? 'No title',
              author: data['author'],
              mediaUrl: mediaUrl,
              thumbnailUrl: thumbnailUrl != 'self' && thumbnailUrl != 'default' ? thumbnailUrl : null,
              isGif: isGif,
              isNsfw: data['over_18'] == true,
              createdAt: DateTime.fromMillisecondsSinceEpoch((data['created_utc'] as num).toInt() * 1000),
              postUrl: 'https://reddit.com${data['permalink']}',
            ));
          }
        } catch (e) {
          _logger.log('⚠️ Ошибка парсинга поста: $e', isError: false);
        }
      }

      _logger.log('📥 Спарсено ${items.length} постов из $subredditUrl');
      return items;
      
    } catch (e) {
      _logger.log('❌ Ошибка парсинга Reddit: $e', isError: true);
      return [];
    }
  }
}
