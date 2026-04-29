import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../providers/invitation_provider.dart';
import '../../../models/template_element.dart';
import 'transliteration_field.dart';

/// A single draggable, resizable element on the editor canvas.
///
/// Features:
/// - Tap to select
/// - Drag to move (when selected and movable)
/// - Resize handles on corners + edges (when selected and resizable)
/// - Double-tap to edit text inline
class DraggableElement extends StatelessWidget {
  final TemplateElement element;
  final bool isSelected;
  final bool isGujarati;
  final VoidCallback onTap;
  final Function(double dx, double dy) onDrag;
  final Function(double newWidth, double newHeight) onResize;
  final Function(String newText) onTextEdit;

  const DraggableElement({
    super.key,
    required this.element,
    required this.isSelected,
    required this.isGujarati,
    required this.onTap,
    required this.onDrag,
    required this.onResize,
    required this.onTextEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: element.x,
      top: element.y,
      child: GestureDetector(
        onTap: onTap,

        // 🔥 DRAG TO MOVE
        onPanUpdate: element.isMovable
            ? (details) {
                onDrag(details.delta.dx, details.delta.dy);
              }
            : null,

        // 🔥 DOUBLE TAP TO EDIT TEXT
        onDoubleTap: element.isEditable && element.type == ElementType.text
            ? () => _showTextEditor(context)
            : null,

        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 🔹 MAIN ELEMENT CONTENT
            Opacity(
              opacity: element.opacity,
              child: Container(
                width: element.width,
                height: element.height,
                decoration: isSelected
                    ? BoxDecoration(
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      )
                    : null,
                child: _buildContent(context),
              ),
            ),

            // 🔹 RESIZE HANDLES (shown when selected & resizable)
            if (isSelected && element.isResizable) ...[
              // Top-Left corner
              _resizeHandle(
                alignment: Alignment.topLeft,
                cursor: SystemMouseCursors.resizeUpLeft,
                onDrag: (dx, dy) {
                  final newW = (element.width - dx).clamp(30.0, 800.0);
                  final newH = (element.height - dy).clamp(20.0, 800.0);
                  onResize(newW, newH);
                },
              ),
              // Top-Right corner
              _resizeHandle(
                alignment: Alignment.topRight,
                cursor: SystemMouseCursors.resizeUpRight,
                onDrag: (dx, dy) {
                  final newW = (element.width + dx).clamp(30.0, 800.0);
                  final newH = (element.height - dy).clamp(20.0, 800.0);
                  onResize(newW, newH);
                },
              ),
              // Bottom-Left corner
              _resizeHandle(
                alignment: Alignment.bottomLeft,
                cursor: SystemMouseCursors.resizeDownLeft,
                onDrag: (dx, dy) {
                  final newW = (element.width - dx).clamp(30.0, 800.0);
                  final newH = (element.height + dy).clamp(20.0, 800.0);
                  onResize(newW, newH);
                },
              ),
              // Bottom-Right corner
              _resizeHandle(
                alignment: Alignment.bottomRight,
                cursor: SystemMouseCursors.resizeDownRight,
                onDrag: (dx, dy) {
                  final newW = (element.width + dx).clamp(30.0, 800.0);
                  final newH = (element.height + dy).clamp(20.0, 800.0);
                  onResize(newW, newH);
                },
              ),
              // Right edge
              _resizeHandle(
                alignment: Alignment.centerRight,
                cursor: SystemMouseCursors.resizeColumn,
                onDrag: (dx, dy) {
                  final newW = (element.width + dx).clamp(30.0, 800.0);
                  onResize(newW, element.height);
                },
              ),
              // Left edge
              _resizeHandle(
                alignment: Alignment.centerLeft,
                cursor: SystemMouseCursors.resizeColumn,
                onDrag: (dx, dy) {
                  final newW = (element.width - dx).clamp(30.0, 800.0);
                  onResize(newW, element.height);
                },
              ),
              // Bottom edge
              _resizeHandle(
                alignment: Alignment.bottomCenter,
                cursor: SystemMouseCursors.resizeRow,
                onDrag: (dx, dy) {
                  final newH = (element.height + dy).clamp(20.0, 800.0);
                  onResize(element.width, newH);
                },
              ),
              // Top edge
              _resizeHandle(
                alignment: Alignment.topCenter,
                cursor: SystemMouseCursors.resizeRow,
                onDrag: (dx, dy) {
                  final newH = (element.height - dy).clamp(20.0, 800.0);
                  onResize(element.width, newH);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // 🎨 RENDER CONTENT
  // ─────────────────────────────────────────────────
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
        return Container(
          color: Colors.grey.withValues(alpha: 0.3),
          child: const Icon(Icons.image, color: Colors.grey),
        );

      case ElementType.divider:
        return Center(
          child: Container(
            width: element.width,
            height: 1.5,
            color: element.color.withValues(alpha: 0.5),
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

  // ─────────────────────────────────────────────────
  // 📐 RESIZE HANDLE WIDGET
  // ─────────────────────────────────────────────────
  Widget _resizeHandle({
    required Alignment alignment,
    required MouseCursor cursor,
    required Function(double dx, double dy) onDrag,
  }) {
    const double handleSize = 18;

    double? left, right, top, bottom;

    if (alignment == Alignment.topLeft) {
      left = -handleSize / 2;
      top = -handleSize / 2;
    } else if (alignment == Alignment.topRight) {
      right = -handleSize / 2;
      top = -handleSize / 2;
    } else if (alignment == Alignment.bottomLeft) {
      left = -handleSize / 2;
      bottom = -handleSize / 2;
    } else if (alignment == Alignment.bottomRight) {
      right = -handleSize / 2;
      bottom = -handleSize / 2;
    } else if (alignment == Alignment.centerRight) {
      right = -handleSize / 2;
      top = element.height / 2 - handleSize / 2;
    } else if (alignment == Alignment.centerLeft) {
      left = -handleSize / 2;
      top = element.height / 2 - handleSize / 2;
    } else if (alignment == Alignment.bottomCenter) {
      left = element.width / 2 - handleSize / 2;
      bottom = -handleSize / 2;
    } else if (alignment == Alignment.topCenter) {
      left = element.width / 2 - handleSize / 2;
      top = -handleSize / 2;
    }

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: (details) {
            onDrag(details.delta.dx, details.delta.dy);
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.blue,
              border: Border.all(color: Colors.white, width: 2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // ✏️ INLINE TEXT EDITOR
  // ─────────────────────────────────────────────────
  void _showTextEditor(BuildContext context) {
    String currentEn = element.content;
    String currentGu = element.contentGujarati;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Text"),
        content: SizedBox(
          width: 400,
          child: TransliterationField(
            initialText: isGujarati ? element.contentGujarati : element.content,
            isTransliterationOn: isGujarati,
            label: "Edit Content",
            maxLines: 4,
            onChanged: (en, gu) {
              currentEn = en;
              currentGu = gu;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              // If we are in Gujarati mode, we return the Gujarati text
              // If not, we return the English text
              onTextEdit(isGujarati ? currentGu : currentEn);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
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
