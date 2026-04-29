import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../models/template_element.dart';
import '../../../providers/invitation_provider.dart';

/// A read-only version of DraggableElement for the preview screens.
class StaticElement extends StatelessWidget {
  final TemplateElement element;
  final bool isGujarati;

  const StaticElement({
    super.key,
    required this.element,
    this.isGujarati = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!element.isVisible) return const SizedBox.shrink();

    return Positioned(
      left: element.x,
      top: element.y,
      child: Opacity(
        opacity: element.opacity,
        child: SizedBox(
          width: element.width,
          height: element.height,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (element.type) {
      case ElementType.text:
        return Container(
          alignment: _getAlignment(),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            element.getDisplayText(isGujarati),
            textAlign: element.textAlign,
            overflow: TextOverflow.visible,
            style: TextStyle(
              fontSize: element.fontSize,
              fontFamily: element.fontFamily,
              color: element.color,
              fontWeight: element.fontWeight,
              fontStyle: element.fontStyle,
              letterSpacing: element.letterSpacing,
              height: element.lineHeight,
            ),
          ),
        );

      case ElementType.image:
        if (element.id == 'ganesh_image') {
          final provider = Provider.of<InvitationProvider>(context, listen: true);
          if (provider.logo.type == LogoType.customSvg && provider.logo.rawSvgContent != null) {
            return SvgPicture.string(
              provider.logo.rawSvgContent!,
              width: element.width,
              height: element.height,
              fit: BoxFit.contain,
            );
          } else if (provider.logo.presetAsset != null) {
            return Image.asset(
              provider.logo.presetAsset!,
              fit: BoxFit.contain,
              width: element.width,
              height: element.height,
            );
          }
        }
        if (element.assetPath != null) {
          return Image.asset(
            element.assetPath!,
            fit: BoxFit.contain,
            width: element.width,
            height: element.height,
          );
        }
        return const SizedBox.shrink();

      case ElementType.divider:
        return Center(
          child: Container(
            width: element.width,
            height: 1.5,
            color: element.color.withOpacity(0.5),
          ),
        );

      case ElementType.decorative:
        if (element.assetPath != null) {
          return Image.asset(
            element.assetPath!,
            fit: BoxFit.contain,
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
