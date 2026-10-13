import 'dart:math';

import 'package:flutter/material.dart';

class PinIndicator extends StatefulWidget {
  final int length;
  final bool hasError;
  final int currentLength;

  const PinIndicator({
    super.key,
    this.length = 4,
    required this.currentLength,
    this.hasError = false,
  });

  @override
  State<PinIndicator> createState() => _PinIndicatorState();
}

class _PinIndicatorState extends State<PinIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(PinIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation and haptic feedback when error state activates
    if (widget.hasError && !oldWidget.hasError) {
      _shakeAndVibrate();
    }
  }

  void _shakeAndVibrate() {
    Feedback.forLongPress(context);
    Future.delayed(const Duration(milliseconds: 200));
    Feedback.forLongPress(context);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorTheme = Theme.of(context).colorScheme;

    // Calculate a horizontal shake offset using a sine wave
    // Multiplying by pi * 4 creates 2 full back-and-forth shakes.
    // Multiplying by 10 determines the maximum pixel distance of the shake.
    final shakeOffset = sin(_animation.value * pi * 4) * 10;

    return Transform.translate(
      offset: Offset(shakeOffset, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.length, (index) {
          final isFilled = index < widget.currentLength;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled
                  ? widget.hasError
                        ? colorTheme.error
                        : colorTheme.onSurface
                  : Colors.transparent,
              border: Border.all(
                color: isFilled
                    ? widget.hasError
                          ? colorTheme.error
                          : colorTheme.onSurface
                    : colorTheme.outline,
                width: 1.5,
              ),
            ),
          );
        }),
      ),
    );
  }
}
