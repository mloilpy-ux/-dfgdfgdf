import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/content_item.dart';

class ContentCard extends StatefulWidget {
  final ContentItem item;
  final VoidCallback? onTap;

  const ContentCard({
    Key? key,
    required this.item,
    this.onTap,
  }) : super(key: key);

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _initVideoPlayer();
    }
  }

  bool get _isVideo => widget.item.mediaUrl.contains('.mp4') || 
                       widget.item.mediaUrl.contains('.webm');

  void _initVideoPlayer() {
    _videoController = VideoPlayerController.network(widget.item.mediaUrl)
      ..initialize().then((_) {
        if (mounted) {
          _videoController?.play();
          _videoController?.setLooping(true);
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Медиа контент
              _buildMediaWidget(),
              
              // Градиент снизу
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item.author != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.orange, size: 16),
                            const SizedBox(width: 5),
                            Text(
                              widget.item.author!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Badges
              Positioned(
                top: 16,
                left: 16,
                child: Row(
                  children: [
                    if (widget.item.isNsfw) _buildBadge('NSFW', Colors.red),
                    if (_isVideo) _buildBadge('VIDEO', Colors.purple),
                    if (widget.item.isGif) _buildBadge('GIF', Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaWidget() {
    if (_isVideo && _videoController != null && _videoController!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController!.value.size.width,
            height: _videoController!.value.size.height,
            child: VideoPlayer(_videoController!),
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: widget.item.thumbnailUrl ?? widget.item.mediaUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.error, size: 50, color: Colors.red),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
