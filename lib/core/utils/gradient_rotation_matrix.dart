import 'package:flutter/material.dart';

class GradientRotationMatrix extends GradientTransform {
  const GradientRotationMatrix();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final side = bounds.shortestSide;

    if (side <= 0) return Matrix4.identity();

    final gradientToNormalized = Matrix4.fromList([
      -0.1755223423242569,
      -0.6230636239051819,
      0,
      0,
      0.7802960872650146,
      -0.6569625735282898,
      0,
      0,
      0,
      0,
      1,
      0,
      0.2057076096534729,
      1.1687465906143188,
      0,
      1,
    ])..invert();

    final circleToNormalized = Matrix4.identity()
      ..translate(0.5 - bounds.center.dx / side, 0.5 - bounds.center.dy / side)
      ..scale(1.0 / side, 1.0 / side);

    // Convert the transformed gradient back into screen coordinates.
    return Matrix4.identity()
      ..translate(bounds.left, bounds.top)
      ..scale(bounds.width, bounds.height)
      ..multiply(gradientToNormalized)
      ..multiply(circleToNormalized);
  }
}
