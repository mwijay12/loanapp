import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/motion/motion.dart';

enum AiState { idle, thinking, typing, happy, error }

class AiAssistantCard extends ConsumerStatefulWidget {
  const AiAssistantCard({super.key});

  @override
  ConsumerState<AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends ConsumerState<AiAssistantCard>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _bounceController;
  late AnimationController _pulseController;
  late AnimationController _dotsController;

  late Animation<double> _blinkAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _pulseAnimation;

  AiState _currentState = AiState.idle;
  int _currentMessageIndex = 0;
  String _displayedText = '';
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _messageTimer;
  Timer? _stateTimer;

  final List<String> _messages = [
    'Ask me anything about your inventory.',
    "Need help with today's transactions?",
    'I can help you find a device.',
    'Want to check your stock?',
    'Need a quick report?',
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startMessageRotation();
    // The loops start in didChangeDependencies, not here: whether to run them is a
    // question about the platform's reduce-motion setting, and reading an inherited
    // widget from initState is an error. It also means the card now stops repainting
    // for someone who asked it not to move, instead of pulsing forever behind a
    // static picture.
    _loopsStarted = false;
  }

  void _initAnimations() {
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  bool _loopsStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loopsStarted) return;
    _loopsStarted = true;
    if (!Motion.enabled(context)) return;
    _pulseController.repeat(reverse: true);
    if (_currentState == AiState.thinking) _dotsController.repeat();
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    final delay = Duration(seconds: 2 + (DateTime.now().millisecond % 3));
    Timer(delay, () {
      if (mounted && _currentState == AiState.idle) {
        _blinkController.forward().then((_) {
          _blinkController.reverse().then((_) {
            if (mounted) _scheduleNextBlink();
          });
        });
      } else if (mounted) {
        _scheduleNextBlink();
      }
    });
  }

  void _startMessageRotation() {
    _typeMessage(_messages[_currentMessageIndex]);
  }

  void _typeMessage(String message) {
    setState(() {
      _isTyping = true;
      _displayedText = '';
      _currentState = AiState.typing;
    });

    int charIndex = 0;
    _typingTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (charIndex < message.length) {
        setState(() {
          _displayedText = message.substring(0, charIndex + 1);
        });
        charIndex++;
      } else {
        timer.cancel();
        setState(() {
          _isTyping = false;
          _currentState = AiState.happy;
        });
        _bounceController.forward().then((_) {
          _bounceController.reverse();
        });

        _messageTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _deleteMessage();
          }
        });
      }
    });
  }

  void _deleteMessage() {
    final currentText = _displayedText;
    int charIndex = currentText.length;
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (charIndex > 0) {
        setState(() {
          _displayedText = currentText.substring(0, charIndex - 1);
        });
        charIndex--;
      } else {
        timer.cancel();
        _currentMessageIndex = (_currentMessageIndex + 1) % _messages.length;
        _typeMessage(_messages[_currentMessageIndex]);
      }
    });
  }

  void _onButtonTap() {
    setState(() {
      _currentState = AiState.thinking;
    });
    if (Motion.enabled(context)) _dotsController.repeat();
    _stateTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        context.push('/ai');
      }
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _bounceController.dispose();
    _pulseController.dispose();
    _dotsController.dispose();
    _typingTimer?.cancel();
    _messageTimer?.cancel();
    _stateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E6F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14213D).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildRobotIcon(isReducedMotion),
          const SizedBox(width: 16),
          Expanded(child: _buildTextContent()),
          const SizedBox(width: 12),
          _buildActionButton(isReducedMotion),
        ],
      ),
    );
  }

  Widget _buildRobotIcon(bool isReducedMotion) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, isReducedMotion ? 0 : _bounceAnimation.value),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.pastelLavender,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(
                        alpha: isReducedMotion ? 0.1 : 0.1 + (_pulseAnimation.value - 0.8) * 0.3,
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: child,
          ),
        );
      },
      child: _buildRobotFace(isReducedMotion),
    );
  }

  Widget _buildRobotFace(bool isReducedMotion) {
    return AnimatedBuilder(
      animation: _blinkAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(52, 52),
          painter: _RobotFacePainter(
            blinkValue: _blinkAnimation.value,
            state: _currentState,
            isReducedMotion: isReducedMotion,
          ),
        );
      },
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Need help?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 20,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _displayedText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isTyping) _buildCursor(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCursor() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Container(
            width: 2,
            height: 14,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(bool isReducedMotion) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isReducedMotion ? 1.0 : 0.95 + (_pulseAnimation.value - 0.8) * 0.5,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onButtonTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                const Text(
                  'AI Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                _currentState == AiState.thinking
                    ? _buildThinkingDots()
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThinkingDots() {
    return SizedBox(
      width: 24,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _dotsController,
            builder: (context, child) {
              final delay = index * 0.2;
              final progress = (_dotsController.value + delay) % 1.0;
              final opacity = 0.3 + (0.7 * (1 - (progress - 0.5).abs() * 2));
              return Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _RobotFacePainter extends CustomPainter {
  final double blinkValue;
  final AiState state;
  final bool isReducedMotion;

  _RobotFacePainter({
    required this.blinkValue,
    required this.state,
    required this.isReducedMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final headPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 32, height: 28),
      const Radius.circular(8),
    );
    canvas.drawRRect(headRect, headPaint);

    final antennaPaint = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy - 14),
      Offset(center.dx, center.dy - 20),
      antennaPaint,
    );
    canvas.drawCircle(Offset(center.dx, center.dy - 22), 3, headPaint);

    final eyePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final leftEyeCenter = Offset(center.dx - 7, center.dy - 4);
    final rightEyeCenter = Offset(center.dx + 7, center.dy - 4);

    if (state == AiState.happy) {
      final arcPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: leftEyeCenter, width: 8, height: 6),
        0.2,
        2.7,
        false,
        arcPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(center: rightEyeCenter, width: 8, height: 6),
        0.2,
        2.7,
        false,
        arcPaint,
      );
    } else if (state == AiState.error) {
      canvas.drawCircle(leftEyeCenter, 2.5, eyePaint);
      canvas.drawCircle(rightEyeCenter, 2.5, eyePaint);
    } else {
      final eyeHeight = 4 * blinkValue;
      canvas.drawOval(
        Rect.fromCenter(center: leftEyeCenter, width: 5, height: eyeHeight),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: rightEyeCenter, width: 5, height: eyeHeight),
        eyePaint,
      );
    }

    final mouthPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (state == AiState.happy) {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 6), width: 12, height: 8),
        0.3,
        2.5,
        false,
        mouthPaint,
      );
    } else if (state == AiState.error) {
      canvas.drawLine(
        Offset(center.dx - 5, center.dy + 8),
        Offset(center.dx + 5, center.dy + 8),
        mouthPaint,
      );
    } else if (state == AiState.thinking) {
      canvas.drawCircle(Offset(center.dx, center.dy + 7), 2, mouthPaint);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 5), width: 10, height: 6),
        0.5,
        2.1,
        false,
        mouthPaint,
      );
    }

    if (state == AiState.happy && !isReducedMotion) {
      final sparklePaint = Paint()
        ..color = AppTheme.warningColor.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      _drawSparkle(canvas, Offset(center.dx + 18, center.dy - 18), 4, sparklePaint);
      _drawSparkle(canvas, Offset(center.dx - 18, center.dy - 14), 3, sparklePaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.lineTo(center.dx + size * 0.3, center.dy - size * 0.3);
    path.lineTo(center.dx + size, center.dy);
    path.lineTo(center.dx + size * 0.3, center.dy + size * 0.3);
    path.lineTo(center.dx, center.dy + size);
    path.lineTo(center.dx - size * 0.3, center.dy + size * 0.3);
    path.lineTo(center.dx - size, center.dy);
    path.lineTo(center.dx - size * 0.3, center.dy - size * 0.3);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RobotFacePainter oldDelegate) {
    return oldDelegate.blinkValue != blinkValue ||
        oldDelegate.state != state ||
        oldDelegate.isReducedMotion != isReducedMotion;
  }
}
