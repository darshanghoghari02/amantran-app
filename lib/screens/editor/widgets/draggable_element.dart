import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../config/api_config.dart';
import '../../../providers/invitation_provider.dart';
import '../../../models/template_element.dart';
import 'transliteration_field.dart';
import '../../preview/widgets/static_element.dart';
import '../../../utils/image_resolver.dart';
import '../../../widgets/app_image.dart';
import '../../../providers/language_provider.dart';

class GuidelineInfo {
  final double x;
  final double y;
  final double width;
  final double height;
  final double pageW;
  final double pageH;
  final double scaleX;
  final double scaleY;

  GuidelineInfo({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.pageW,
    required this.pageH,
    required this.scaleX,
    required this.scaleY,
  });
}

/// Helper to calculate the dynamic wrapped text height
double _calculateTextHeight(TemplateElement element, double width, String activeLanguage) {
  final String displayText = element.getDisplayText(activeLanguage);
  final textStyle = element.getTextStyle(scale: 1.0);
  
  final textPainter = TextPainter(
    text: TextSpan(
      text: displayText,
      style: textStyle,
    ),
    textDirection: TextDirection.ltr,
    textAlign: element.textAlign,
  );
  textPainter.layout(maxWidth: width);
  return textPainter.height > 0 ? textPainter.height + 4.0 : 40.0;
}

/// A single draggable, resizable element on the editor canvas.
///
/// Features:
/// - Tap to select
/// - Drag to move (when selected and movable)
/// - Resize handles on corners + edges (when selected and resizable)
/// - Double-tap to edit text inline, or double-tap Ganesh to change style
class DraggableElement extends StatefulWidget {
  final TemplateElement element;
  final bool isSelected;
  final String activeLanguage;
  final VoidCallback onTap;
  final Function(double newX, double newY) onDrag;
  final Function(double newWidth, double newHeight, double? newFontSize, {double? newX, double? newY, double? newLetterSpacing}) onResize;
  final Function(String newText, String newTextGujarati) onTextEdit;
  final VoidCallback? onActionStart;
  final VoidCallback? onActionEnd;
  final double scaleX;
  final double scaleY;
  final VoidCallback? onDelete;
  final double pageW;
  final double pageH;
  final ValueNotifier<GuidelineInfo?> guidelineNotifier;

  const DraggableElement({
    super.key,
    required this.element,
    required this.isSelected,
    required this.activeLanguage,
    required this.onTap,
    required this.onDrag,
    required this.onResize,
    required this.onTextEdit,
    this.onActionStart,
    this.onActionEnd,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.onDelete,
    required this.pageW,
    required this.pageH,
    required this.guidelineNotifier,
  });

  @override
  State<DraggableElement> createState() => _DraggableElementState();
}

class _DraggableElementState extends State<DraggableElement> {
  static final Map<String, DateTime> _lastTapTimes = {};

  double? _localX;
  double? _localY;
  double? _localWidth;
  double? _localHeight;
  double? _localFontSize;
  double? _localLetterSpacing;

