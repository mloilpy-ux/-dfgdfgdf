import 'package:hive/hive.dart';

part 'content_source.g.dart';

@HiveType(typeId: 1)
enum SourceType { reddit, twitter, telegram }

@HiveType(typeId: 2)
class ContentSource {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String name;
  @HiveField(2)
  final String url;
  @HiveField(3)
  final SourceType type;
  @HiveField(4)
  bool active;
  @HiveField(5)
  bool nsfw;

  ContentSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    this.active = true,
    this.nsfw = false,
  });

  factory ContentSource.fromUrl(String url) {
    SourceType type;
    String sub;
    if (url.contains('reddit.com/r/')) {
      type = SourceType.reddit;
      sub = url.split('/r/')[1].split('/')[0].split('?')[0];
      return ContentSource(id: sub, name: 'r/$sub', url: 'https://www.reddit.com/r/$sub/.json', type: type);
    } else if (url.contains('twitter.com/') || url.contains('x.com/')) {
      type = SourceType.twitter;
      final user = url.split('/').lastWhere((e) => e.isNotEmpty, orElse: () => '');
      return ContentSource(id: user, name: '@$user', url: url, type: type);
    } else if (url.contains('t.me/')) {
      type = SourceType.telegram;
      final channel = url.split('/').last;
      return ContentSource(id: channel, name: channel, url: 'https://t.me/s/$channel', type: type);
    }
    throw Exception('Unsupported URL');
  }
}
