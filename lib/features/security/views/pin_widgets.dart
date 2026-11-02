import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The four dots that show how many PIN digits have been entered.
class PinDots extends StatelessWidget {
  const PinDots({required this.filled, this.hasError = false, super.key});

  final int filled;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError ? colors.error : colors.primary)
                : Colors.transparent,
            border: Border.all(
              color: hasError ? colors.error : colors.outline,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }
}

/// A reusable number pad that does not open the system keyboard.
class PinPad extends StatelessWidget {
  const PinPad({
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    super.key,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ]) ...[
          _NumberRow(numbers: row, onDigit: onDigit),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: _PinActionButton(
                onPressed: onBiometric,
                icon: Icons.fingerprint_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: _NumberButton(number: 0, onDigit: onDigit)),
            const SizedBox(width: 10),
            Expanded(
              child: _PinActionButton(
                onPressed: onBackspace,
                icon: Icons.backspace_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PinActionButton extends StatelessWidget {
  const _PinActionButton({required this.onPressed, required this.icon});

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: onPressed == null ? const SizedBox.shrink() : Icon(icon),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({required this.numbers, required this.onDigit});

  final List<int> numbers;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < numbers.length; index++) ...[
          Expanded(
            child: _NumberButton(number: numbers[index], onDigit: onDigit),
          ),
          if (index < numbers.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _NumberButton extends StatelessWidget {
  const _NumberButton({required this.number, required this.onDigit});

  final int number;
  final ValueChanged<int> onDigit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: FilledButton.tonal(
        onPressed: () {
          HapticFeedback.selectionClick();
          onDigit(number);
        },
        child: Text(
          number.toString(),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
