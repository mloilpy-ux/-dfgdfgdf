import 'package:flutter/material.dart';
import '../models/content_item.dart';
import '../screens/home_screen.dart';

class SwipeableCard extends StatefulWidget {
  final ContentItem item;
  final int index;
  final int currentIndex;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeUp;

  const SwipeableCard({
    Key? key,
    required this.item,
    required this.index,
    required this.currentIndex,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    required this.onSwipeUp,
  }) : super(key: key);

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> with SingleTickerProviderStateMixin {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  double _angle = 0;

  @override
  Widget build(BuildContext context) {
    final isTop = widget.index == widget.currentIndex;
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      top: isTop ? 20 : 30,
      left: 20,
      right: 20,
      child: GestureDetector(
        onPanStart: isTop ? _onPanStart : null,
        onPanUpdate: isTop ? _onPanUpdate : null,
        onPanEnd: isTop ? _onPanEnd : null,
        onTap: widget.onSwipeUp,
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
                  image: DecorationImage(
                    image: NetworkImage(widget.item.thumbnailUrl ?? widget.item.mediaUrl),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    // Градиент внизу
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
                            colors: [
                              Colors.black.withOpacity(0.8),
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
                              const SizedBox(height: 5),
                              Text(
                                'by ${widget.item.author}',
                                style: TextStyle(color: Colors.white.withOpacity(0.8)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Индикатор свайпа
                    if (_isDragging) ...[
                      if (_position.dx > 50)
                        Positioned(
                          top: 50,
                          right: 50,
                          child: Transform.rotate(
                            angle: -0.3,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.green, width: 3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'LIKE',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_position.dx < -50)
                        Positioned(
                          top: 50,
                          left: 50,
                          child: Transform.rotate(
                            angle: 0.3,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.red, width: 3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NOPE',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                    // NSFW badge
                    if (widget.item.isNsfw)
                      Positioned(
                        top: 20,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'NSFW',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
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

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      _angle = _position.dx / 1000;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    const threshold = 100.0;

    if (_position.dx > threshold) {
      // Свайп вправо - лайк
      _animateCardOff(SwipeDirection.right);
    } else if (_position.dx < -threshold) {
      // Свайп влево - пропустить
      _animateCardOff(SwipeDirection.left);
    } else {
      // Вернуть на место
      _resetPosition();
    }
  }

  void _animateCardOff(SwipeDirection direction) {
    final screenWidth = MediaQuery.of(context).size.width;
    final target = direction == SwipeDirection.right ? screenWidth * 2 : -screenWidth * 2;

    setState(() {
      _position = Offset(target, _position.dy);
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (direction == SwipeDirection.right) {
        widget.onSwipeRight();
      } else {
        widget.onSwipeLeft();
      }
      _resetPosition();
    });
  }

  void _resetPosition() {
    setState(() {
      _position = Offset.zero;
      _angle = 0;
    });
  }
}
