import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_resolver.dart';

/// A drop-in replacement for Image.network / Image.asset / Image.file
/// that automatically caches network images to disk and memory.
/// Resolves local, network, and file paths transparently.
class AppImage extends StatelessWidget {
  final String src;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.src,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;
    final cleaned = src.trim();

    if (isNetworkImage(cleaned)) {
      // Network image — use disk cache
      child = CachedNetworkImage(
        imageUrl: resolveImageUrl(cleaned),
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: width != null ? (width! * 2).toInt() : 800,
        memCacheHeight: height != null ? (height! * 2).toInt() : 1200,
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 1800,
        fadeInDuration: const Duration(milliseconds: 100),
        placeholder: (_, __) =>
            placeholder ??
            Container(
              color: Colors.grey.shade100,
            ),
        errorWidget: (_, __, ___) =>
            errorWidget ??
            Container(
              color: Colors.grey.shade100,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 24),
            ),
      );
    } else if (File(cleaned).existsSync()) {
      // Local file
      child = Image.file(
        File(cleaned),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            errorWidget ??
            Container(
              color: Colors.grey.shade100,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
      );
    } else {
      // Asset
      child = Image.asset(
        cleanAssetPath(cleaned),
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, __, ___) =>
            errorWidget ??
            Container(
              color: Colors.grey.shade100,
              child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
            ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}
