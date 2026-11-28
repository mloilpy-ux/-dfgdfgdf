enum MediaKind {
  image,
  gif,
  video;

  static MediaKind? fromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    final extension = path.split('.').last;
    return switch (extension) {
      'jpg' || 'jpeg' || 'png' || 'webp' || 'bmp' => image,
      'gif' => gif,
      'mp4' || 'webm' || 'm4v' || 'mov' => video,
      _ => null,
    };
  }
}

class ContentItem {
  final String id;
  final String sourceId;
  final String title;
  final String? author;
  final String mediaUrl;
  final String? thumbnailUrl;
  final MediaKind kind;
  final bool isNsfw;
  final DateTime createdAt;
  final bool isSaved;
  final String? postUrl;

  ContentItem({
    required this.id,
    required this.sourceId,
    required this.title,
    this.author,
    required this.mediaUrl,
    this.thumbnailUrl,
    MediaKind? kind,
    this.isNsfw = false,
    required this.createdAt,
    this.isSaved = false,
    this.postUrl,
  }) : kind = kind ?? MediaKind.fromUrl(mediaUrl) ?? MediaKind.image;

  bool get isGif => kind == MediaKind.gif;
  bool get isVideo => kind == MediaKind.video;
  bool get usesVideoPlayer =>
      isVideo || (isGif && MediaKind.fromUrl(mediaUrl) == MediaKind.video);

  Map<String, String> get mediaHeaders {
    if (!id.startsWith('web_') || postUrl == null) return const {};
    final page = Uri.tryParse(postUrl!);
    if (page == null || page.scheme != 'https' || page.host.isEmpty)
      return const {};
    return {'Referer': '${page.origin}/'};
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sourceId': sourceId,
    'title': title,
    'author': author,
    'mediaUrl': mediaUrl,
    'thumbnailUrl': thumbnailUrl,
    'isGif': isGif ? 1 : 0,
    'mediaKind': kind.name,
    'isNsfw': isNsfw ? 1 : 0,
    'createdAt': createdAt.toIso8601String(),
    'isSaved': isSaved ? 1 : 0,
    'postUrl': postUrl,
  };

  factory ContentItem.fromMap(Map<String, dynamic> map) {
    final mediaUrl = map['mediaUrl'] as String;
    final kind =
        MediaKind.values
            .where((kind) => kind.name == map['mediaKind'])
            .firstOrNull ??
        MediaKind.fromUrl(mediaUrl) ??
        (map['isGif'] == 1 ? MediaKind.gif : MediaKind.image);
    return ContentItem(
      id: map['id'] as String,
      sourceId: map['sourceId'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      mediaUrl: mediaUrl,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      kind: kind,
      isNsfw: map['isNsfw'] == 1,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isSaved: map['isSaved'] == 1,
      postUrl: map['postUrl'] as String?,
    );
  }

  ContentItem copyWith({bool? isSaved}) => ContentItem(
    id: id,
    sourceId: sourceId,
    title: title,
    author: author,
    mediaUrl: mediaUrl,
    thumbnailUrl: thumbnailUrl,
    kind: kind,
    isNsfw: isNsfw,
    createdAt: createdAt,
    isSaved: isSaved ?? this.isSaved,
    postUrl: postUrl,
  );
}
