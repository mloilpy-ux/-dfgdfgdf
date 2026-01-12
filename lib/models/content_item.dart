import 'package:hive/hive.dart';

part 'content_item.g.dart';

@HiveType(typeId: 0)
class ContentItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String sourceId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String? author;

  @HiveField(4)
  final String mediaUrl;

  @HiveField(5)
  final String? thumbnailUrl;

  @HiveField(6)
  final bool isGif;

  @HiveField(7)
  final bool isNsfw;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  bool isSaved;

  @HiveField(10)
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
