import 'package:hive/hive.dart';

part 'content_source.g.dart';

enum SourceType {
  reddit,
  twitter,
  telegram,
}

@HiveType(typeId: 1)
class ContentSource extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String url;

  @HiveField(3)
  SourceType type;

  @HiveField(4)
  bool isActive;

  @HiveField(5)
  bool isNsfw;

  @HiveField(6)
  DateTime addedAt;

  @HiveField(7)
  DateTime? lastParsed;

  @HiveField(8)
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
      name = 'Twitter Source';
    } else if (url.contains('t.me')) {
      type = SourceType.telegram;
      name = 'Telegram Channel';
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
        name: 'r/furryart',
        url: 'https://www.reddit.com/r/furryart/',
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
      id: map['id'],
      name: map['name'],
      url: map['url'],
      type: SourceType.values.firstWhere((e) => e.name == map['type']),
      isActive: map['isActive'] == 1,
      isNsfw: map['isNsfw'] == 1,
      addedAt: DateTime.parse(map['addedAt']),
      lastParsed: map['lastParsed'] != null ? DateTime.parse(map['lastParsed']) : null,
      parsedCount: map['parsedCount'] ?? 0,
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
