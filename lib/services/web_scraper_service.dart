import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'logger_service.dart';
import '../models/content_item.dart';

class WebScraperService {
  static final WebScraperService instance = WebScraperService._init();
  final LoggerService _logger = LoggerService.instance;
  
  WebScraperService._init();

  // ==================== TWITTER / X ====================
  
  Future<List<ContentItem>> parseTwitter(String username, String sourceId) async {
    _logger.log('🐦 Парсинг Twitter: @$username');
    
    // Метод 1: Twitter Syndication API (публичный)
    try {
      final items = await _parseTwitterSyndicationAPI(username, sourceId);
      if (items.isNotEmpty) {
        _logger.log('✅ Twitter API: ${items.length} изображений');
        return items;
      }
    } catch (e) {
      _logger.log('⚠️ Twitter API недоступен: $e', isError: false);
    }
    
    // Метод 2: Nitter зеркала
    final nitterMirrors = [
      'nitter.poast.org',
      'nitter.privacydev.net',
      'nitter.1d4.us',
      'nitter.net',
    ];
    
    for (var mirror in nitterMirrors) {
      try {
        final items = await _parseTwitterViaNitter(username, sourceId, mirror);
        if (items.isNotEmpty) {
          _logger.log('✅ Nitter ($mirror): ${items.length} изображений');
          return items;
        }
      } catch (e) {
        _logger.log('⚠️ $mirror не работает', isError: false);
      }
    }
    
    _logger.log('❌ Все методы Twitter не сработали', isError: true);
    return [];
  }

