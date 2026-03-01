import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../shell/main_shell_screen.dart';

class IntroFlowScreen extends StatefulWidget {
  const IntroFlowScreen({super.key});

  @override
  State<IntroFlowScreen> createState() => _IntroFlowScreenState();
}

class _IntroFlowScreenState extends State<IntroFlowScreen> {
  bool _showApp = false;

  void _handleSplashFinished() {
    if (!mounted) return;
    setState(() {
      _showApp = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: KeyedSubtree(
        key: ValueKey<bool>(_showApp),
        child: _showApp
            ? const MainShellScreen()
            : _SplashScreen(onFinished: _handleSplashFinished),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _splashDuration = Duration(milliseconds: 2300);

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _textOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.78,
          end: 1.08,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.08,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    _glowAnimation = Tween<double>(
      begin: 0.15,
      end: 0.42,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.35, 1.0)),
    );

    Future<void>.delayed(_splashDuration, widget.onFinished);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.95),
              Color.lerp(theme.colorScheme.primary, Colors.black, 0.28) ??
                  theme.colorScheme.primary,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _AmbientBubbles(),
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 142,
                          height: 142,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: _glowAnimation.value,
                                ),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 71,
                            backgroundImage: AssetImage(
                              'assets/bullrithm.png',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Text(
                          'Bullrithm',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: _textOpacityAnimation.value,
                        child: Text(
                          'Market Insight in Motion',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onPrimary.withValues(
                              alpha: 0.88,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientBubbles extends StatelessWidget {
  const _AmbientBubbles();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _BubblePainter(
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final points = <Offset>[
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.88, size.height * 0.18),
      Offset(size.width * 0.75, size.height * 0.78),
      Offset(size.width * 0.08, size.height * 0.82),
    ];

    for (var i = 0; i < points.length; i++) {
      final radius = 52 + (i * 14);
      canvas.drawCircle(points[i], radius.toDouble(), paint);
    }

    final arcPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.52),
        radius: math.min(size.width, size.height) * 0.36,
      ),
      0.4,
      1.9,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
