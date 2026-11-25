import 'dart:math';

import 'content_item.dart';
import 'source_type.dart';

export 'source_type.dart';

class ContentSource {
  final String id;
  String name;
  String url;
  SourceType type;
  bool isActive;
  bool isNsfw;
  DateTime addedAt;
  DateTime? lastParsed;
  int parsedCount;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.isActive = true,
    this.isNsfw = false,
    required this.addedAt,
    this.lastParsed,
    this.parsedCount = 0,
  });

  factory ContentSource.fromUrl(String input) {
    final value = input.trim();
    final normalized = value.startsWith('@')
        ? 'https://t.me/${value.substring(1)}'
        : value;
    final uri = Uri.tryParse(
      normalized.contains('://') ? normalized : 'https://$normalized',
    );
    if (uri == null ||
        uri.host.isEmpty ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('Введите корректную ссылку на источник');
    }

    final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final first = parts.firstOrNull ?? '';
    final second = parts.length > 1 ? parts[1] : '';
    final validName = RegExp(r'^[a-zA-Z0-9_]+$');
    late final String name;
    late final String url;
    late final SourceType type;
    if ({
      'reddit.com',
      'old.reddit.com',
      'm.reddit.com',
      'redd.it',
    }.contains(host)) {
      final isCommunity = first == 'r' && validName.hasMatch(second);
      name = isCommunity ? 'r/$second' : 'Reddit';
      final path = isCommunity && parts.length == 2
          ? '/r/${second.toLowerCase()}/'
          : uri.path;
      url = uri
          .replace(
            scheme: 'https',
            host: host == 'reddit.com' || host == 'm.reddit.com'
                ? 'www.reddit.com'
                : host,
            path: path,
          )
          .toString();
      type = SourceType.reddit;
    } else if ({'t.me', 'telegram.me', 'telegram.dog'}.contains(host)) {
      final channel = first == 's' ? second : first;
      if (!validName.hasMatch(channel) ||
          {
            'c',
            's',
            'joinchat',
            'share',
            'addstickers',
          }.contains(channel.toLowerCase())) {
        throw const FormatException(
          'Укажите ссылку на публичный канал Telegram',
        );
      }
      name = '@$channel';
      url = 'https://t.me/${channel.toLowerCase()}';
      type = SourceType.telegram;
    } else if ({'x.com', 'twitter.com', 'mobile.twitter.com'}.contains(host)) {
      name = first.isNotEmpty && validName.hasMatch(first) ? '@$first' : 'X';
      final path = parts.length == 1 && validName.hasMatch(first)
          ? '/${first.toLowerCase()}'
          : uri.path;
      url = uri.replace(scheme: 'https', host: 'x.com', path: path).toString();
      type = SourceType.twitter;
    } else if (host == 'pin.it' || _pinterest.hasMatch(host)) {
      name = 'Pinterest';
      url = uri.replace(scheme: 'https').toString();
      type = SourceType.pinterest;
    } else if (uri.scheme == 'https' &&
        MediaKind.fromUrl(uri.toString()) != null) {
      name = parts.last;
      url = uri.removeFragment().toString();
      type = SourceType.direct;
    } else if (uri.scheme == 'https') {
      name = host;
      url = uri.toString();
      type = SourceType.web;
    } else {
      throw const FormatException(
        'Укажите HTTPS-ссылку на веб-страницу или медиафайл',
      );
    }

    return ContentSource(
      id: '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}',
      name: name,
      url: url,
      type: type,
      addedAt: DateTime.now(),
    );
  }

  static final _pinterest = RegExp(
    r'^(?:[a-z]{2}\.)?pinterest\.(?:[a-z]{2,3}|co\.[a-z]{2}|com\.[a-z]{2})$',
  );

  static ContentSource defaultTelegramSource() => ContentSource(
    id: 'default_telegram_furries',
    name: '@furries',
    url: 'https://t.me/furries',
    type: SourceType.telegram,
    addedAt: DateTime.utc(2026, 11, 25),
  );

  static List<ContentSource> getDefaultSources() {
    return [
      defaultTelegramSource(),
      ContentSource(
        id: 'default_1',
        name: 'r/furry_irl',
        url: 'https://www.reddit.com/r/furry_irl/',
        type: SourceType.reddit,
        isActive: true,
        addedAt: DateTime(2024),
      ),
      ContentSource(
        id: 'default_2',
        name: 'r/furrymemes',
        url: 'https://www.reddit.com/r/furrymemes/',
        type: SourceType.reddit,
        isActive: true,
        addedAt: DateTime(2024),
      ),
      ContentSource(
        id: 'default_3',
        name: 'r/furry',
        url: 'https://www.reddit.com/r/furry/',
        type: SourceType.reddit,
        isActive: true,
        addedAt: DateTime(2024),
      ),
    ];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type.name,
      'isActive': isActive ? 1 : 0,
      'isNsfw': isNsfw ? 1 : 0,
      'addedAt': addedAt.toIso8601String(),
      'lastParsed': lastParsed?.toIso8601String(),
      'parsedCount': parsedCount,
    };
  }

  factory ContentSource.fromMap(Map<String, dynamic> map) {
    return ContentSource(
      id: map['id'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      // БАГ #1 ИСПРАВЛЕН: orElse вместо краша на неизвестном типе
      type: SourceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SourceType.web,
      ),
      isActive: map['isActive'] != 0,
      isNsfw: map['isNsfw'] == 1,
      addedAt:
          DateTime.tryParse(map['addedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastParsed: DateTime.tryParse(map['lastParsed'] as String? ?? ''),
      parsedCount: (map['parsedCount'] as int?) ?? 0,
    );
  }

  ContentSource copyWith({
    String? name,
    String? url,
    bool? isActive,
    bool? isNsfw,
    DateTime? lastParsed,
    int? parsedCount,
  }) {
    return ContentSource(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type,
      isActive: isActive ?? this.isActive,
      isNsfw: isNsfw ?? this.isNsfw,
      addedAt: addedAt,
      lastParsed: lastParsed ?? this.lastParsed,
      parsedCount: parsedCount ?? this.parsedCount,
    );
  }
}
