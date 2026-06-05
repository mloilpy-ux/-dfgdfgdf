import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'logger_service.dart';
import '../models/content_item.dart';

class WebScraperService {
  static final WebScraperService instance = WebScraperService._init();
  final LoggerService _logger = LoggerService.instance;
  
  WebScraperService._init();

  // ==================== TELEGRAM WEB ====================
  
Future<List<ContentItem>> parseTelegram(String channelUrl, String sourceId) async {
  _logger.log('✈️ Парсинг Telegram Web: $channelUrl');

  final channelName = _extractTelegramChannelName(channelUrl);
  if (channelName == null) {
    _logger.log('❌ Неверный URL Telegram', isError: true);
    return [];
  }

  try {
    final url = 'https://t.me/s/$channelName';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    ).timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      _logger.log('❌ Telegram HTTP ${response.statusCode}', isError: true);
      return [];
    }

    final items = _parseTelegramHTML(response.body, channelName, sourceId, channelUrl);
    _logger.log('✅ Telegram: найдено ${items.length} элементов');
    return items;

  } catch (e) {
    _logger.log('❌ Ошибка Telegram: $e', isError: true);
    return [];
  }
}

  List<ContentItem> _parseTelegramHTML(String html, String channelName, String sourceId, String originalUrl) {
    final document = html_parser.parse(html);
    final items = <ContentItem>[];
    final messages = document.querySelectorAll('.tgme_widget_message');

    _logger.log('🔍 Telegram: найдено ${messages.length} сообщений');

    for (var message in messages.take(60)) {
      try {
        String? mediaUrl;
        bool isVideo = false;

        // ФОТО
        final photoWrap = message.querySelector('.tgme_widget_message_photo_wrap');
        if (photoWrap != null) {
          final style = photoWrap.attributes['style'] ?? '';
          final match = RegExp(r"background-image:url\('([^']+)'\)").firstMatch(style);
          if (match != null) {
            mediaUrl = match.group(1);
          }
        }

        // ВИДЕО
        if (mediaUrl == null) {
          final videoWrap = message.querySelector('.tgme_widget_message_video_wrap');
          if (videoWrap != null) {
            final video = videoWrap.querySelector('video');
            if (video != null) {
              mediaUrl = video.attributes['src'];
              isVideo = true;
            }
          }
        }

        // ВИДЕО ПРЕВЬЮ
        if (mediaUrl == null) {
          final videoThumb = message.querySelector('.tgme_widget_message_video_thumb');
          if (videoThumb != null) {
            final style = videoThumb.attributes['style'] ?? '';
            final match = RegExp(r"background-image:url\('([^']+)'\)").firstMatch(style);
            if (match != null) {
              mediaUrl = match.group(1);
              isVideo = true;
            }
          }
        }

        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          final textElement = message.querySelector('.tgme_widget_message_text');
          final text = textElement?.text?.trim() ?? 'Telegram Post';
          
          final dateElement = message.querySelector('.tgme_widget_message_date time');
          final dateStr = dateElement?.attributes['datetime'];
          
          final linkElement = message.querySelector('.tgme_widget_message_date');
          final postUrl = linkElement?.attributes['href'] ?? originalUrl;

          items.add(ContentItem(
            id: 'telegram_${mediaUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: sourceId,
            title: text.length > 200 ? '${text.substring(0, 200)}...' : text,
            author: channelName,
            mediaUrl: mediaUrl,
            isGif: isVideo,
            isNsfw: _detectNsfw(text),
            createdAt: dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now(),
            postUrl: postUrl,
          ));
        }
      } catch (e) {
        _logger.log('⚠️ Ошибка парсинга сообщения: $e', isError: false);
      }
    }

    return items;
  }

  String? _extractTelegramChannelName(String url) {
    if (url.startsWith('@')) return url.substring(1);
    
    final patterns = [
      RegExp(r't\.me/s/([a-zA-Z0-9_]+)'),
      RegExp(r't\.me/([a-zA-Z0-9_]+)'),
      RegExp(r'telegram\.me/([a-zA-Z0-9_]+)'),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    
    return null;
  }

  // ==================== TWITTER WEB ====================
  
  Future<List<ContentItem>> parseTwitter(String username, String sourceId) async {
    _logger.log('🐦 Парсинг Twitter через Nitter: @$username');
    
    final mirrors = [
      'nitter.poast.org',
      'nitter.privacydev.net',
      'nitter.net',
      'nitter.1d4.us',
    ];
    
    for (var mirror in mirrors) {
      try {
        _logger.log('📡 Пробую $mirror');
        final items = await _parseNitter(username, sourceId, mirror);
        
        if (items.isNotEmpty) {
          _logger.log('✅ $mirror: ${items.length} элементов');
          return items;
        }
      } catch (e) {
        _logger.log('⚠️ $mirror недоступен', isError: false);
      }
    }
    
    _logger.log('❌ Все Nitter зеркала недоступны', isError: true);
    return [];
  }

  Future<List<ContentItem>> _parseNitter(String username, String sourceId, String mirror) async {
    final url = 'https://$mirror/$username/media';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final items = <ContentItem>[];
    final tweets = document.querySelectorAll('.timeline-item');

    _logger.log('🔍 Twitter: найдено ${tweets.length} твитов');

    for (var tweet in tweets.take(30)) {
      try {
        final mediaElements = tweet.querySelectorAll('.still-image, .gallery-photo, a[href*="/pic/"]');
        
        for (var media in mediaElements) {
          var imgUrl = media.attributes['href'] ?? media.attributes['src'];
          if (imgUrl == null || imgUrl.isEmpty) continue;

          if (!imgUrl.startsWith('http')) {
            imgUrl = 'https://$mirror$imgUrl';
          }

          final textElement = tweet.querySelector('.tweet-content');
          final text = textElement?.text?.trim() ?? 'Twitter Post';
          
          final authorElement = tweet.querySelector('.fullname');
          final author = authorElement?.text?.trim() ?? username;
          
          final linkElement = tweet.querySelector('.tweet-link');
          final tweetLink = linkElement?.attributes['href'];

          items.add(ContentItem(
            id: 'twitter_${imgUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: sourceId,
            title: text.length > 200 ? '${text.substring(0, 200)}...' : text,
            author: author,
            mediaUrl: imgUrl,
            isGif: imgUrl.contains('.gif'),
            isNsfw: _detectNsfw(text),
            createdAt: DateTime.now(),
            postUrl: tweetLink != null ? 'https://twitter.com$tweetLink' : 'https://twitter.com/$username',
          ));
        }
      } catch (e) {
        _logger.log('⚠️ Ошибка парсинга твита: $e', isError: false);
      }
    }

    return items;
  }

  // ==================== NSFW ДЕТЕКЦИЯ ====================

  bool _detectNsfw(String text) {
    final keywords = [
      'nsfw', '18+', 'adult', 'porn', 'sex', 'nude', 'naked',
      'hentai', 'lewd', 'yiff', 'r34', 'rule34', 'xxx', 'erotic',
      'нсфв', 'порно', 'эротика',
    ];
    
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }
}
