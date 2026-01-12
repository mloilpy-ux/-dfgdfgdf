enum SourceType { reddit, twitter, telegram }

class ContentSource {
  final String id;
  final String name;
  final String url;
  final SourceType type;
  bool isActive;
  final DateTime addedAt;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.isActive = true,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type.toString(),
      'isActive': isActive ? 1 : 0,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory ContentSource.fromMap(Map<String, dynamic> map) {
    return ContentSource(
      id: map['id'],
      name: map['name'],
      url: map['url'],
      type: SourceType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      isActive: map['isActive'] == 1,
      addedAt: DateTime.parse(map['addedAt']),
    );
  }
}
