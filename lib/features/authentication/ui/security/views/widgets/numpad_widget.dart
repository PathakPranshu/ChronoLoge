import 'dart:ui';
import 'package:flutter/material.dart';

class NumpadWidget extends StatelessWidget {
  final Function(int) onNumberTapped;
  final VoidCallback onBackspaceTapped;
  final bool hasBiometrics;
  final VoidCallback? onBiometricTapped;

  const NumpadWidget({
    super.key,
    required this.onNumberTapped,
    required this.onBackspaceTapped,
    this.hasBiometrics = false,
    this.onBiometricTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, [1, 2, 3]),
        const SizedBox(height: 12),
        _buildRow(context, [4, 5, 6]),
        const SizedBox(height: 12),
        _buildRow(context, [7, 8, 9]),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox(
              width: 104,
              height: 64,
              child: hasBiometrics 
                  ? _buildActionButton(context, Icons.fingerprint, onBiometricTapped ?? () {}) 
                  : null,
            ),
            _buildNumberButton(context, 0),
            SizedBox(
              width: 104,
              height: 64,
              child: _buildActionButton(context, Icons.backspace_rounded, onBackspaceTapped, size: 24),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<int> numbers) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers.map((number) => _buildNumberButton(context, number)).toList(),
    );
  }

  Widget _buildNumberButton(BuildContext context, int number) {
    final colorTheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => onNumberTapped(number),
      onTapDown: (details) => Feedback.forTap(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            width: 104,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorTheme.surfaceContainerLowest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorTheme.outline.withValues(alpha: 0.2),
                width: 1.0,
              ),
            ),
            child: Text(
              number.toString(),
              style: textTheme.headlineMedium?.copyWith(
                color: colorTheme.onSurface,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, VoidCallback onTap, {double size = 32}) {
    final colorTheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: size, color: colorTheme.onSurface),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}