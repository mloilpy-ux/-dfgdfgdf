import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'logger_service.dart';
import '../models/content_item.dart';

class WebScraperService {
  static final WebScraperService instance = WebScraperService._init();
  final LoggerService _logger = LoggerService.instance;
  
  WebScraperService._init();

  // Парсинг Twitter/X через веб-версию
  Future<List<ContentItem>> parseTwitter(String username, String sourceId) async {
    _logger.log('🐦 Парсинг Twitter: @$username');
    
    try {
      final url = 'https://nitter.net/$username/media';
      _logger.log('📡 Запрос: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final items = <ContentItem>[];

      final tweets = document.querySelectorAll('.timeline-item');
      _logger.log('🔍 Найдено твитов: ${tweets.length}');

      for (var tweet in tweets.take(20)) {
        try {
          final images = tweet.querySelectorAll('.still-image');
          
          for (var img in images) {
            final imgUrl = img.attributes['href'];
            final text = tweet.querySelector('.tweet-content')?.text ?? 'No title';
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

      _logger.log('✅ Twitter: получено ${items.length} изображений');
      return items;
    } catch (e) {
      _logger.log('❌ Ошибка парсинга Twitter: $e', isError: true);
      return [];
    }
  }

  // Парсинг Telegram через веб-версию
  Future<List<ContentItem>> parseTelegram(String channelUrl, String sourceId) async {
    _logger.log('✈️ Парсинг Telegram: $channelUrl');
    
    try {
      // Используем t.me preview
      final url = channelUrl.replaceAll('https://t.me/', 'https://t.me/s/');
      _logger.log('📡 Запрос: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final document = html_parser.parse(response.body);
      final items = <ContentItem>[];

      final messages = document.querySelectorAll('.tgme_widget_message');
      _logger.log('🔍 Найдено сообщений: ${messages.length}');

      for (var message in messages.take(30)) {
        try {
          final photo = message.querySelector('.tgme_widget_message_photo_wrap');
          final video = message.querySelector('.tgme_widget_message_video_thumb');
          
          String? mediaUrl;
          bool isGif = false;

          if (photo != null) {
            final style = photo.attributes['style'] ?? '';
            final match = RegExp(r"url\('([^']+)'\)").firstMatch(style);
            if (match != null) {
              mediaUrl = match.group(1);
            }
          } else if (video != null) {
            final style = video.attributes['style'] ?? '';
            final match = RegExp(r"url\('([^']+)'\)").firstMatch(style);
            if (match != null) {
              mediaUrl = match.group(1);
              isGif = true;
            }
          }

          if (mediaUrl != null && mediaUrl.isNotEmpty) {
            final text = message.querySelector('.tgme_widget_message_text')?.text ?? 'Telegram post';
            final dateStr = message.querySelector('.tgme_widget_message_date time')?.attributes['datetime'];
            final postUrl = message.querySelector('.tgme_widget_message_date')?.attributes['href'];

            items.add(ContentItem(
              id: 'telegram_${mediaUrl.hashCode}',
              sourceId: sourceId,
              title: text.length > 100 ? '${text.substring(0, 100)}...' : text,
              author: 'Telegram Channel',
              mediaUrl: mediaUrl,
              isGif: isGif,
              isNsfw: _detectNsfwFromText(text),
              createdAt: dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
              postUrl: postUrl,
            ));
          }
        } catch (e) {
          _logger.log('⚠️ Ошибка парсинга сообщения: $e', isError: false);
        }
      }

      _logger.log('✅ Telegram: получено ${items.length} изображений');
      return items;
    } catch (e) {
      _logger.log('❌ Ошибка парсинга Telegram: $e', isError: true);
      return [];
    }
  }

  // Простая эвристика NSFW по тексту
  bool _detectNsfwFromText(String text) {
    final nsfwKeywords = [
      'nsfw', '18+', 'adult', 'explicit', 'porn', 'sex', 'nude', 'naked',
      'hentai', 'lewd', 'yiff', 'r34', 'rule34',
    ];
    
    final lowerText = text.toLowerCase();
    return nsfwKeywords.any((keyword) => lowerText.contains(keyword));
  }
}
