import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../models/template_element.dart';
import '../../../providers/invitation_provider.dart';
import '../../../utils/image_resolver.dart';

/// A read-only version of DraggableElement for the preview screens.
class StaticElement extends StatelessWidget {
  final TemplateElement element;
  final String activeLanguage;
  final double scaleX;
  final double scaleY;

  const StaticElement({
    super.key,
    required this.element,
    required this.activeLanguage,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!element.isVisible) return const SizedBox.shrink();

    // Hide map icon elements reactively if no map location url has been added by the user
    if (element.id.endsWith('_map_icon')) {
      final provider = Provider.of<InvitationProvider>(context, listen: false);
      final hasMapUrl = provider.elements.any((e) => e.mapUrl != null && e.mapUrl!.isNotEmpty);
      if (!hasMapUrl) {
        return const SizedBox.shrink();
      }
    }

    Widget content = SizedBox(
      width: element.width * scaleX,
      height: element.height * scaleY,
      child: _buildContent(context),
    );

    // Make map elements clickable in preview
    if (element.mapUrl != null && element.mapUrl!.isNotEmpty) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          try {
            await launchUrlString(
              element.mapUrl!,
              mode: LaunchMode.externalApplication,
            );
          } catch (_) {}
        },
        child: content,
      );
    }

    return Positioned(
      left: element.x * scaleX,
      top: element.y * scaleY,
      child: Transform.rotate(
        angle: element.rotation * 3.14159 / 180,
        child: Opacity(
          opacity: element.opacity,
          child: content,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (element.id.contains('_map_icon')) {
      return GoogleMapsIconWidget(size: element.height * scaleY);
    }
    switch (element.type) {
      case ElementType.text:
        return Container(
          alignment: _getAlignment(),
          padding: EdgeInsets.zero,
          child: Text(
            element.getDisplayText(activeLanguage),
            textAlign: element.textAlign,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: element.getTextStyle(scale: scaleX),
          ),
        );

      case ElementType.image:
      case ElementType.sticker:
        {
          final idLower = element.id.toLowerCase();
          final pathLower = (element.assetPath ?? '').toLowerCase();
          if (idLower.contains('ganesh') || pathLower.contains('ganesh')) {
            final provider = Provider.of<InvitationProvider>(context, listen: true);
            if (provider.logo.type == LogoType.customSvg) {
              if (provider.logo.rawSvgContent != null) {
                return SvgPicture.string(
                  provider.logo.rawSvgContent!,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                  fit: BoxFit.contain,
                );
              } else {
                final String? path = provider.logo.customSvgPath ?? element.assetPath;
                if (path != null && path.isNotEmpty) {
                  if (path.startsWith('http://') || path.startsWith('https://')) {
                    return SvgPicture.network(
                      path,
                      width: element.width * scaleX,
                      height: element.height * scaleY,
                      fit: BoxFit.contain,
                    );
                  }
                  if (path.contains('assets/')) {
                    final clean = cleanAssetPath(path);
                    if (isNetworkImage(clean)) {
                      return SvgPicture.network(
                        resolveImageUrl(clean),
                        width: element.width * scaleX,
                        height: element.height * scaleY,
                        fit: BoxFit.contain,
                      );
                    } else {
                      return SvgPicture.asset(
                        clean,
                        width: element.width * scaleX,
                        height: element.height * scaleY,
                        fit: BoxFit.contain,
                      );
                    }
                  }
                  return SvgPicture.file(
                    File(path),
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                    fit: BoxFit.contain,
                  );
                }
              }
            } else if (provider.logo.type == LogoType.customFile && provider.logo.customFilePath != null) {
              final String path = provider.logo.customFilePath!;
              if (path.startsWith('http://') || path.startsWith('https://')) {
                return Image.network(
                  path,
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                );
              }
              if (path.contains('assets/')) {
                final clean = cleanAssetPath(path);
                if (isNetworkImage(clean)) {
                  return Image.network(
                    resolveImageUrl(clean),
                    fit: BoxFit.contain,
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                  );
                } else {
                  return Image.asset(
                    clean,
                    fit: BoxFit.contain,
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                  );
                }
              }
              return Image.file(
                File(path),
                fit: BoxFit.contain,
                width: element.width * scaleX,
                height: element.height * scaleY,
              );
            } else {
              final String? path = provider.logo.presetAsset ?? element.assetPath;
              if (path != null && path.isNotEmpty) {
                if (path.startsWith('http://') || path.startsWith('https://')) {
                  return Image.network(
                    path,
                    fit: BoxFit.contain,
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                  );
                }
                if (path.contains('assets/')) {
                  final clean = cleanAssetPath(path);
                  if (isNetworkImage(clean)) {
                    return Image.network(
                      resolveImageUrl(clean),
                      fit: BoxFit.contain,
                      width: element.width * scaleX,
                      height: element.height * scaleY,
                    );
                  } else {
                    return Image.asset(
                      clean,
                      fit: BoxFit.contain,
                      width: element.width * scaleX,
                      height: element.height * scaleY,
                    );
                  }
                }
                return Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                );
              }
            }
          }
        }
        if (element.assetPath != null && element.assetPath!.isNotEmpty) {
          final isNetwork = isNetworkImage(element.assetPath!);
          return isNetwork
              ? Image.network(
                  resolveImageUrl(element.assetPath!),
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                )
              : Image.asset(
                  cleanAssetPath(element.assetPath!),
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                );
        }
        return const SizedBox.shrink();

      case ElementType.divider:
        return Center(
          child: Container(
            width: element.width * scaleX,
            height: 1.5 * scaleY,
            color: element.color.withOpacity(0.5),
          ),
        );

      case ElementType.decorative:
        if (element.assetPath != null && element.assetPath!.isNotEmpty) {
          final isNetwork = isNetworkImage(element.assetPath!);
          return isNetwork
              ? Image.network(
                  resolveImageUrl(element.assetPath!),
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                )
              : Image.asset(
                  cleanAssetPath(element.assetPath!),
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                );
        }
        return const SizedBox.shrink();
    }
  }

  Alignment _getAlignment() {
    switch (element.textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        return Alignment.centerLeft;
      case TextAlign.right:
      case TextAlign.end:
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }
}

class GoogleMapsIconWidget extends StatelessWidget {
  final double size;

  const GoogleMapsIconWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _AuthenticGoogleMapsPainter(),
      ),
    );
  }
}

