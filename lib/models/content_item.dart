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
      id: map['id'] as String,
      sourceId: map['sourceId'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      mediaUrl: map['mediaUrl'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      isGif: (map['isGif'] as int) == 1,
      isNsfw: (map['isNsfw'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isSaved: (map['isSaved'] as int) == 1,
      postUrl: map['postUrl'] as String?,
    );
  }

  ContentItem copyWith({bool? isSaved}) {
    return ContentItem(
      id: id,
      sourceId: sourceId,
      title: title,
      author: author,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      isGif: isGif,
      isNsfw: isNsfw,
      createdAt: createdAt,
      isSaved: isSaved ?? this.isSaved,
      postUrl: postUrl,
    );
  }
}
