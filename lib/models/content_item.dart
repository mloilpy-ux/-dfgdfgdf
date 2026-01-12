class ContentItem {
  final String id;
  final String sourceId;
  final String title;
  final String? author;
  final String mediaUrl;
  final String? thumbnailUrl;
  final bool isGif;
  final bool isNsfw;
  final DateTime createdAt;
  bool isSaved;
  final String? postUrl;

  ContentItem({
    required this.id,
    required this.sourceId,
    required this.title,
    this.author,
    required this.mediaUrl,
    this.thumbnailUrl,
    this.isGif = false,
    this.isNsfw = false,
    required this.createdAt,
    this.isSaved = false,
    this.postUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sourceId': sourceId,
      'title': title,
      'author': author,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'isGif': isGif ? 1 : 0,
      'isNsfw': isNsfw ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'isSaved': isSaved ? 1 : 0,
      'postUrl': postUrl,
    };
  }

  factory ContentItem.fromMap(Map<String, dynamic> map) {
    return ContentItem(
      id: map['id'],
      sourceId: map['sourceId'],
      title: map['title'],
      author: map['author'],
      mediaUrl: map['mediaUrl'],
      thumbnailUrl: map['thumbnailUrl'],
      isGif: map['isGif'] == 1,
      isNsfw: map['isNsfw'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      isSaved: map['isSaved'] == 1,
      postUrl: map['postUrl'],
    );
  }
}
