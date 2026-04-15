import 'package:flutter/material.dart';
import 'dart:math' show pi, cos, sin;

class BitcoinLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const BitcoinLoadingIndicator({
    super.key,
    this.size = 40,
    this.color = const Color(0xFF84BD00),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<BitcoinLoadingIndicator> createState() => _BitcoinLoadingIndicatorState();
}

class _BitcoinLoadingIndicatorState extends State<BitcoinLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        final rotation = _rotationController.value * 2 * pi;

        return Transform.rotate(
          angle: rotation,
          child: Image.asset(
            'assets/images/x.png',
            width: widget.size,
            height: widget.size,
          ),
        );
      },
    );
  }
}

class CenterBitcoinLoading extends StatelessWidget {
  final double size;
  final Color color;
  final String? message;

  const CenterBitcoinLoading({
    super.key,
    this.size = 50,
    this.color = const Color(0xFF84BD00),
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BitcoinLoadingIndicator(size: size, color: color),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: color.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class FullScreenBitcoinLoading extends StatelessWidget {
  final Color color;
  final String? message;
  final Color backgroundColor;

  const FullScreenBitcoinLoading({
    super.key,
    this.color = const Color(0xFF84BD00),
    this.message,
    this.backgroundColor = const Color(0xFF0D0D0D),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: CenterBitcoinLoading(
        size: 60,
        color: color,
        message: message,
      ),
    );
  }
}

class OtpLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const OtpLoadingIndicator({
    super.key,
    this.size = 40,
    this.color = const Color(0xFF84BD00),
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<OtpLoadingIndicator> createState() => _OtpLoadingIndicatorState();
}

class _OtpLoadingIndicatorState extends State<OtpLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final innerSize = widget.size * 0.9;
    final iconSize = widget.size * 0.55;
    final dotSize = widget.size * 0.125;
    final orbitRadius = widget.size * 0.425;

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        final rotation = _rotationController.value * 2 * 3.14159;
        final scale = 0.8 + (_pulseController.value * 0.2);

        return Transform.scale(
          scale: scale,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color,
                    widget.color.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.5 + (_pulseController.value * 0.3)),
                    blurRadius: widget.size * 0.375 + (_pulseController.value * widget.size * 0.25),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: innerSize,
                    height: innerSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -rotation,
                    child: Icon(
                      Icons.lock_outline,
                      color: widget.color,
                      size: iconSize,
                    ),
                  ),
                  ...List.generate(4, (index) {
                    double angle = (index * 3.14159 / 2) + rotation;
                    return Transform.translate(
                      offset: Offset(
                        orbitRadius * cos(angle),
                        orbitRadius * sin(angle),
                      ),
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