class _AuthenticGoogleMapsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Clip to rounded bounds of the inner map canvas
    final RRect clipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.15),
    );
    canvas.save();
    canvas.clipRRect(clipRect);

    // 1. Draw base/background: light grey fold (bottom-right)
    paint.color = const Color(0xFFE8EAED); // Google Light Grey
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // 2. Draw Blue fold (bottom center/right area)
    final Path bluePath = Path()
      ..moveTo(w * 0.2, h)
      ..lineTo(w * 0.9, h)
      ..lineTo(w * 0.55, h * 0.55)
      ..close();
    paint.color = const Color(0xFF4285F4); // Google Blue
    canvas.drawPath(bluePath, paint);

    // 3. Draw Green fold (top left area)
    final Path greenPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.65, h * 0.6)
      ..lineTo(0, h * 0.6)
      ..close();
    paint.color = const Color(0xFF34A853); // Google Green
    canvas.drawPath(greenPath, paint);

    // 4. Draw Yellow diagonal road/strip separating them
    final Path yellowPath = Path()
      ..moveTo(0, h * 0.6)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.8, 0)
      ..lineTo(0, h * 0.75)
      ..close();
    paint.color = const Color(0xFFFBBC05); // Google Yellow
    canvas.drawPath(yellowPath, paint);

    // 5. Draw the iconic white Google "G" in the green section
    final double gCenterX = w * 0.26;
    final double gCenterY = h * 0.28;
    final double gRadius = w * 0.14;

    // Draw the white circle background for G logo
    paint.color = Colors.white.withOpacity(0.95);
    canvas.drawCircle(Offset(gCenterX, gCenterY), gRadius, paint);

    // Draw the Google "G" icon itself in green
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'G',
        style: TextStyle(
          color: const Color(0xFF34A853), // Green "G"
          fontSize: gRadius * 1.45,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(
      canvas,
      Offset(gCenterX - textPainter.width / 2, gCenterY - textPainter.height / 2),
    );

    canvas.restore(); // Restore clipping to draw pin outside/overlapping

    // 6. Draw the three-dimensional Google Maps Red Pin overlapping on the right!
    final pinCenter = Offset(w * 0.68, h * 0.38);
    final double pinRadius = w * 0.23;

    // Soft realistic Pin Shadow cast to the bottom-left
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pinCenter.dx - pinRadius * 0.25, pinCenter.dy + pinRadius * 1.1),
        width: pinRadius * 1.1,
        height: pinRadius * 0.35,
      ),
      shadowPaint,
    );

    // Red pin base path (combining circle and sharp bottom pointer)
    final Path pinPath = Path()
      ..moveTo(pinCenter.dx, pinCenter.dy + pinRadius * 1.25)
      ..lineTo(pinCenter.dx - pinRadius * 0.65, pinCenter.dy + pinRadius * 0.35)
      ..arcToPoint(
        Offset(pinCenter.dx + pinRadius * 0.65, pinCenter.dy + pinRadius * 0.35),
        radius: Radius.circular(pinRadius),
        clockwise: true,
      )
      ..lineTo(pinCenter.dx, pinCenter.dy + pinRadius * 1.25)
      ..close();

    paint.color = const Color(0xFFEA4335); // Google Red Pin
    canvas.drawPath(pinPath, paint);
    canvas.drawCircle(pinCenter, pinRadius, paint);

    // White circle inside pin (outer ring)
    paint.color = Colors.white;
    canvas.drawCircle(pinCenter, pinRadius * 0.45, paint);

    // Inner red dot representing the exact location point
    paint.color = const Color(0xFFB71C1C);
    canvas.drawCircle(pinCenter, pinRadius * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dynamic Max Width Helper for self-healing text layouts
double getMaxConstraintWidth(String elementId) {
  final String id = elementId.toLowerCase();
  final bool isLeftColumn = id.contains('event1') || 
                            id.contains('bhojan_title') || 
                            id.contains('bhojan_time') || 
                            id.contains('list1a') || 
                            id.contains('list2a') || 
                            id.contains('list3a') || 
                            id.endsWith('_left');
                            
  final bool isRightColumn = id.contains('event2') || 
                             id.contains('sthal_title') || 
                             id.contains('sthal_address') || 
                             id.contains('list1b') || 
                             id.contains('list2b') || 
                             id.contains('list3b') || 
                             id.endsWith('_right');

  if (isLeftColumn || isRightColumn) {
    return 160.0;
  }
  return 320.0;
}

