import 'package:flutter/material.dart';

class FurryLoadingIndicator extends StatefulWidget {
  const FurryLoadingIndicator({super.key});

  @override
  State<FurryLoadingIndicator> createState() => _FurryLoadingIndicatorState();
}

class _FurryLoadingIndicatorState extends State<FurryLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: List.generate(4, (index) {
                final angle = (index * 90 + _controller.value * 360) * 3.14159 / 180;
                return Transform.translate(
                  offset: Offset(
                    30 * (index % 2 == 0 ? 1 : -1) * _controller.value,
                    30 * (index < 2 ? 1 : -1) * _controller.value,
                  ),
                  child: Transform.rotate(
                    angle: angle,
                    child: const Text('🐾', style: TextStyle(fontSize: 24)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading... OwO',
              style: TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ],
        );
      },
    );
  }
}
