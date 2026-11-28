import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/content_item.dart';
import '../widgets/media_video_preview.dart';

class MediaViewer extends StatelessWidget {
  const MediaViewer({super.key, required this.item});
  final ContentItem item;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Просмотр')),
    body: SizedBox.expand(
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 6,
        child: Center(
          child: item.usesVideoPlayer
              ? MediaVideoPreview(
                  url: item.mediaUrl,
                  muted: item.isGif,
                  headers: item.mediaHeaders,
                )
              : CachedNetworkImage(
                  imageUrl: item.mediaUrl,
                  httpHeaders: item.mediaHeaders,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined),
                ),
        ),
      ),
    ),
  );
}
