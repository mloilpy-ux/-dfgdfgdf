import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ДЛЯ ВИБРАЦИИ
import 'package:provider/provider.dart';
import 'package:wallpaper_manager_plus/wallpaper_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart'; // flutter pub add share_plus
import 'dart:math' as math;
import '../providers/content_provider.dart';
import '../providers/source_provider.dart';
import '../widgets/content_card.dart';
import '../models/content_item.dart';
import 'saved_screen.dart';
import 'sources_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _floatingController;
  late AnimationController _buttonController;
  late AnimationController _likeController;
  late ConfettiController _confettiController;
  bool _showHint = true;
  int _todayViewed = 0;
  DateTime _lastViewDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    
    // ИСПРАВЛЕНИЕ: Правильная инициализация контроллеров
    _floatingController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _likeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    Future.microtask(() {
      context.read<SourceProvider>().loadSources();
      context.read<ContentProvider>().loadNewContent();
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    // ИСПРАВЛЕНИЕ: Правильная очистка ресурсов
    _floatingController.stop();
    _floatingController.dispose();
    _buttonController.dispose();
    _likeController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // НОВАЯ ФИЧА: Тактильная обратная связь
  void _vibrate([HapticFeedbackType type = HapticFeedbackType.light]) {
    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  // НОВАЯ ФИЧА: Двойной тап для лайка
  void _onDoubleTap(ContentProvider provider) {
    _vibrate(HapticFeedbackType.medium);
    _likeController.forward().then((_) => _likeController.reverse());
    _confettiController.play();
    _nextImage(provider, true);
  }

  // НОВАЯ ФИЧА: Статистика просмотров
  void _updateStats() {
    final today = DateTime.now();
    if (_lastViewDate.day != today.day) {
      _todayViewed = 0;
      _lastViewDate = today;
    }
    setState(() => _todayViewed++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildContent()),
                _buildBottomBar(),
              ],
            ),
          ),

          if (_showHint) _buildSwipeHint(),
          
          // НОВАЯ ФИЧА: Конфетти при лайке
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.orange, Colors.pink, Colors.purple, Colors.blue],
              numberOfParticles: 30,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepOrange.withOpacity(0.1),
                Colors.black,
                Colors.purple.withOpacity(0.1),
              ],
              stops: [
                0.0,
                0.5 + _floatingController.value * 0.1,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _floatingController.value * 0.2,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Text('🐾', style: TextStyle(fontSize: 28)),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.orange, Colors.pink],
                  ).createShader(bounds),
                  child: const Text(
                    'Furry Hub',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // НОВАЯ ФИЧА: Показ статистики
                Row(
                  children: [
                    Text(
                      'Сегодня: $_todayViewed 👁️',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Consumer<ContentProvider>(
                      builder: (context, provider, _) => Text(
                        '• ${provider.filteredItems.length} новых',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildIconButton(
            icon: Icons.source,
            gradient: const [Colors.blue, Colors.cyan],
            onTap: () {
              _vibrate();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SourcesScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.filter_alt,
            gradient: const [Colors.purple, Colors.pink],
            onTap: () {
              _vibrate();
              _showFilterMenu();
            },
          ),
          const SizedBox(width: 8),
          _buildIconButton(
            icon: Icons.settings,
            gradient: const [Colors.orange, Colors.deepOrange],
            onTap: () {
              _vibrate();
              _showSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        _buttonController.forward().then((_) => _buttonController.reverse());
        onTap();
      },
      borderRadius: BorderRadius.circular(15),
      child: AnimatedBuilder(
        animation: _buttonController,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 - (_buttonController.value * 0.1),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: gradient.first.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<ContentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.filteredItems.isEmpty) {
          return _buildLoadingState();
        }

        if (provider.filteredItems.isEmpty) {
          return _buildEmptyState(provider);
        }

        // ИСПРАВЛЕНИЕ: Безопасная проверка индекса
        if (_currentIndex >= provider.filteredItems.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex = 0);
          });
          return const SizedBox.shrink();
        }

        final item = provider.filteredItems[_currentIndex];

        return GestureDetector(
          // НОВАЯ ФИЧА: Двойной тап для лайка
          onDoubleTap: () => _onDoubleTap(provider),
          
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! > 500) {
              _vibrate(HapticFeedbackType.medium);
              _nextImage(provider, true);
            } else if (details.primaryVelocity! < -500) {
              _vibrate(HapticFeedbackType.light);
              _nextImage(provider, false);
            }
          },
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity! < -500) {
              _vibrate();
              _showFullscreen(item);
            }
          },
          onLongPress: () {
            _vibrate(HapticFeedbackType.heavy);
            _showQuickMenu(item, provider);
          },
          child: Column(
            children: [
              _buildProgressBar(provider),
              Expanded(
                child: Stack(
                  children: [
                    _buildMainCard(item),
                    _buildQuickActions(item),
                    // НОВАЯ ФИЧА: Анимация лайка при двойном тапе
                    Center(
                      child: AnimatedBuilder(
                        animation: _likeController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _likeController.value * 3,
                            child: Opacity(
                              opacity: 1.0 - _likeController.value,
                              child: const Text('💖', style: TextStyle(fontSize: 100)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _floatingController.value * 2 * math.pi,
                child: const Text('🐾', style: TextStyle(fontSize: 100)),
              );
            },
          ),
          const SizedBox(height: 30),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.orange, Colors.pink],
            ).createShader(bounds),
            child: const Text(
              'Загружаем мимимишки...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ContentProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatingController.value * 20),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.withOpacity(0.3), Colors.teal.withOpacity(0.1)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('✨', style: TextStyle(fontSize: 80)),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.green, Colors.teal],
              ).createShader(bounds),
              child: const Text(
                'Весь контент просмотрен!',
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Просмотрено сегодня: $_todayViewed 🎉',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 40),
            _buildGradientButton(
              label: '🔄 Загрузить ещё',
              gradient: const [Colors.orange, Colors.deepOrange],
              onPressed: () {
                _vibrate();
                if (mounted) {
                  setState(() => _currentIndex = 0);
                  provider.loadNewContent();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ContentProvider provider) {
    final total = provider.filteredItems.length;
    final current = _currentIndex + 1;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
              shape: BoxShape.circle,
            ),
            child: const Text('👁️', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Прогресс',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$current / $total',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: current / total,
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation(Colors.orange),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(ContentItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Hero(
        tag: 'content_${item.id}',
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                ContentCard(
                  key: ValueKey(item.id),
                  item: item,
                  onTap: () => _showFullscreen(item),
                ),
                
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
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.author != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text('🎨', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.author!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 20,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.isNsfw) _buildBadge('🔞 NSFW', Colors.red),
                      if (item.isGif) _buildBadge('🎬 GIF', Colors.orange),
                      if (item.mediaUrl.contains('.mp4')) _buildBadge('▶️ VIDEO', Colors.purple),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
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

  Widget _buildQuickActions(ContentItem item) {
    final isVideo = item.mediaUrl.contains('.mp4') || item.mediaUrl.contains('.webm');
    final showWallpaper = !item.isGif && !isVideo;

    return Positioned(
      right: 20,
      top: 100,
      child: Column(
        children: [
          if (showWallpaper)
            _buildQuickActionButton(
              icon: '🖼️',
              gradient: const [Colors.blue, Colors.cyan],
              onTap: () {
                _vibrate();
                _setWallpaper(item);
              },
            ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: '📤',
            gradient: const [Colors.green, Colors.teal],
            onTap: () {
              _vibrate();
              _shareContent(item);
            },
          ),
          const SizedBox(height: 12),
          _buildQuickActionButton(
            icon: 'ℹ️',
            gradient: const [Colors.purple, Colors.pink],
            onTap: () {
              _vibrate();
              _showInfo(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Text(icon, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Consumer<ContentProvider>(
      builder: (context, provider, _) {
        if (provider.filteredItems.isEmpty) return const SizedBox.shrink();
        
        final item = provider.filteredItems[_currentIndex];
        final isVideo = item.mediaUrl.contains('.mp4') || item.mediaUrl.contains('.webm');
        final showWallpaper = !item.isGif && !isVideo;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.8),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: _buildMainButton(
                    icon: '👎',
                    label: 'Пропустить',
                    gradient: [Colors.grey[700]!, Colors.grey[900]!],
                    onPressed: () {
                      _vibrate(HapticFeedbackType.light);
                      _nextImage(provider, false);
                    },
                  ),
                ),
                
                const SizedBox(width: 12),
                
                if (showWallpaper) ...[
                  Expanded(
                    child: _buildMainButton(
                      icon: '🖼️',
                      label: 'Обои',
                      gradient: [Colors.blue[700]!, Colors.blue[900]!],
                      onPressed: () {
                        _vibrate();
                        _setWallpaper(item);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                
                Expanded(
                  child: _buildMainButton(
                    icon: '💖',
                    label: 'Сохранить',
                    gradient: [Colors.pink[700]!, Colors.pink[900]!],
                    onPressed: () {
                      _vibrate(HapticFeedbackType.medium);
                      _confettiController.play();
                      _nextImage(provider, true);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainButton({
    required String icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _buttonController.forward().then((_) => _buttonController.reverse());
          onPressed();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _buttonController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 - (_buttonController.value * 0.05),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: gradient.first.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSwipeHint() {
    return Positioned(
      bottom: 200,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Opacity(
            opacity: 1.0 - (_floatingController.value * 0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '💡 Подсказка',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👆👆', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 8),
                        Text(
                          'Двойной тап - Сохранить',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('👇', style: TextStyle(fontSize: 24)),
                        SizedBox(width: 8),
                        Text(
                          'Долгое нажатие - Меню',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    required List<Color> gradient,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _nextImage(ContentProvider provider, bool save) {
    if (_currentIndex >= provider.filteredItems.length) return;
    
    final item = provider.filteredItems[_currentIndex];

    if (save) {
      provider.saveItem(item);
      _showSnackBar('💖 Сохранено в галерею!', Colors.green);
    } else {
      provider.markAsSeen(item.id);
    }

    _updateStats();

    // ИСПРАВЛЕНИЕ: Безопасный setState
    if (mounted) {
      setState(() {
        _currentIndex++;
        
        if (_currentIndex >= provider.filteredItems.length) {
          _currentIndex = 0;
          provider.loadNewContent();
        } else if (_currentIndex >= provider.filteredItems.length - 3) {
          provider.loadNewContent();
        }
      });
    }
  }

  // НОВАЯ ФИЧА: Быстрое меню по долгому нажатию
  void _showQuickMenu(ContentItem item, ContentProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.black],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚡ Быстрые действия',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildQuickMenuItem(Icons.favorite, 'Сохранить', Colors.pink, () {
              Navigator.pop(context);
              _nextImage(provider, true);
            }),
            _buildQuickMenuItem(Icons.wallpaper, 'Установить обои', Colors.blue, () {
              Navigator.pop(context);
              _setWallpaper(item);
            }),
            _buildQuickMenuItem(Icons.share, 'Поделиться', Colors.green, () {
              Navigator.pop(context);
              _shareContent(item);
            }),
            _buildQuickMenuItem(Icons.info, 'Информация', Colors.purple, () {
              Navigator.pop(context);
              _showInfo(item);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickMenuItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), Colors.transparent],
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setWallpaper(ContentItem item) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      _showSnackBar('⚠️ Требуется разрешение', Colors.red);
      return;
    }

    final location = await showDialog<int>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[900]!, Colors.black],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '🖼️ Установить обои',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildWallpaperOption(Icons.home, 'Главный экран', 1),
              const SizedBox(height: 12),
              _buildWallpaperOption(Icons.lock, 'Экран блокировки', 2),
              const SizedBox(height: 12),
              _buildWallpaperOption(Icons.phone_android, 'Оба экрана', 3),
            ],
          ),
        ),
      ),
    );

    if (location != null && mounted) {
      _applyWallpaper(item, location);
    }
  }

  Widget _buildWallpaperOption(IconData icon, String title, int location) {
    return InkWell(
      onTap: () {
        _vibrate();
        Navigator.pop(context, location);
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.withOpacity(0.3), Colors.deepOrange.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange, size: 28),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyWallpaper(ContentItem item, int location) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.grey[900]!, Colors.black]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _floatingController.value * 2 * math.pi,
                    child: const Text('🎨', style: TextStyle(fontSize: 50)),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Устанавливаем обои...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await WallpaperManagerPlus().setWallpaper(item.mediaUrl, location);
      
      if (mounted) {
        Navigator.pop(context);
        _vibrate(HapticFeedbackType.heavy);
        _showSnackBar('✅ Обои установлены!', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('❌ Ошибка: $e', Colors.red);
      }
    }
  }

  // НОВАЯ ФИЧА: Реальный шаринг через share_plus
  void _shareContent(ContentItem item) async {
    try {
      await Share.share(
        '🐾 Смотри какой крутой арт!\n\n${item.title}\n\n${item.mediaUrl}',
        subject: 'Арт из Furry Hub',
      );
    } catch (e) {
      _showSnackBar('❌ Ошибка шаринга', Colors.red);
    }
  }

  void _showInfo(ContentItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              item.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (item.author != null) ...[
              const SizedBox(height: 10),
              Text(
                '🎨 ${item.author}',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.black],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎯 Фильтры',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Consumer<ContentProvider>(
              builder: (context, provider, _) => Column(
                children: ContentType.values.map((type) {
                  final isSelected = provider.contentType == type;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        _vibrate();
                        if (mounted) {
                          setState(() => _currentIndex = 0);
                        }
                        provider.setContentType(type);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isSelected
                                ? [Colors.orange, Colors.deepOrange]
                                : [Colors.grey[800]!, Colors.grey[900]!],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getTypeIcon(type),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _getTypeName(type),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[900]!, Colors.black],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚙️ Настройки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Consumer<ContentProvider>(
              builder: (context, provider, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.withOpacity(0.3), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SwitchListTile(
                  title: const Text(
                    '🔞 Показывать NSFW',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('18+ контент', style: TextStyle(color: Colors.grey)),
                  value: provider.showNsfw,
                  onChanged: (value) {
                    _vibrate();
                    provider.toggleNsfwFilter();
                  },
                  activeColor: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                _vibrate();
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedScreen()),
                );
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink.withOpacity(0.3), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.collections, color: Colors.pink, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Сохранённые',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Consumer<ContentProvider>(
                      builder: (context, provider, _) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.pink, Colors.purple]),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: Text(
                          '${provider.savedItems.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreen(ContentItem item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => FullscreenViewer(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.all:
        return '🌟';
      case ContentType.images:
        return '🖼️';
      case ContentType.gifs:
        return '🎬';
      case ContentType.videos:
        return '▶️';
    }
  }

  String _getTypeName(ContentType type) {
    switch (type) {
      case ContentType.all:
        return 'Всё';
      case ContentType.images:
        return 'Картинки';
      case ContentType.gifs:
        return 'GIF-анимации';
      case ContentType.videos:
        return 'Видео';
    }
  }
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}

class FullscreenViewer extends StatelessWidget {
  final ContentItem item;

  const FullscreenViewer({Key? key, required this.item}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: Hero(
              tag: 'content_${item.id}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(item.mediaUrl, fit: BoxFit.contain),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
