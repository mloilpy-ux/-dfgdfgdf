class ContentSource {
  final String id;
  final String name;
  final String url;
  final SourceType type;
  final bool isActive;
  final DateTime addedAt;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    bool? isActive,
    DateTime? addedAt,
  })  : isActive = isActive ?? true,
        addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type.name,
      'isActive': isActive ? 1 : 0,
      'addedAt': addedAt.toIso8601String(),
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
      addedAt: DateTime.parse(map['addedAt'] as String),
    );
  }

  ContentSource copyWith({
    String? id,
    String? name,
    String? url,
    SourceType? type,
    bool? isActive,
    DateTime? addedAt,
  }) {
    return ContentSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      type: type ?? this.type,
      isActive: isActive ?? this.isActive,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

enum SourceType {
  reddit,
  twitter,
  telegram,
}
