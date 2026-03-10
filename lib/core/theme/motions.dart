import 'package:flutter/animation.dart';

class Motions {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 190);
  static const Duration slow = Duration(milliseconds: 220);

  static const Curve ease = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
}
