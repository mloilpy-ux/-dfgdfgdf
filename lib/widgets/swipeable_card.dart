import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:wallpaper_manager_flutter/wallpaper_manager_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/content_item.dart';

class SwipeableCard extends StatefulWidget {
  final ContentItem item;
  final int index;
  final int currentIndex;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const SwipeableCard({
    Key? key,
    required this.item,
    required this.index,
    required this.currentIndex,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  }) : super(key: key);

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  double _angle = 0;
  VideoPlayerController? _videoController;
  bool _isSettingWallpaper = false;

  @override
  void initState() {
    super.initState();
    if (_isVideo) _initVideoPlayer();
  }

  bool get _isVideo => widget.item.mediaUrl.contains('.mp4');

  void _initVideoPlayer() {
    _videoController = VideoPlayerController.network(widget.item.mediaUrl)
      ..initialize().then((_) {
        if (mounted && widget.index == widget.currentIndex) {
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
    final isTop = widget.index == widget.currentIndex;
    final screenSize = MediaQuery.of(context).size;

    if (_videoController != null && _videoController!.value.isInitialized) {
      if (isTop && !_videoController!.value.isPlaying) {
        _videoController?.play();
      } else if (!isTop && _videoController!.value.isPlaying) {
        _videoController?.pause();
      }
    }

    return Positioned(
      top: isTop ? 20 : 30,
      left: 20,
      right: 20,
      child: GestureDetector(
        onPanStart: isTop ? (details) => setState(() => _isDragging = true) : null,
        onPanUpdate: isTop ? (details) => setState(() {
          _position += details.delta;
          _angle = _position.dx / 1000;
        }) : null,
        onPanEnd: isTop ? _onPanEnd : null,
        child: Transform.translate(
          offset: _position,
          child: Transform.rotate(
            angle: _angle,
            child: Card(
              elevation: isTop ? 10 : 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                height: screenSize.height * 0.65,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.black,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _buildMediaWidget(),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                          ),
                        ),
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          maxLines: 2,
                        ),
                      ),
                    ),
                    if (!_isVideo && !widget.item.isGif)
                      Positioned(
                        bottom: 100,
                        right: 20,
                        child: FloatingActionButton(
                          heroTag: 'wallpaper_${widget.item.id}',
                          mini: true,
                          backgroundColor: Colors.white,
                          onPressed: _setWallpaper,
                          child: _isSettingWallpaper
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.wallpaper, color: Colors.black),
                        ),
                      ),
                    if (_isDragging) ..._buildSwipeIndicators(),
                    if (widget.item.isNsfw)
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                          child: const Text('NSFW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, size: 50, color: Colors.red)),
    );
  }

  List<Widget> _buildSwipeIndicators() {
    return [
      if (_position.dx > 50)
        Positioned(
          top: 50,
          right: 50,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(border: Border.all(color: Colors.green, width: 4), borderRadius: BorderRadius.circular(10)),
            child: const Text('LIKE', style: TextStyle(color: Colors.green, fontSize: 35, fontWeight: FontWeight.bold)),
          ),
        ),
      if (_position.dx < -50)
        Positioned(
          top: 50,
          left: 50,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 4), borderRadius: BorderRadius.circular(10)),
            child: const Text('NOPE', style: TextStyle(color: Colors.red, fontSize: 35, fontWeight: FontWeight.bold)),
          ),
        ),
    ];
  }

  Future<void> _setWallpaper() async {
    setState(() => _isSettingWallpaper = true);

    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showMessage('Требуется разрешение');
        return;
      }

      final location = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Установить обои'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Главный экран'),
                onTap: () => Navigator.pop(context, WallpaperManagerFlutter.HOME_SCREEN),
              ),
              ListTile(
                leading: const Icon(Icons.lock),
                title: const Text('Экран блокировки'),
                onTap: () => Navigator.pop(context, WallpaperManagerFlutter.LOCK_SCREEN),
              ),
              ListTile(
                leading: const Icon(Icons.phone_android),
                title: const Text('Оба экрана'),
                onTap: () => Navigator.pop(context, WallpaperManagerFlutter.BOTH_SCREENS),
              ),
            ],
          ),
        ),
      );

      if (location == null) return;

      await WallpaperManagerFlutter().setwallpaperfromUrl(widget.item.mediaUrl, location);
      _showMessage('✅ Обои установлены!');
      
    } catch (e) {
      _showMessage('❌ Ошибка: $e');
    } finally {
      if (mounted) setState(() => _isSettingWallpaper = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    if (_position.dx > 100) {
      _animateOff(true);
    } else if (_position.dx < -100) {
      _animateOff(false);
    } else {
      setState(() {
        _position = Offset.zero;
        _angle = 0;
      });
    }
  }

  void _animateOff(bool isRight) {
    final screenWidth = MediaQuery.of(context).size.width;
    setState(() => _position = Offset(isRight ? screenWidth * 2 : -screenWidth * 2, _position.dy));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (isRight) {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      if (mounted) setState(() {
        _position = Offset.zero;
        _angle = 0;
      });
    });
  }
}
