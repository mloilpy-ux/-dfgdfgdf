import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/content_item.dart';
import 'logger_service.dart';

class RedditParser {
  final LoggerService _logger = LoggerService.instance;

  // БАГ #1 ИСПРАВЛЕН: правильный User-Agent по требованиям Reddit API.
  // Браузерный Mozilla/5.0 блокируется — Reddit возвращает HTML вместо JSON.
  static const String _userAgent = 'android:furry_content_hub:1.0.0 (by /u/anonymous)';

  // Thumbnail-значения, которые не являются реальными URL
  static const _invalidThumbnails = {'self', 'default', 'nsfw', 'spoiler', 'image', ''};

  Future<List<ContentItem>> parseSubreddit(
      String subredditUrl, String sourceId) async {
    try {
      final url = subredditUrl.endsWith('/')
          ? '${subredditUrl}hot.json?limit=50'
          : '$subredditUrl/hot.json?limit=50';

      _logger.log('📡 Reddit запрос: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          // БАГ #1 ИСПРАВЛЕН: используем правильный User-Agent
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 429) {
        _logger.log('⚠️ Reddit: Слишком много запросов (429)', isError: true);
        return [];
      }

      if (response.statusCode == 403) {
        _logger.log('❌ Reddit: Доступ запрещён (403). Проверь URL сабреддита.',
            isError: true);
        return [];
      }

      if (response.statusCode != 200) {
        _logger.log('❌ Reddit HTTP ${response.statusCode}', isError: true);
        return [];
      }

      // БАГ #2 ИСПРАВЛЕН: проверяем Content-Type до jsonDecode.
      // Если Reddit вернул HTML (блокировка/редирект) — jsonDecode упадёт с FormatException.
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json') &&
          !contentType.contains('text/json')) {
        _logger.log(
            '❌ Reddit вернул не JSON (Content-Type: $contentType). '
            'Вероятно, запрос заблокирован.',
            isError: true);
        return [];
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        _logger.log('❌ Ошибка разбора JSON от Reddit: $e', isError: true);
        return [];
      }

      final posts = json['data']?['children'] as List?;
      if (posts == null) {
        _logger.log('❌ Неожиданная структура ответа Reddit', isError: true);
        return [];
      }

      final items = <ContentItem>[];

      for (var post in posts) {
        try {
          final data = post['data'] as Map<String, dynamic>?;
          if (data == null) continue;

          String? mediaUrl;
          String? thumbnailUrl = data['thumbnail'] as String?;
          bool isGif = false;

          if (data['is_video'] == true) {
            // Видео: берём fallback_url (MP4), не HLS-поток (.m3u8)
            final fallback =
                data['media']?['reddit_video']?['fallback_url'] as String?;
            if (fallback != null && !fallback.contains('.m3u8')) {
              mediaUrl = fallback;
            }
          } else if (data['is_gallery'] == true) {
            // БАГ #4 ИСПРАВЛЕН: галерейные посты — берём первое изображение
            final metadata =
                data['media_metadata'] as Map<String, dynamic>?;
            if (metadata != null && metadata.isNotEmpty) {
              final firstItem =
                  metadata.values.first as Map<String, dynamic>?;
              final source = firstItem?['s'] as Map<String, dynamic>?;
              mediaUrl = source?['u'] as String?;
              // URL в галерее содержит &amp; — декодируем
              mediaUrl = mediaUrl?.replaceAll('&amp;', '&');
            }
          } else {
            final rawUrl = data['url'] as String?;
            if (rawUrl != null) {
              mediaUrl = rawUrl;
              if (mediaUrl.endsWith('.gif') || mediaUrl.endsWith('.gifv')) {
                isGif = true;
              }
            }
          }

          if (mediaUrl == null || mediaUrl.isEmpty) continue;
          if (!mediaUrl.startsWith('http')) continue;

          // БАГ #3 ИСПРАВЛЕН: фильтруем все невалидные thumbnail-значения
          final validThumbnail = (thumbnailUrl != null &&
                  !_invalidThumbnails.contains(thumbnailUrl) &&
                  thumbnailUrl.startsWith('http'))
              ? thumbnailUrl
              : null;

          items.add(ContentItem(
            id: 'reddit_${data['id']}',
            sourceId: sourceId,
            title: (data['title'] as String?) ?? 'No title',
            author: data['author'] as String?,
            mediaUrl: mediaUrl,
            thumbnailUrl: validThumbnail,
            isGif: isGif,
            isNsfw: (data['over_18'] as bool?) ?? false,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              ((data['created_utc'] as num).toInt()) * 1000,
            ),
            postUrl: 'https://reddit.com${data['permalink']}',
          ));
        } catch (e) {
          _logger.log('⚠️ Ошибка парсинга поста: $e', isError: false);
        }
      }

      _logger.log('✅ Reddit: спарсено ${items.length} постов');
      return items;
    } catch (e) {
      _logger.log('❌ Ошибка парсинга Reddit: $e', isError: true);
      return [];
    }
  }
}
