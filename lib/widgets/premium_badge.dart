import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _crownSvg = '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="crown_grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#FFE07D" />
      <stop offset="50%" stop-color="#F1B404" />
      <stop offset="100%" stop-color="#8B6508" />
    </linearGradient>
  </defs>
  <path d="M4 17.5c4 .8 12 .8 16 0" stroke="url(#crown_grad)" stroke-width="1.2" stroke-linecap="round"/>
  <path d="M4 17L2.5 9.5L7.5 12L12 4L16.5 12L21.5 9.5L20 17H4z" fill="url(#crown_grad)"/>
  <path d="M12 11l2 2.5l-2 2.5l-2-2.5z" fill="#FFFFFF"/>
  <circle cx="2.5" cy="9.5" r="0.9" fill="#FFE07D" stroke="#8B6508" stroke-width="0.3"/>
  <circle cx="7.5" cy="12.0" r="0.8" fill="#FFE07D" stroke="#8B6508" stroke-width="0.3"/>
  <circle cx="12.0" cy="4.0" r="1.1" fill="#FFE07D" stroke="#8B6508" stroke-width="0.3"/>
  <circle cx="16.5" cy="12.0" r="0.8" fill="#FFE07D" stroke="#8B6508" stroke-width="0.3"/>
  <circle cx="21.5" cy="9.5" r="0.9" fill="#FFE07D" stroke="#8B6508" stroke-width="0.3"/>
</svg>
''';

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
    final activeRadius = borderRadius ?? BorderRadius.circular(30);

    return Container(
      padding: const EdgeInsets.all(1.0), // Outer gold border thickness
      decoration: BoxDecoration(
        borderRadius: activeRadius,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF1B404), // Bright gold
            Color(0xFF8B6508), // Darker bronze gold
            Color(0xFFFFDF00), // Pure golden shine
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            spreadRadius: 0.1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(0.8), // Thin dark space gap
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F), // Sleek black inner gap
          borderRadius: activeRadius,
        ),
        child: Container(
          padding: const EdgeInsets.all(0.8), // Inner gold border thickness
          decoration: BoxDecoration(
            borderRadius: activeRadius,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFE07D), // Warm golden highlight
                Color(0xFFD4AF37), // Metallic gold accent
                Color(0xFF705305), // Deep shadow gold
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            padding: padding, // Custom padding for spacing
            decoration: BoxDecoration(
              color: const Color(0xFF080808), // Solid premium black center body
              borderRadius: activeRadius,
            ),
            child: SvgPicture.string(
              _crownSvg,
              width: iconSize * 1.35,
              height: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
