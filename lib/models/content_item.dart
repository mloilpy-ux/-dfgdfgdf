import 'package:hive/hive.dart';

part 'content_item.g.dart';

@HiveType(typeId: 0)
class ContentItem {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String imageUrl;
  @HiveField(3)
  final String? thumbnailUrl;
  @HiveField(4)
  final String sourceName;
  @HiveField(5)
  final bool isGif;
  @HiveField(6)
  final bool isNsfw;
  @HiveField(7)
  final DateTime created;

  ContentItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.sourceName,
    this.isGif = false,
    this.isNsfw = false,
    required this.created,
  });

  factory ContentItem.fromRedditJson(Map<String, dynamic> data, String sourceName) {
    final title = data['title'] ?? 'Untitled';
    String? imageUrl;
    String? thumb;
    final over18 = data['over_18'] ?? false;
    final preview = data['preview']?['images']?[0]?['source']?['url'];
    final thumbData = data['thumbnail'];
    if (preview != null && preview.toString().contains('http')) {
      imageUrl = preview.replaceAll('amp;', '');
    } else {
      imageUrl = data['url'];
    }
    if (thumbData != null && thumbData != 'self' && thumbData != 'nsfw') {
      thumb = thumbData;
    }
    final isGif = imageUrl?.toLowerCase().endsWith('.gif') ?? false;
    if (!RegExp(r'\.(jpg|jpeg|png|webp|gif)$').hasMatch(imageUrl ?? '')) return null!;
    final created = DateTime.fromMillisecondsSinceEpoch((data['created_utc'] ?? 0) * 1000);
    return ContentItem(
      id: data['id'] ?? '',
      title: title,
      imageUrl: imageUrl!,
      thumbnailUrl: thumb,
      sourceName: sourceName,
      isGif: isGif,
      isNsfw: over18,
      created: created,
    );
  }
}