  Future<List<ContentItem>> _parseTwitterSyndicationAPI(String username, String sourceId) async {
    // Twitter Syndication API - публичный endpoint для вставки твитов
    final url = 'https://cdn.syndication.twimg.com/timeline/profile?screen_name=$username&limit=20';
    _logger.log('📡 Twitter Syndication: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final tweets = json['timeline'] as List? ?? [];
    final items = <ContentItem>[];

    for (var tweet in tweets) {
      try {
        final photos = tweet['photos'] as List? ?? [];
        
        for (var photo in photos) {
          final mediaUrl = photo['url'] as String?;
          if (mediaUrl == null) continue;

          final text = tweet['text'] as String? ?? 'Twitter post';
          final author = tweet['user']?['name'] as String? ?? username;
          final tweetId = tweet['id_str'] as String?;

          items.add(ContentItem(
            id: 'twitter_${tweetId ?? mediaUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: sourceId,
            title: text.length > 150 ? '${text.substring(0, 150)}...' : text,
            author: author,
            mediaUrl: mediaUrl,
            isGif: false,
            isNsfw: _detectNsfwFromText(text),
            createdAt: DateTime.now(),
            postUrl: tweetId != null ? 'https://twitter.com/$username/status/$tweetId' : 'https://twitter.com/$username',
          ));
        }
      } catch (e) {
        _logger.log('⚠️ Ошибка парсинга твита из API: $e', isError: false);
      }
    }

    return items;
  }

  Future<List<ContentItem>> _parseTwitterViaNitter(String username, String sourceId, String mirror) async {
    final url = 'https://$mirror/$username/media';
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final items = <ContentItem>[];
    final tweets = document.querySelectorAll('.timeline-item');

    for (var tweet in tweets.take(20)) {
      try {
        final images = tweet.querySelectorAll('.still-image, .gallery-photo');
        
        for (var img in images) {
          var imgUrl = img.attributes['href'] ?? img.attributes['src'];
          if (imgUrl == null || imgUrl.isEmpty) continue;

          if (!imgUrl.startsWith('http')) {
            imgUrl = 'https://$mirror$imgUrl';
          }

          final text = tweet.querySelector('.tweet-content')?.text ?? 'Twitter post';
          final author = tweet.querySelector('.fullname')?.text ?? username;

          items.add(ContentItem(
            id: 'twitter_${imgUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: sourceId,
            title: text.length > 150 ? '${text.substring(0, 150)}...' : text,
            author: author,
            mediaUrl: imgUrl,
            isGif: imgUrl.contains('.gif'),
            isNsfw: _detectNsfwFromText(text),
            createdAt: DateTime.now(),
            postUrl: 'https://twitter.com/$username',
          ));
        }
      } catch (e) {
        _logger.log('⚠️ Ошибка парсинга твита: $e', isError: false);
      }
    }

    return items;
  }

  // ==================== TELEGRAM ====================

  Future<List<ContentItem>> parseTelegram(String channelUrl, String sourceId) async {
    _logger.log('✈️ Парсинг Telegram: $channelUrl');
    
    final channelName = _extractTelegramChannelName(channelUrl);
    if (channelName == null) {
      _logger.log('❌ Неверный формат Telegram URL', isError: true);
      return [];
    }

    // Метод 1: Публичный превью
    try {
      final items = await _parseTelegramPublic(channelName, sourceId, channelUrl);
      if (items.isNotEmpty) {
        _logger.log('✅ Telegram: ${items.length} изображений');
        return items;
      }
    } catch (e) {
      _logger.log('⚠️ Telegram превью недоступен: $e', isError: false);
    }

    _logger.log('❌ Telegram парсинг не удался', isError: true);
    return [];
  }

  Future<List<ContentItem>> _parseTelegramPublic(String channelName, String sourceId, String originalUrl) async {
    final url = 'https://t.me/s/$channelName';
    _logger.log('📡 Telegram: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final document = html_parser.parse(response.body);
    final items = <ContentItem>[];
    final messages = document.querySelectorAll('.tgme_widget_message');

    _logger.log('🔍 Найдено сообщений Telegram: ${messages.length}');

    for (var message in messages.take(40)) {
      try {
        String? mediaUrl;
        bool isGif = false;

        // Ищем фото
        var photo = message.querySelector('.tgme_widget_message_photo_wrap');
        if (photo != null) {
          final style = photo.attributes['style'] ?? '';
          final match = RegExp(r"url\('([^']+)'\)").firstMatch(style);
          if (match != null) {
            mediaUrl = match.group(1)!;
          }
        }

        // Ищем видео/GIF
        if (mediaUrl == null) {
          photo = message.querySelector('.tgme_widget_message_video_thumb');
          if (photo != null) {
            final style = photo.attributes['style'] ?? '';
            final match = RegExp(r"url\('([^']+)'\)").firstMatch(style);
            if (match != null) {
              mediaUrl = match.group(1)!;
              isGif = true;
            }
          }
        }

        // Ищем документ (изображение)
        if (mediaUrl == null) {
          photo = message.querySelector('.tgme_widget_message_document_wrap');
          if (photo != null) {
            final thumb = photo.querySelector('.tgme_widget_message_document_icon_image');
            if (thumb != null) {
              final style = thumb.attributes['style'] ?? '';
              final match = RegExp(r"url\('([^']+)'\)").firstMatch(style);
              if (match != null) {
                mediaUrl = match.group(1)!;
              }
            }
          }
        }

        if (mediaUrl != null && mediaUrl.isNotEmpty) {
          final text = message.querySelector('.tgme_widget_message_text')?.text ?? 
                      message.querySelector('.js-message_text')?.text ?? 
                      'Telegram';
          
          final postLink = message.querySelector('.tgme_widget_message_date')?.attributes['href'];

          items.add(ContentItem(
            id: 'telegram_${mediaUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
            sourceId: sourceId,
            title: text.length > 150 ? '${text.substring(0, 150)}...' : text,
            author: channelName,
            mediaUrl: mediaUrl,
            isGif: isGif,
            isNsfw: _detectNsfwFromText(text),
            createdAt: DateTime.now(),
            postUrl: postLink ?? originalUrl,
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
    
    final regex = RegExp(r't(?:elegram)?\.me/(?:s/)?([a-zA-Z0-9_]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  bool _detectNsfwFromText(String text) {
    final keywords = [
      'nsfw', '18+', 'adult', 'porn', 'sex', 'nude', 'naked',
      'hentai', 'lewd', 'yiff', 'r34', 'xxx', 'нсфв', 'порно',
    ];
    
    final lower = text.toLowerCase();
    return keywords.any((k) => lower.contains(k));
  }
}
