import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/content_item.dart';
import 'logger_service.dart';

class RedditParser {
  final LoggerService _logger = LoggerService.instance;

  Future<List<ContentItem>> parseSubreddit(String subredditUrl, String sourceId) async {
    try {
      _logger.log('🔍 Начинаю парсинг: $subredditUrl');
      
      // Извлекаем имя сабреддита
      final subredditName = _extractSubredditName(subredditUrl);
      final jsonUrl = 'https://www.reddit.com/r/$subredditName.json?limit=50';
      
      _logger.log('📡 Запрос к API: $jsonUrl');
      
      final response = await http.get(
        Uri.parse(jsonUrl),
        headers: {'User-Agent': 'FurryContentHub/1.0'},
      );

      if (response.statusCode != 200) {
        _logger.log('❌ Ошибка: HTTP ${response.statusCode}', isError: true);
        return [];
      }

      _logger.log('✅ Получен ответ: ${response.body.length} байт');

      final data = json.decode(response.body);
      final posts = data['data']['children'] as List;
      
      final List<ContentItem> items = [];
      
      for (var post in posts) {
        final postData = post['data'];
        
        // Пропускаем текстовые посты
        if (postData['post_hint'] != 'image' && 
            postData['post_hint'] != 'hosted:video' &&
            postData['post_hint'] != 'rich:video') {
          continue;
        }

        final isNsfw = postData['over_18'] ?? false;
        final isGif = postData['url']?.toString().contains('.gif') ?? false;
        
        String? mediaUrl;
        if (postData['url'] != null) {
          mediaUrl = postData['url'];
        } else if (postData['preview']?['images']?[0]?['source']?['url'] != null) {
          mediaUrl = postData['preview']['images'][0]['source']['url']
              .toString()
              .replaceAll('&amp;', '&');
        }

        if (mediaUrl == null) continue;

        final item = ContentItem(
          id: const Uuid().v4(),
          sourceId: sourceId,
          title: postData['title'] ?? 'Без названия',
          author: postData['author'],
          mediaUrl: mediaUrl,
          thumbnailUrl: postData['thumbnail'],
          isGif: isGif,
          isNsfw: isNsfw,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            (postData['created_utc'] * 1000).toInt(),
          ),
          postUrl: 'https://reddit.com${postData['permalink']}',
        );

        items.add(item);
      }

      _logger.log('✨ Найдено ${items.length} элементов из ${posts.length} постов');
      return items;
      
    } catch (e) {
      _logger.log('💥 Критическая ошибка: $e', isError: true);
      return [];
    }
  }

  String _extractSubredditName(String url) {
    final regex = RegExp(r'/r/([^/]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '';
  }
}
