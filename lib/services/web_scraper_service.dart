import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'logger_service.dart';
import '../models/content_item.dart';

class WebScraperService {
  static final WebScraperService instance = WebScraperService._init();
  final LoggerService _logger = LoggerService.instance;
  
  WebScraperService._init();

  Future<List<ContentItem>> parseTwitter(String username, String sourceId) async {
    _logger.log('🐦 Парсинг Twitter: @$username');
    
    try {
      final url = 'https://nitter.net/$username/media';
      _logger.log('📡 Запрос: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final items = <ContentItem>[];
      final tweets = document.querySelectorAll('.timeline-item');

      for (var tweet in tweets.take(20)) {
        try {
          final images = tweet.querySelectorAll('.still-image');
          
          for (var img in images) {
            final imgUrl = img.attributes['href'];
            final text = tweet.querySelector('.tweet-content')?.text ?? 'Twitter post';
            final author = tweet.querySelector('.fullname')?.text ?? username;

            if (imgUrl != null && imgUrl.isNotEmpty) {
              items.add(ContentItem(
                id: 'twitter_${imgUrl.hashCode}',
                sourceId: sourceId,
                title: text.length > 100 ? '${text.substring(0, 100)}...' : text,
                author: author,
                mediaUrl: 'https://nitter.net$imgUrl',
                isGif: imgUrl.contains('.gif'),
                isNsfw: _detectNsfwFromText(text),
                createdAt: DateTime.now(),
                postUrl: 'https://twitter.com/$username',
              ));
            }
          }
        } catch (e) {
          _logger.log('⚠️ Ошибка парсинга твита: $e', isError: false);
        }
      }

      _logger.log('✅ Twitter: ${items.length} изображений');
      return items;
    } catch (e) {
      _logger.log('❌ Ошибка Twitter: $e', isError: true);
      return [];
    }
  }

  Future<List<ContentItem>> parseTelegram(String channelUrl, String sourceId) async {
    _logger.log('✈️ Парсинг Telegram: $channelUrl');
    
    try {
      final url = channelUrl.replaceAll('https://t.me/', 'https://t.me/s/');
      _logger.log('📡 Запрос: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0'},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final items = <ContentItem>[];
      final messages = document.querySelectorAll('.tgme_widget_message');

      for (var message in messages.take(30)) {
        try {
          final photo = message.querySelector('.tgme_widget_message_photo_wrap');
          String? mediaUrl;

          if (photo != null) {
            final style = photo.attributes['style'] ?? '';
            final match = RegExp(r"url\('([^']+)'\)").firstMatch(style);
            if (match != null) {
              mediaUrl = match.group(1);
            }
          }

          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            final text = message.querySelector('.tgme_widget_message_text')?.text ?? 'Telegram post';

            items.add(ContentItem(
              id: 'telegram_${mediaUrl.hashCode}',
              sourceId: sourceId,
              title: text.length > 100 ? '${text.substring(0, 100)}...' : text,
              author: 'Telegram',
              mediaUrl: mediaUrl,
              isGif: false,
              isNsfw: _detectNsfwFromText(text),
              createdAt: DateTime.now(),
              postUrl: channelUrl,
            ));
          }
        } catch (e) {
          _logger.log('⚠️ Ошибка парсинга сообщения: $e', isError: false);
        }
      }

      _logger.log('✅ Telegram: ${items.length} изображений');
      return items;
    } catch (e) {
      _logger.log('❌ Ошибка Telegram: $e', isError: true);
      return [];
    }
  }

  bool _detectNsfwFromText(String text) {
    final nsfwKeywords = ['nsfw', '18+', 'adult', 'porn', 'sex', 'nude', 'naked', 'hentai', 'lewd', 'yiff'];
    final lowerText = text.toLowerCase();
    return nsfwKeywords.any((keyword) => lowerText.contains(keyword));
  }
}
