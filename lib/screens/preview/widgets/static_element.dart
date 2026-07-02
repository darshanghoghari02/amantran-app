import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../models/template_element.dart';
import '../../../providers/invitation_provider.dart';
import '../../../widgets/app_image.dart';
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
      child: RepaintBoundary(
        child: _buildContent(context),
      ),
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
            textAlign: element.getTextAlignForLanguage(activeLanguage),
            textDirection: TemplateElement.textDirectionFor(activeLanguage),
            softWrap: true,
            overflow: TextOverflow.visible,
            style: element.getTextStyleForLanguage(activeLanguage, scale: scaleX),
          ),
        );

      case ElementType.image:
      case ElementType.sticker:
        {
          final idLower = element.id.toLowerCase();
          final pathLower = (element.assetPath ?? '').toLowerCase();
          if (idLower.contains('ganesh') || pathLower.contains('ganesh')) {
            final provider = Provider.of<InvitationProvider>(context, listen: false);
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
                  if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
                    return SvgPicture.network(
                      resolveImageUrl(path),
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
                  if (File(path).existsSync()) {
                    return SvgPicture.file(
                      File(path),
                      width: element.width * scaleX,
                      height: element.height * scaleY,
                      fit: BoxFit.contain,
                    );
                  }
                  return SvgPicture.network(
                    resolveImageUrl(path),
                    width: element.width * scaleX,
                    height: element.height * scaleY,
                    fit: BoxFit.contain,
                  );
                }
              }
            } else if (provider.logo.type == LogoType.customFile && provider.logo.customFilePath != null) {
              final String path = provider.logo.customFilePath!;
              return AppImage(
                src: path,
                fit: BoxFit.contain,
                width: element.width * scaleX,
                height: element.height * scaleY,
              );
            } else {
              final String? path = provider.logo.presetAsset ?? element.assetPath;
              if (path != null && path.isNotEmpty) {
                return AppImage(
                  src: path,
                  fit: BoxFit.contain,
                  width: element.width * scaleX,
                  height: element.height * scaleY,
                );
              }
            }
          }
        }
        if (element.assetPath != null && element.assetPath!.isNotEmpty) {
          return AppImage(
            src: element.assetPath!,
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
          return AppImage(
            src: element.assetPath!,
            fit: BoxFit.contain,
            width: element.width * scaleX,
            height: element.height * scaleY,
          );
        }
        return const SizedBox.shrink();
    }
  }

  Alignment _getAlignment() {
    switch (element.getTextAlignForLanguage(activeLanguage)) {
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
  static const String assetPath = 'assets/images/location_map_icon.png';

  final double size;

  const GoogleMapsIconWidget({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
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
    return 480.0;
  }
  return 960.0;
}

