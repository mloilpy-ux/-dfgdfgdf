import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import 'furry_loading.dart';

class MediaVideoPreview extends StatefulWidget {
  const MediaVideoPreview({
    super.key,
    required this.url,
    this.muted = false,
    this.headers = const {},
  });

  final String url;
  final bool muted;
  final Map<String, String> headers;

  @override
  State<MediaVideoPreview> createState() => MediaVideoPreviewState();
}

class MediaVideoPreviewState extends State<MediaVideoPreview> {
  VideoPlayerController? _player;
  late final Future<void> _ready = _initialize();

  Future<void> _initialize() async {
    final cached = await DefaultCacheManager().getFileFromCache(widget.url);
    if (!mounted) return;
    final player = cached != null && await cached.file.exists()
        ? VideoPlayerController.file(cached.file)
        : VideoPlayerController.networkUrl(
            Uri.parse(widget.url),
            httpHeaders: widget.headers,
          );
    _player = player;
    await player.initialize();
    if (!mounted) return;
    await player.setLooping(true);
    if (mounted && widget.muted) await player.setVolume(0);
    if (mounted) await player.play();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Видео недоступно',
              style: TextStyle(color: Colors.white),
            ),
          );
        }
        final player = _player;
        if (snapshot.connectionState != ConnectionState.done ||
            player == null) {
          return const Center(child: FurryLoadingIndicator());
        }

        return Center(
          child: AspectRatio(
            aspectRatio: player.value.aspectRatio,
            child: GestureDetector(
              onTap: () =>
                  player.value.isPlaying ? player.pause() : player.play(),
              child: VideoPlayer(player),
            ),
          ),
        );
      },
    );
  }
}
