import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PremiumBadge extends StatelessWidget {
  final double fontSize;
  final double iconSize;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  const PremiumBadge({
    super.key,
    this.fontSize = 9.0,
    this.iconSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Scale up slightly to match the visual footprint of the old circular badge
    final displayHeight = iconSize * 2.5;
    final displayWidth = displayHeight; // The cropped medal is square (aspect ratio ~1.0)

    return SvgPicture.asset(
      'assets/images/premium_logo.svg',
      width: displayWidth,
      height: displayHeight,
      fit: BoxFit.contain,
    );
  }
}
