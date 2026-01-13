enum SourceType { reddit, twitter, telegram }

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

  factory ContentSource.fromUrl(String url) {
    String id = DateTime.now().millisecondsSinceEpoch.toString();
    String name;
    SourceType type;

    if (url.contains('reddit.com')) {
      type = SourceType.reddit;
      final match = RegExp(r'r/([a-zA-Z0-9_]+)').firstMatch(url);
      name = match != null ? 'r/${match.group(1)}' : 'Reddit Source';
    } else if (url.contains('twitter.com') || url.contains('x.com')) {
      type = SourceType.twitter;
      final match = RegExp(r'(?:twitter|x)\.com/([^/]+)').firstMatch(url);
      name = match != null ? '@${match.group(1)}' : 'Twitter Source';
    } else if (url.contains('t.me')) {
      type = SourceType.telegram;
      final match = RegExp(r't\.me/([^/]+)').firstMatch(url);
      name = match != null ? match.group(1)! : 'Telegram Channel';
    } else {
      throw Exception('Неподдерживаемый тип источника');
    }

    return ContentSource(
      id: id,
      name: name,
      url: url,
      type: type,
      addedAt: DateTime.now(),
    );
  }

  static List<ContentSource> getDefaultSources() {
    return [
      ContentSource(
        id: 'default_1',
        name: 'r/furry_irl',
        url: 'https://www.reddit.com/r/furry_irl/',
        type: SourceType.reddit,
        isActive: true,
        addedAt: DateTime.now(),
      ),
      ContentSource(
        id: 'default_2',
        name: 'r/furrymemes',
        url: 'https://www.reddit.com/r/furrymemes/',
        type: SourceType.reddit,
        isActive: true,
        addedAt: DateTime.now(),
      ),
      ContentSource(
        id: 'default_3',
        name: 'r/furry',
        url: 'https://www.reddit.com/r/furry/',
        type: SourceType.reddit,
        isActive: true,
        addedAt: DateTime.now(),
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
      type: SourceType.values.firstWhere((e) => e.name == map['type']),
      isActive: (map['isActive'] as int) == 1,
      isNsfw: (map['isNsfw'] as int) == 1,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastParsed: map['lastParsed'] != null ? DateTime.parse(map['lastParsed'] as String) : null,
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