  bool _isDragging = false;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _syncWithWidget();
  }

  @override
  void didUpdateWidget(DraggableElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && !_isResizing) {
      _syncWithWidget();
    }
  }

  void _syncWithWidget() {
    _localX = widget.element.x;
    _localY = widget.element.y;
    _localWidth = widget.element.width;
    _localHeight = widget.element.height;
    _localFontSize = widget.element.fontSize;
    _localLetterSpacing = widget.element.letterSpacing;
  }

  void handleResize({
    required double dx,
    required double dy,
    required Alignment alignment,
  }) {
    final double dw = dx / widget.scaleX;
    final double dh = dy / widget.scaleY;

    const double minW = 30.0;
    const double minH = 15.0;
    const double maxDim = 800.0;

    final bool isCorner = alignment == Alignment.topLeft ||
        alignment == Alignment.topRight ||
        alignment == Alignment.bottomLeft ||
        alignment == Alignment.bottomRight;

    if (widget.element.type == ElementType.text) {
      final bool isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft || alignment == Alignment.centerLeft;
      final bool isRight = alignment == Alignment.topRight || alignment == Alignment.bottomRight || alignment == Alignment.centerRight;
      final bool isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight || alignment == Alignment.topCenter;
      final bool isBottom = alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight || alignment == Alignment.bottomCenter;

      if (isCorner) {
        final double factorW = isLeft ? -1 : 1;
        final double factorH = isTop ? -1 : 1;
        final double widthChange = factorW * dw;
        final double heightChange = factorH * dh;

        double ratio = 1.0;
        final double currentW = _localWidth ?? widget.element.width;
        final double currentH = _localHeight ?? widget.element.height;
        if (widthChange.abs() > heightChange.abs()) {
          ratio = (currentW + widthChange) / currentW;
        } else {
          ratio = (currentH + heightChange) / currentH;
        }

        final double newFontSize = ((_localFontSize ?? widget.element.fontSize) * ratio).clamp(6.0, 120.0);
        final double finalRatio = newFontSize / (_localFontSize ?? widget.element.fontSize);

        final double newWidth = (currentW * finalRatio).clamp(minW, maxDim);
        final double newHeight = (currentH * finalRatio).clamp(minH, maxDim);
        final double newLetterSpacing = (_localLetterSpacing ?? widget.element.letterSpacing) * finalRatio;

        double du = 0.0;
        if (isLeft) {
          du = (currentW - newWidth) / 2.0;
        } else if (isRight) {
          du = (newWidth - currentW) / 2.0;
        }

        double dv = 0.0;
        if (isTop) {
          dv = (currentH - newHeight) / 2.0;
        } else if (isBottom) {
          dv = (newHeight - currentH) / 2.0;
        }

        final double angleRad = widget.element.rotation * 3.141592653589793 / 180.0;
        final double cosA = math.cos(angleRad);
        final double sinA = math.sin(angleRad);

        final double shiftX = du * cosA - dv * sinA;
        final double shiftY = du * sinA + dv * cosA;

        final double newX = (_localX ?? widget.element.x) + (currentW - newWidth) / 2.0 + shiftX;
        final double newY = (_localY ?? widget.element.y) + (currentH - newHeight) / 2.0 + shiftY;

        setState(() {
          _localWidth = newWidth;
          _localHeight = newHeight;
          _localFontSize = newFontSize;
          _localX = newX;
          _localY = newY;
          _localLetterSpacing = newLetterSpacing;
        });
      } else {
        double newWidth = _localWidth ?? widget.element.width;
        if (isRight) {
          newWidth = ((_localWidth ?? widget.element.width) + dw).clamp(minW, maxDim);
        } else if (isLeft) {
          newWidth = ((_localWidth ?? widget.element.width) - dw).clamp(minW, maxDim);
        }

        final double newHeight = _calculateTextHeight(
          widget.element.copyWith(
            fontSize: _localFontSize ?? widget.element.fontSize,
            letterSpacing: _localLetterSpacing ?? widget.element.letterSpacing,
          ),
          newWidth,
          widget.activeLanguage,
        );

        double du = 0.0;
        final double currentW = _localWidth ?? widget.element.width;
        final double currentH = _localHeight ?? widget.element.height;
        if (isLeft) {
          du = (currentW - newWidth) / 2.0;
        } else if (isRight) {
          du = (newWidth - currentW) / 2.0;
        }

        double dv = (newHeight - currentH) / 2.0;

        final double angleRad = widget.element.rotation * 3.141592653589793 / 180.0;
        final double cosA = math.cos(angleRad);
        final double sinA = math.sin(angleRad);

        final double shiftX = du * cosA - dv * sinA;
        final double shiftY = du * sinA + dv * cosA;

        final double newX = (_localX ?? widget.element.x) + (currentW - newWidth) / 2.0 + shiftX;
        final double newY = (_localY ?? widget.element.y) + (currentH - newHeight) / 2.0 + shiftY;

        setState(() {
          _localWidth = newWidth;
          _localHeight = newHeight;
          _localX = newX;
          _localY = newY;
        });
      }
    } else {
      final bool isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft || alignment == Alignment.centerLeft;
      final bool isRight = alignment == Alignment.topRight || alignment == Alignment.bottomRight || alignment == Alignment.centerRight;
      final bool isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight || alignment == Alignment.topCenter;
      final bool isBottom = alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight || alignment == Alignment.bottomCenter;

      if (isCorner) {
        final double factorW = isLeft ? -1 : 1;
        final double factorH = isTop ? -1 : 1;

        final double widthChange = factorW * dw;
        final double heightChange = factorH * dh;

        double baseW = _localWidth ?? widget.element.width;
        double baseH = _localHeight ?? widget.element.height;

        double ratio = 1.0;
        if (widthChange.abs() > heightChange.abs()) {
          ratio = (baseW + widthChange) / baseW;
        } else {
          ratio = (baseH + heightChange) / baseH;
        }

        final double newW = ((_localWidth ?? widget.element.width) * ratio).clamp(minW, maxDim);
        final double newH = ((_localHeight ?? widget.element.height) * ratio).clamp(minH, maxDim);

        double du = 0.0;
        final double currentW = _localWidth ?? widget.element.width;
        final double currentH = _localHeight ?? widget.element.height;
        if (isLeft) {
          du = (currentW - newW) / 2.0;
        } else if (isRight) {
          du = (newW - currentW) / 2.0;
        }

        double dv = 0.0;
        if (isTop) {
          dv = (currentH - newH) / 2.0;
        } else if (isBottom) {
          dv = (newH - currentH) / 2.0;
        }

        final double angleRad = widget.element.rotation * 3.141592653589793 / 180.0;
        final double cosA = math.cos(angleRad);
        final double sinA = math.sin(angleRad);

        final double shiftX = du * cosA - dv * sinA;
        final double shiftY = du * sinA + dv * cosA;

        final double newX = (_localX ?? widget.element.x) + (currentW - newW) / 2.0 + shiftX;
        final double newY = (_localY ?? widget.element.y) + (currentH - newH) / 2.0 + shiftY;

        setState(() {
          _localWidth = newW;
          _localHeight = newH;
          _localX = newX;
          _localY = newY;
        });
      } else {
        double newW = _localWidth ?? widget.element.width;
        double newH = _localHeight ?? widget.element.height;

        if (alignment == Alignment.centerRight) {
          newW = ((_localWidth ?? widget.element.width) + dw).clamp(minW, maxDim);
        } else if (alignment == Alignment.centerLeft) {
          newW = ((_localWidth ?? widget.element.width) - dw).clamp(minW, maxDim);
        } else if (alignment == Alignment.bottomCenter) {
          newH = ((_localHeight ?? widget.element.height) + dh).clamp(minH, maxDim);
        } else if (alignment == Alignment.topCenter) {
          newH = ((_localHeight ?? widget.element.height) - dh).clamp(minH, maxDim);
        }

        double du = 0.0;
        final double currentW = _localWidth ?? widget.element.width;
        final double currentH = _localHeight ?? widget.element.height;
        if (alignment == Alignment.centerLeft) {
          du = (currentW - newW) / 2.0;
        } else if (alignment == Alignment.centerRight) {
          du = (newW - currentW) / 2.0;
        }

        double dv = 0.0;
        if (alignment == Alignment.topCenter) {
          dv = (currentH - newH) / 2.0;
        } else if (alignment == Alignment.bottomCenter) {
          dv = (newH - currentH) / 2.0;
        }

        final double angleRad = widget.element.rotation * 3.141592653589793 / 180.0;
        final double cosA = math.cos(angleRad);
        final double sinA = math.sin(angleRad);

        final double shiftX = du * cosA - dv * sinA;
        final double shiftY = du * sinA + dv * cosA;

        final double newX = (_localX ?? widget.element.x) + (currentW - newW) / 2.0 + shiftX;
        final double newY = (_localY ?? widget.element.y) + (currentH - newH) / 2.0 + shiftY;

        setState(() {
          _localWidth = newW;
          _localHeight = newH;
          _localX = newX;
          _localY = newY;
        });
      }
    }

    widget.guidelineNotifier.value = GuidelineInfo(
      x: _localX!,
      y: _localY!,
      width: _localWidth!,
      height: _localHeight!,
      pageW: widget.pageW,
      pageH: widget.pageH,
      scaleX: widget.scaleX,
      scaleY: widget.scaleY,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.element.isVisible) return const SizedBox.shrink();

    if (widget.element.id.endsWith('_map_icon')) {
      final provider = Provider.of<InvitationProvider>(context, listen: false);
      final hasMapUrl = provider.elements.any((e) => e.mapUrl != null && e.mapUrl!.isNotEmpty);
      if (!hasMapUrl) {
        return const SizedBox.shrink();
      }
    }

    final sx = widget.scaleX;
    final sy = widget.scaleY;
    const double padding = 32.0;

    double textW = _localWidth ?? widget.element.width;
    double textH = _localHeight ?? widget.element.height;
    double newX = _localX ?? widget.element.x;
    double newY = _localY ?? widget.element.y;

    final currentElementCopy = widget.element.copyWith(
      x: newX,
      y: newY,
      width: textW,
      height: textH,
      fontSize: _localFontSize ?? widget.element.fontSize,
      letterSpacing: _localLetterSpacing ?? widget.element.letterSpacing,
    );

    return Positioned(
      left: (newX * sx) - padding,
      top: (newY * sy) - padding,
      width: (textW * sx) + padding * 2,
      height: (textH * sy) + padding * 2,
      child: Transform.rotate(
        angle: widget.element.rotation * 3.141592653589793 / 180.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: padding,
              top: padding,
              width: textW * sx,
              height: textH * sy,
              child: Opacity(
                opacity: widget.element.opacity,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onDoubleTap: () {
                    final String idLower = widget.element.id.toLowerCase();
                    final String pathLower = (widget.element.assetPath ?? '').toLowerCase();
                    final bool isGaneshaOrImage = idLower.contains('ganesh') || 
                                                  pathLower.contains('ganesh') || 
                                                  widget.element.type == ElementType.sticker || 
                                                  widget.element.type == ElementType.image;

                    if (isGaneshaOrImage) {
                      _showGaneshPicker(context);
                    } else if (widget.element.isEditable && widget.element.type == ElementType.text) {
                      _showTextEditor(context);
                    }
                  },
                  onPanStart: (_) {
                    _isDragging = true;
                    widget.onActionStart?.call();
                  },
                  onPanEnd: (_) {
                    _isDragging = false;
                    widget.guidelineNotifier.value = null;
                    widget.onDrag(_localX!, _localY!);
                    widget.onActionEnd?.call();
                  },
                  onPanUpdate: widget.element.isMovable
                      ? (details) {
                          final double angleRad = widget.element.rotation * 3.141592653589793 / 180.0;
                          final double cosA = math.cos(angleRad);
                          final double sinA = math.sin(angleRad);
                          final double globalDx = details.delta.dx * cosA - details.delta.dy * sinA;
                          final double globalDy = details.delta.dx * sinA + details.delta.dy * cosA;
                          
                          _localX = (_localX ?? widget.element.x) + globalDx / widget.scaleX;
                          _localY = (_localY ?? widget.element.y) + globalDy / widget.scaleY;

                          final currentW = _localWidth ?? widget.element.width;
                          final currentH = _localHeight ?? widget.element.height;

                          final centerX = _localX! + currentW / 2;
                          if ((centerX - widget.pageW / 2).abs() < 5.0) {
                            _localX = widget.pageW / 2 - currentW / 2;
                          }

                          final centerY = _localY! + currentH / 2;
                          if ((centerY - widget.pageH / 2).abs() < 5.0) {
                            _localY = widget.pageH / 2 - currentH / 2;
                          }

                          widget.guidelineNotifier.value = GuidelineInfo(
                            x: _localX!,
                            y: _localY!,
                            width: currentW,
                            height: currentH,
                            pageW: widget.pageW,
                            pageH: widget.pageH,
                            scaleX: widget.scaleX,
                            scaleY: widget.scaleY,
                          );

                          setState(() {});
                        }
                      : null,
                  child: Container(
                    width: textW * sx,
                    height: textH * sy,
                    color: Colors.transparent,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: _buildContent(context, sx, sy, currentElementCopy),
                          ),
                        ),
                        if (widget.isSelected)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF2196F3),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (widget.isSelected && widget.onDelete != null)
              Positioned(
                left: padding + (textW * sx) / 2 - 15.0,
                top: padding - 36.0,
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 30.0,
                    height: 30.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF94C66),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF94C66).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 16.0,
                    ),
                  ),
                ),
              ),

            if (widget.isSelected && widget.element.isResizable) ...[
              _resizeHandle(
                alignment: Alignment.topLeft,
                cursor: SystemMouseCursors.resizeUpLeft,
                padding: padding,
                sx: sx,
                sy: sy,
                elementW: textW,
                elementH: textH,
                onActionStart: () {
                  _isResizing = true;
                  widget.onActionStart?.call();
                },
                onActionEnd: () {
                  _isResizing = false;
                  widget.guidelineNotifier.value = null;
                  widget.onResize(
                    _localWidth!,
                    _localHeight!,
                    _localFontSize,
                    newX: _localX,
                    newY: _localY,
                    newLetterSpacing: _localLetterSpacing,
                  );
                  widget.onActionEnd?.call();
                },
                onDrag: (dx, dy) {
                  handleResize(dx: dx, dy: dy, alignment: Alignment.topLeft);
                },
              ),
              _resizeHandle(
                alignment: Alignment.topRight,
                cursor: SystemMouseCursors.resizeUpRight,
                padding: padding,
                sx: sx,
                sy: sy,
                elementW: textW,
                elementH: textH,
                onActionStart: () {
                  _isResizing = true;
                  widget.onActionStart?.call();
                },
                onActionEnd: () {
                  _isResizing = false;
                  widget.guidelineNotifier.value = null;
                  widget.onResize(
                    _localWidth!,
                    _localHeight!,
                    _localFontSize,
                    newX: _localX,
                    newY: _localY,
                    newLetterSpacing: _localLetterSpacing,
                  );
                  widget.onActionEnd?.call();
                },
                onDrag: (dx, dy) {
                  handleResize(dx: dx, dy: dy, alignment: Alignment.topRight);
                },
              ),
              _resizeHandle(
                alignment: Alignment.bottomLeft,
                cursor: SystemMouseCursors.resizeDownLeft,
                padding: padding,
                sx: sx,
                sy: sy,
                elementW: textW,
                elementH: textH,
                onActionStart: () {
                  _isResizing = true;
                  widget.onActionStart?.call();
                },
                onActionEnd: () {
                  _isResizing = false;
                  widget.guidelineNotifier.value = null;
                  widget.onResize(
                    _localWidth!,
                    _localHeight!,
                    _localFontSize,
                    newX: _localX,
                    newY: _localY,
                    newLetterSpacing: _localLetterSpacing,
                  );
                  widget.onActionEnd?.call();
                },
                onDrag: (dx, dy) {
                  handleResize(dx: dx, dy: dy, alignment: Alignment.bottomLeft);
                },
              ),
              _resizeHandle(
                alignment: Alignment.bottomRight,
                cursor: SystemMouseCursors.resizeDownRight,
                padding: padding,
                sx: sx,
                sy: sy,
                elementW: textW,
                elementH: textH,
                onActionStart: () {
                  _isResizing = true;
                  widget.onActionStart?.call();
                },
                onActionEnd: () {
                  _isResizing = false;
                  widget.guidelineNotifier.value = null;
                  widget.onResize(
                    _localWidth!,
                    _localHeight!,
                    _localFontSize,
                    newX: _localX,
                    newY: _localY,
                    newLetterSpacing: _localLetterSpacing,
                  );
                  widget.onActionEnd?.call();
                },
                onDrag: (dx, dy) {
                  handleResize(dx: dx, dy: dy, alignment: Alignment.bottomRight);
                },
              ),
              _resizeHandle(
                alignment: Alignment.centerLeft,
                cursor: SystemMouseCursors.resizeColumn,
                padding: padding,
                sx: sx,
                sy: sy,
                elementW: textW,
                elementH: textH,
                onActionStart: () {
                  _isResizing = true;
                  widget.onActionStart?.call();
                },
                onActionEnd: () {
                  _isResizing = false;
                  widget.guidelineNotifier.value = null;
                  widget.onResize(
                    _localWidth!,
                    _localHeight!,
                    _localFontSize,
                    newX: _localX,
                    newY: _localY,
                    newLetterSpacing: _localLetterSpacing,
                  );
                  widget.onActionEnd?.call();
                },
                onDrag: (dx, dy) {
                  handleResize(dx: dx, dy: 0, alignment: Alignment.centerLeft);
                },
              ),
              _resizeHandle(
                alignment: Alignment.centerRight,
                cursor: SystemMouseCursors.resizeColumn,
                padding: padding,
                sx: sx,
                sy: sy,
                elementW: textW,
                elementH: textH,
                onActionStart: () {
                  _isResizing = true;
                  widget.onActionStart?.call();
                },
                onActionEnd: () {
                  _isResizing = false;
                  widget.guidelineNotifier.value = null;
                  widget.onResize(
                    _localWidth!,
                    _localHeight!,
                    _localFontSize,
                    newX: _localX,
                    newY: _localY,
                    newLetterSpacing: _localLetterSpacing,
                  );
                  widget.onActionEnd?.call();
                },
                onDrag: (dx, dy) {
                  handleResize(dx: dx, dy: 0, alignment: Alignment.centerRight);
                },
              ),
              if (widget.element.type != ElementType.text)
                _resizeHandle(
                  alignment: Alignment.topCenter,
                  cursor: SystemMouseCursors.resizeRow,
                  padding: padding,
                  sx: sx,
                  sy: sy,
                  elementW: textW,
                  elementH: textH,
                  onActionStart: () {
                    _isResizing = true;
                    widget.onActionStart?.call();
                  },
                  onActionEnd: () {
                    _isResizing = false;
                    widget.guidelineNotifier.value = null;
                    widget.onResize(
                      _localWidth!,
                      _localHeight!,
                      _localFontSize,
                      newX: _localX,
                      newY: _localY,
                      newLetterSpacing: _localLetterSpacing,
                    );
                    widget.onActionEnd?.call();
                  },
                  onDrag: (dx, dy) {
                    handleResize(dx: 0, dy: dy, alignment: Alignment.topCenter);
                  },
                ),
              if (widget.element.type != ElementType.text)
                _resizeHandle(
                  alignment: Alignment.bottomCenter,
                  cursor: SystemMouseCursors.resizeRow,
                  padding: padding,
                  sx: sx,
                  sy: sy,
                  elementW: textW,
                  elementH: textH,
                  onActionStart: () {
                    _isResizing = true;
                    widget.onActionStart?.call();
                  },
                  onActionEnd: () {
                    _isResizing = false;
                    widget.guidelineNotifier.value = null;
                    widget.onResize(
                      _localWidth!,
                      _localHeight!,
                      _localFontSize,
                      newX: _localX,
                      newY: _localY,
                      newLetterSpacing: _localLetterSpacing,
                    );
                    widget.onActionEnd?.call();
                  },
                  onDrag: (dx, dy) {
                    handleResize(dx: 0, dy: dy, alignment: Alignment.bottomCenter);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, double sx, double sy, TemplateElement element) {
    if (element.id.contains('_map_icon')) {
      return GoogleMapsIconWidget(size: element.height * sy);
    }
    switch (element.type) {
      case ElementType.text:
        return Container(
          alignment: _getAlignment(element),
          padding: EdgeInsets.zero,
          child: Text(
            element.getDisplayText(widget.activeLanguage),
            softWrap: true,
            overflow: TextOverflow.visible,
            textAlign: element.getTextAlignForLanguage(widget.activeLanguage),
            textDirection: TemplateElement.textDirectionFor(widget.activeLanguage),
            style: element.getTextStyleForLanguage(widget.activeLanguage, scale: sx),
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
                  width: element.width * sx,
                  height: element.height * sy,
                  fit: BoxFit.contain,
                );
              } else {
                final String? path = provider.logo.customSvgPath ?? element.assetPath;
                if (path != null && path.isNotEmpty) {
                  if (path.startsWith('http://') || path.startsWith('https://')) {
                    return SvgPicture.network(
                      path,
                      width: element.width * sx,
                      height: element.height * sy,
                      fit: BoxFit.contain,
                    );
                  }
                  if (path.startsWith('uploads/') || path.startsWith('/uploads/')) {
                    return SvgPicture.network(
                      resolveImageUrl(path),
                      width: element.width * sx,
                      height: element.height * sy,
                      fit: BoxFit.contain,
                    );
                  }
                  if (path.contains('assets/')) {
                    final clean = cleanAssetPath(path);
                    if (isNetworkImage(clean)) {
                      return SvgPicture.network(
                        resolveImageUrl(clean),
                        width: element.width * sx,
                        height: element.height * sy,
                        fit: BoxFit.contain,
                      );
                    } else {
                      return SvgPicture.asset(
                        clean,
                        width: element.width * sx,
                        height: element.height * sy,
                        fit: BoxFit.contain,
                      );
                    }
                  }
                  if (File(path).existsSync()) {
                    return SvgPicture.file(
                      File(path),
                      width: element.width * sx,
                      height: element.height * sy,
                      fit: BoxFit.contain,
                    );
                  }
                  return SvgPicture.network(
                    resolveImageUrl(path),
                    width: element.width * sx,
                    height: element.height * sy,
                    fit: BoxFit.contain,
                  );
                }
              }
            } else if (provider.logo.type == LogoType.customFile && provider.logo.customFilePath != null) {
              final String path = provider.logo.customFilePath!;
              return AppImage(
                src: path,
                fit: BoxFit.contain,
                width: element.width * sx,
                height: element.height * sy,
              );
            } else {
              final String? path = provider.logo.presetAsset ?? element.assetPath;
              if (path != null && path.isNotEmpty) {
                return AppImage(
                  src: path,
                  fit: BoxFit.contain,
                  width: element.width * sx,
                  height: element.height * sy,
                );
              }
            }
          }
        }
        if (element.assetPath != null && element.assetPath!.isNotEmpty) {
          return AppImage(
            src: element.assetPath!,
            fit: BoxFit.contain,
            width: element.width * sx,
            height: element.height * sy,
          );
        }
        return Container(
          color: Colors.grey.withValues(alpha: 0.3),
          child: const Icon(Icons.image, color: Colors.grey),
        );

      case ElementType.divider:
        return Center(
          child: Container(
            width: element.width * sx,
            height: 1.5 * sy,
            color: element.color.withValues(alpha: 0.5),
          ),
        );

      case ElementType.decorative:
        if (element.assetPath != null && element.assetPath!.isNotEmpty) {
          return AppImage(
            src: element.assetPath!,
            fit: BoxFit.contain,
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _resizeHandle({
    required Alignment alignment,
    required MouseCursor cursor,
    required double padding,
    required double sx,
    required double sy,
    required double elementW,
    required double elementH,
    required VoidCallback onActionStart,
    required VoidCallback onActionEnd,
    required Function(double dx, double dy) onDrag,
  }) {
    const double touchSize = 36.0;
    double? left, right, top, bottom;

    if (alignment == Alignment.topLeft) {
      left = padding - touchSize / 2;
      top = padding - touchSize / 2;
    } else if (alignment == Alignment.topRight) {
      right = padding - touchSize / 2;
      top = padding - touchSize / 2;
    } else if (alignment == Alignment.bottomLeft) {
      left = padding - touchSize / 2;
      bottom = padding - touchSize / 2;
    } else if (alignment == Alignment.bottomRight) {
      right = padding - touchSize / 2;
      bottom = padding - touchSize / 2;
    } else if (alignment == Alignment.centerRight) {
      right = padding - touchSize / 2;
      top = padding + (elementH * sy) / 2 - touchSize / 2;
    } else if (alignment == Alignment.centerLeft) {
      left = padding - touchSize / 2;
      top = padding + (elementH * sy) / 2 - touchSize / 2;
    } else if (alignment == Alignment.bottomCenter) {
      left = padding + (elementW * sx) / 2 - touchSize / 2;
      bottom = padding - touchSize / 2;
    } else if (alignment == Alignment.topCenter) {
      left = padding + (elementW * sx) / 2 - touchSize / 2;
      top = padding - touchSize / 2;
    }

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (_) => onActionStart(),
          onPanEnd: (_) => onActionEnd(),
          onPanUpdate: (details) {
            onDrag(details.delta.dx, details.delta.dy);
          },
          child: Container(
            width: touchSize,
            height: touchSize,
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Container(
              width: 12.0,
              height: 12.0,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _normalizeGaneshPath(String path) {
    var p = path.trim();
    final pLower = p.toLowerCase();
    if (pLower.contains('ganesh1.png') || pLower.contains('ganesh.png')) {
      return 'assets/images/ganesh1.png';
    }
    if (pLower.contains('ganesh2.png')) {
      return 'assets/images/ganesh2.png';
    }
    if (pLower.contains('ganesh3.png')) {
      return 'assets/images/ganesh3.png';
    }
    for (final prefix in [
      ApiConfig.baseUrl,
      'http://192.168.1.68:8000',
      'https://192.168.1.68:8000',
      'http://10.0.2.2:8000',
      'http://10.0.2.2:8080',
      'https://10.0.2.2:8000',
      'https://10.0.2.2:8080',
      'http://localhost:8000',
      'http://localhost:8080',
      'https://localhost:8000',
      'https://localhost:8080',
    ]) {
      if (p.startsWith(prefix)) {
        p = p.substring(prefix.length);
        break;
      }
    }
    if (p.startsWith('/')) p = p.substring(1);
    return p;
  }

  void _showGaneshPicker(BuildContext context) {
    final provider = Provider.of<InvitationProvider>(context, listen: false);
    final String idLower = widget.element.id.toLowerCase();
    final String pathLower = (widget.element.assetPath ?? '').toLowerCase();
    final bool isGanesha = idLower.contains('ganesh') || pathLower.contains('ganesh');

    LogoModel tempLogo;
    if (isGanesha) {
      tempLogo = LogoModel(
        type: provider.logo.type,
        presetAsset: provider.logo.presetAsset,
        customSvgPath: provider.logo.customSvgPath,
        rawSvgContent: provider.logo.rawSvgContent,
        customFilePath: provider.logo.customFilePath,
      );
    } else {
      final String path = widget.element.assetPath ?? '';
      final String normalized = _normalizeGaneshPath(path);
      if (normalized.endsWith('.svg')) {
        tempLogo = LogoModel(
          type: LogoType.customSvg,
          customSvgPath: path,
        );
      } else if (normalized == 'assets/images/ganesh1.png' ||
                 normalized == 'assets/images/ganesh2.png' ||
                 normalized == 'assets/images/ganesh3.png') {
        tempLogo = LogoModel(
          type: LogoType.preset,
          presetAsset: normalized,
        );
      } else {
        tempLogo = LogoModel(
          type: LogoType.customFile,
          customFilePath: path,
        );
      }
    }

    String selectedKey = '';
    final String pathToCheck = tempLogo.type == LogoType.preset
        ? (tempLogo.presetAsset ?? '')
        : (tempLogo.customFilePath ?? tempLogo.customSvgPath ?? '');
    
    if (pathToCheck.isNotEmpty) {
      final String normalized = _normalizeGaneshPath(pathToCheck);
      if (normalized == 'assets/images/ganesh1.png') {
        selectedKey = 'preset1';
      } else if (normalized == 'assets/images/ganesh2.png') {
        selectedKey = 'preset2';
      } else if (normalized == 'assets/images/ganesh3.png') {
        selectedKey = 'preset3';
      } else {
        selectedKey = 'uploaded';
      }
    } else {
      selectedKey = 'uploaded';
    }

    LogoModel? customLogoState;
    if (tempLogo.type == LogoType.customSvg || tempLogo.type == LogoType.customFile) {
      customLogoState = tempLogo;
    } else {
      if (isGanesha) {
        if (provider.logo.type == LogoType.customSvg || provider.logo.type == LogoType.customFile) {
          customLogoState = provider.logo;
        }
      } else {
        final String path = widget.element.assetPath ?? '';
        final String normalized = _normalizeGaneshPath(path);
        if (path.isNotEmpty &&
            !normalized.endsWith('.svg') &&
            normalized != 'assets/images/ganesh1.png' &&
            normalized != 'assets/images/ganesh2.png' &&
            normalized != 'assets/images/ganesh3.png') {
          customLogoState = LogoModel(
            type: LogoType.customFile,
            customFilePath: path,
          );
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildOptionCard({
              required String optionKey,
              required Widget child,
              required VoidCallback onTap,
            }) {
              final bool isSelected = selectedKey == optionKey;
              return GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  height: 58,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF94C66) : const Color(0xFFE5E5E5),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF94C66).withValues(alpha: 0.1),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 1.5),
                            )
                          ]
                        : [],
                  ),
                  child: Center(child: child),
                ),
              );
            }

            Widget buildCustomPreview() {
              final logo = customLogoState;
              if (logo == null) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_outlined, size: 20, color: Colors.grey.shade600),
                    const SizedBox(height: 4),
                    Text(
                      "Upload",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }

              if (logo.type == LogoType.customSvg && logo.rawSvgContent != null) {
                return SvgPicture.string(logo.rawSvgContent!, fit: BoxFit.contain);
              }
              
              if (logo.type == LogoType.customFile && logo.customFilePath != null) {
                final String path = logo.customFilePath!;
                return AppImage(src: path, fit: BoxFit.contain);
              }
              
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_outlined, size: 20, color: Colors.grey.shade600),
                  const SizedBox(height: 4),
                  Text(
                    "Upload",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 310),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Choose Lord Ganesha Image",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1C1C),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildOptionCard(
                            optionKey: 'preset1',
                            onTap: () {
                              setDialogState(() {
                                selectedKey = 'preset1';
                                tempLogo = LogoModel(
                                  type: LogoType.preset,
                                  presetAsset: 'assets/images/ganesh1.png',
                                );
                              });
                            },
                            child: Image.asset('assets/images/ganesh1.png', fit: BoxFit.contain),
                          ),
                          buildOptionCard(
                            optionKey: 'preset2',
                            onTap: () {
                              setDialogState(() {
                                selectedKey = 'preset2';
                                tempLogo = LogoModel(
                                  type: LogoType.preset,
                                  presetAsset: 'assets/images/ganesh2.png',
                                );
                              });
                            },
                            child: Image.asset('assets/images/ganesh2.png', fit: BoxFit.contain),
                          ),
                          buildOptionCard(
                            optionKey: 'preset3',
                            onTap: () {
                              setDialogState(() {
                                selectedKey = 'preset3';
                                tempLogo = LogoModel(
                                  type: LogoType.preset,
                                  presetAsset: 'assets/images/ganesh3.png',
                                );
                              });
                            },
                            child: Image.asset('assets/images/ganesh3.png', fit: BoxFit.contain),
                          ),
                          buildOptionCard(
                            optionKey: 'uploaded',
                            onTap: () async {
                              try {
                                final FilePickerResult? result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['svg', 'png', 'jpg', 'jpeg'],
                                );
                                if (result != null && result.files.single.path != null) {
                                  final String path = result.files.single.path!;
                                  final File file = File(path);

                                  if (path.endsWith('.svg')) {
                                    final String content = await file.readAsString();
                                    setDialogState(() {
                                      selectedKey = 'uploaded';
                                      tempLogo = LogoModel(
                                        type: LogoType.customSvg,
                                        customSvgPath: path,
                                        rawSvgContent: content,
                                      );
                                      customLogoState = tempLogo;
                                    });
                                  } else {
                                    setDialogState(() {
                                      selectedKey = 'uploaded';
                                      tempLogo = LogoModel(
                                        type: LogoType.customFile,
                                        customFilePath: path,
                                      );
                                      customLogoState = tempLogo;
                                    });
                                  }
                                } else {
                                  if (customLogoState != null) {
                                    setDialogState(() {
                                      selectedKey = 'uploaded';
                                      tempLogo = customLogoState!;
                                    });
                                  }
                                }
                              } catch (e) {
                                debugPrint("Error picking file: $e");
                              }
                            },
                            child: buildCustomPreview(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: Color(0xFFDCDCDC), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  backgroundColor: Colors.white,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Color(0xFF1E1C1C),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  if (isGanesha) {
                                    provider.updateLogo(tempLogo);
                                  } else {
                                    String newPath = '';
                                    if (tempLogo.type == LogoType.preset) {
                                      newPath = tempLogo.presetAsset ?? '';
                                    } else if (tempLogo.type == LogoType.customSvg) {
                                      newPath = tempLogo.customSvgPath ?? '';
                                    } else if (tempLogo.type == LogoType.customFile) {
                                      newPath = tempLogo.customFilePath ?? '';
                                    }
                                    if (newPath.isNotEmpty) {
                                      provider.updateField(() {
                                        widget.element.assetPath = newPath;
                                      });
                                    }
                                  }
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF94C66),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: const Text(
                                  "Select",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _isDateField(TemplateElement el) {
    final id = el.id.toLowerCase();
    if (id.contains('title') ||
        id.contains('name') ||
        id.contains('address') ||
        id.contains('place') ||
        id.contains('invite') ||
        id.contains('text') ||
        id.contains('family') ||
        id.contains('shlok') ||
        id.contains('nimantrak') ||
        id.contains('gifts') ||
        id.contains('tahuko') ||
        id.contains('snehdhin') ||
        id.contains('darshanabhilashi') ||
        id.contains('mameru') ||
        id.contains('masi')) {
      return false;
    }

    if (id.contains('date') ||
        id.contains('time') ||
        id.contains('datetime') ||
        id.contains('day') ||
        id.contains('muhurt') ||
        id.contains('samay')) {
      return true;
    }

    final en = el.content.toLowerCase();
    final gu = el.contentGujarati.toLowerCase();

    final dateRegex = RegExp(r'\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}');
    final guDateRegex = RegExp(r'[૦-૯]{1,2}[/\-.][૦-૯]{1,2}[/\-.][૦-૯]{2,4}');
    
    if (dateRegex.hasMatch(en) || guDateRegex.hasMatch(gu)) {
      return true;
    }

    final yearRegex = RegExp(r'\b202[5-9]\b');
    final guYearRegex = RegExp(r'૨૦૨[૫-૯]');
    if (yearRegex.hasMatch(en) || guYearRegex.hasMatch(gu)) {
      return true;
    }

    const engMonths = [
      'january', 'february', 'march', 'april', 'may', 'june', 
      'july', 'august', 'september', 'october', 'november', 'december',
      'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
    ];
    const guMonths = [
      'જાન્યુઆરી', 'ફેબ્રુઆરી', 'માર્ચ', 'એપ્રિલ', 'મે', 'જૂન', 
      'જુલાઈ', 'ઓગસ્ટ', 'સપ્ટેમ્બર', 'ઓક્ટોબર', 'નવેમ્બર', 'ડિસેમ્બર'
    ];

    for (final month in engMonths) {
      if (en.contains(month)) return true;
    }
    for (final month in guMonths) {
      if (gu.contains(month)) return true;
    }

    if (en.contains('date:') || 
        en.contains('time:') || 
        en.contains(' am') || 
        en.contains(' pm') ||
        gu.contains('તારીખ') || 
        gu.contains('સમય') ||
        gu.contains('તા.')) {
      return true;
    }

    return false;
  }

  Future<void> _showDatePickerFlow(BuildContext context, TemplateElement el, Function(String en, String gu) onSave) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF94C66),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF94C66),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    final bool? addTime = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Ceremony Time?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Would you like to specify a time for this ceremony?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No, Date Only", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF94C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Add Time"),
          ),
        ],
      ),
    );

    TimeOfDay? pickedTime;
    if (addTime == true) {
      pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFF94C66),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
            ),
            child: child!,
          );
        },
      );
    }

    String translateDigits(String input) {
      const eng = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
      const guj = ['૦', '૧', '૨', '૩', '૪', '૫', '૬', '૭', '૮', '૯'];
      String res = input;
      for (int i = 0; i < eng.length; i++) {
        res = res.replaceAll(eng[i], guj[i]);
      }
      return res;
    }

    String getGujDay(int weekday) {
      const days = {
        DateTime.monday: 'સોમવાર',
        DateTime.tuesday: 'મંગળવાર',
        DateTime.wednesday: 'બુધવાર',
        DateTime.thursday: 'ગુરુવાર',
        DateTime.friday: 'શુક્રવાર',
        DateTime.saturday: 'શનિવાર',
        DateTime.sunday: 'રવિવાર',
      };
      return days[weekday] ?? '';
    }

    String getGujMonth(int month) {
      const months = {
        1: 'જાન્યુઆરી',
        2: 'ફેબ્રુઆરી',
        3: 'માર્ચ',
        4: 'એપ્રિલ',
        5: 'મે',
        6: 'જૂન',
        7: 'જુલાઈ',
        8: 'ઓગસ્ટ',
        9: 'સપ્ટેમ્બર',
        10: 'ઓક્ટોબર',
        11: 'નવેમ્બર',
        12: 'ડિસેમ્બર',
      };
      return months[month] ?? '';
    }

    String getEngDay(int weekday) {
      const days = {
        DateTime.monday: 'Monday',
        DateTime.tuesday: 'Tuesday',
        DateTime.wednesday: 'Wednesday',
        DateTime.thursday: 'Thursday',
        DateTime.friday: 'Friday',
        DateTime.saturday: 'Saturday',
        DateTime.sunday: 'Sunday',
      };
      return days[weekday] ?? '';
    }

    String getEngMonth(int month) {
      const months = {
        1: 'January',
        2: 'February',
        3: 'March',
        4: 'April',
        5: 'May',
        6: 'June',
        7: 'July',
        8: 'August',
        9: 'September',
        10: 'October',
        11: 'November',
        12: 'December',
      };
      return months[month] ?? '';
    }

    final String dayStr = pickedDate.day.toString().padLeft(2, '0');
    final String monthStr = pickedDate.month.toString().padLeft(2, '0');
    final String yearStr = pickedDate.year.toString();

    final String gujDayStr = translateDigits(dayStr);
    final String gujMonthStr = translateDigits(monthStr);
    final String gujYearStr = translateDigits(yearStr);

    String timeSuffixEn = '';
    String timeSuffixGu = '';
    if (pickedTime != null) {
      final int hour = pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod;
      final String min = pickedTime.minute.toString().padLeft(2, '0');
      final String period = pickedTime.period == DayPeriod.am ? 'AM' : 'PM';
      final String periodGu = pickedTime.period == DayPeriod.am ? 'સવારે' : 'સાંજે';

      timeSuffixEn = ' at $hour:$min $period';
      timeSuffixGu = ', સમય: $periodGu ${translateDigits(hour.toString())}:${translateDigits(min)}';
    }

    final String f1En = 'Date: $dayStr/$monthStr/$yearStr$timeSuffixEn';
    final String f1Gu = 'તા. $gujDayStr/$gujMonthStr/$gujYearStr$timeSuffixGu';

    final String f2En = '${getEngDay(pickedDate.weekday)}, $dayStr ${getEngMonth(pickedDate.month)} $yearStr$timeSuffixEn';
    final String f2Gu = '${getGujDay(pickedDate.weekday)}, $gujDayStr ${getGujMonth(pickedDate.month)} $gujYearStr$timeSuffixGu';

    final String f3En = '$dayStr ${getEngMonth(pickedDate.month)} $yearStr$timeSuffixEn';
    final String f3Gu = '$gujDayStr ${getGujMonth(pickedDate.month)} $gujYearStr$timeSuffixGu';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Date Style", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(f1En, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(f1Gu, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                onTap: () {
                  onSave(f1En, f1Gu);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(f2En, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(f2Gu, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                onTap: () {
                  onSave(f2En, f2Gu);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text(f3En, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(f3Gu, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                onTap: () {
                  onSave(f3En, f3Gu);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTextEditor(BuildContext context) {
    if (_isDateField(widget.element)) {
      _showDatePickerFlow(context, widget.element, (en, gu) {
        widget.onTextEdit(en, gu);
      });
      return;
    }

    String currentEn = widget.element.content;
    String currentGu = widget.element.contentGujarati;
    final bool isGuj = widget.activeLanguage != 'English';
    final lang = context.read<LanguageProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(lang.editText, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: TransliterationField(
            initialText: widget.element.getDisplayText(widget.activeLanguage),
            isTransliterationOn: isGuj,
            language: widget.activeLanguage,
            label: lang.editContent,
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
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
            child: Text(lang.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF94C66),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              widget.onTextEdit(currentEn, currentGu);
              Navigator.pop(ctx);
            },
            child: Text(lang.save),
          ),
        ],
      ),
    );
  }

  Alignment _getAlignment(TemplateElement el) {
    switch (el.getTextAlignForLanguage(widget.activeLanguage)) {
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
