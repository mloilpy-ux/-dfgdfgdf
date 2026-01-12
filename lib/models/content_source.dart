class ContentSource {
  final String id;
  final String name;
  final String url;
  final SourceType type;
  final bool isActive;
  final bool isNsfw;
  final DateTime addedAt;
  final DateTime? lastParsed;
  final int parsedCount;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    bool? isActive,
    bool? isNsfw,
    DateTime? addedAt,
    this.lastParsed,
    int? parsedCount,
  })  : isActive = isActive ?? true,
        isNsfw = isNsfw ?? false,
        addedAt = addedAt ?? DateTime.now(),
        parsedCount = parsedCount ?? 0;

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
      type: SourceType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SourceType.reddit,
      ),
      isActive: (map['isActive'] as int) == 1,
      isNsfw: (map['isNsfw'] as int) == 1,
      addedAt: DateTime.parse(map['addedAt'] as String),
      lastParsed: map['lastParsed'] != null ? DateTime.parse(map['lastParsed'] as String) : null,
      parsedCount: map['parsedCount'] as int? ?? 0,
    );
  }

  ContentSource copyWith({
    String? id,
    String? name,
    String? url,
    SourceType? type,
    bool? isActive,
    bool? isNsfw,
    DateTime? addedAt,
    DateTime? lastParsed,
    int? parsedCount,
  }) {
    return ContentSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      isNsfw: isNsfw ?? this.isNsfw,
      addedAt: addedAt ?? this.addedAt,
      lastParsed: lastParsed ?? this.lastParsed,
      parsedCount: parsedCount ?? this.parsedCount,
    );
  }

  // Стандартные источники
  static List<ContentSource> getDefaultSources() {
    return [
      ContentSource(
        id: 'default_1',
        name: 'r/furry_irl',
        url: 'https://www.reddit.com/r/furry_irl/',
        type: SourceType.reddit,
        isActive: true,
        isNsfw: false,
      ),
      ContentSource(
        id: 'default_2',
        name: 'r/furrymemes',
        url: 'https://www.reddit.com/r/furrymemes/',
        type: SourceType.reddit,
        isActive: true,
        isNsfw: false,
      ),
      ContentSource(
        id: 'default_3',
        name: 'r/furryart',
        url: 'https://www.reddit.com/r/furryart/',
        type: SourceType.reddit,
        isActive: true,
        isNsfw: false,
      ),
    ];
  }
}
