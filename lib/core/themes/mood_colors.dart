import 'package:flutter/material.dart';

@immutable
class MoodColorSet {
  const MoodColorSet({
    required this.iconColor,
    required this.backgroundColor,
    required this.glowColor,
  });

  final Color iconColor;

  final Color backgroundColor;

  // Soft radial glow in the background for Mood selector, and diary screen
  final Color glowColor;

  static MoodColorSet lerp(MoodColorSet a, MoodColorSet b, double t) {
    return MoodColorSet(
      iconColor: Color.lerp(a.iconColor, b.iconColor, t)!,
      backgroundColor: Color.lerp(a.backgroundColor, b.backgroundColor, t)!,
      glowColor: Color.lerp(a.glowColor, b.glowColor, t)!,
    );
  }
}