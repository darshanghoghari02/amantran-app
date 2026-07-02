import '../config/api_config.dart';
import 'package:flutter/foundation.dart';

String resolveImageUrl(String path) {
  if (path.isEmpty) return '';
  
  var resolvedPath = path;

  // Map local ganesh presets to backend stickers directory
  if (resolvedPath.endsWith('ganesh1.png') && !resolvedPath.contains('/stickers/')) {
    resolvedPath = 'assets/images/stickers/ganesh1.png';
  } else if (resolvedPath.endsWith('ganesh2.png') && !resolvedPath.contains('/stickers/')) {
    resolvedPath = 'assets/images/stickers/ganesh2.png';
  } else if (resolvedPath.endsWith('ganesh3.png') && !resolvedPath.contains('/stickers/')) {
    resolvedPath = 'assets/images/stickers/ganesh3.png';
  }

  // Normalize legacy /static/ paths to /assets/
  if (resolvedPath.contains('/static/')) {
    resolvedPath = resolvedPath.replaceAll('/static/', '/assets/');
  } else if (resolvedPath.startsWith('static/')) {
    resolvedPath = 'assets/${resolvedPath.substring(7)}';
  }
  
  // Cloudinary URLs — already permanent, return as-is
  if (resolvedPath.contains('res.cloudinary.com')) {
    return resolvedPath;
  }

  // Firebase Storage URLs — already permanent, return as-is
  if (resolvedPath.contains('firebasestorage.googleapis.com')) {
    return resolvedPath;
  }
  
  // Replace localhost or local IP URLs with the live backend URL
  if (resolvedPath.contains('localhost:') || 
      resolvedPath.contains('127.0.0.1:') || 
      resolvedPath.contains('10.0.2.2:') || 
      resolvedPath.contains('192.168.1.68:') ||
      resolvedPath.contains('192.168.')) {
    final uri = Uri.tryParse(resolvedPath);
    if (uri != null) {
      resolvedPath = '${ApiConfig.baseUrl}${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    }
  }

  if (resolvedPath.startsWith('http://') || resolvedPath.startsWith('https://')) {
    return resolvedPath;
  }
  if (resolvedPath.startsWith('/assets/') || resolvedPath.startsWith('assets/')) {
    final cleanPath = resolvedPath.startsWith('/') ? resolvedPath : '/$resolvedPath';
    final finalUrl = '${ApiConfig.baseUrl}$cleanPath';
    if (kDebugMode) {
      print('🖼️ Image Resolution: $path -> $finalUrl');
    }
    return finalUrl;
  }
  return resolvedPath;
}

/// Checks if the image path is a network asset (either standard http/https or dynamic unbundled assets).
bool isNetworkImage(String path) {
  if (path.isEmpty) return false;

  // Cloudinary URLs are always network images
  if (path.contains('res.cloudinary.com')) return true;

  // Firebase Storage URLs are always network images
  if (path.contains('firebasestorage.googleapis.com')) return true;

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return true;
  }
  if (path.startsWith('assets/') || path.startsWith('/assets/')) {
    return !_isBundledAsset(path);
  }
  return false;
}

/// Helper to check if an asset is physically bundled in the app.
bool _isBundledAsset(String path) {
  final clean = path.startsWith('/') ? path.substring(1) : path;
  
  // Whitelist of core UI assets physically bundled in the app package.
  // All templates, themes, stickers, and design assets must load from the backend API server.
  final bundledWhitelist = [
    'assets/images/invitation_logo.jpg',
    'assets/images/banner_image.png',
    'assets/images/placeholder.png',
    'assets/images/default_avatar.png',
  ];

  for (final allowed in bundledWhitelist) {
    if (clean == allowed || clean.endsWith(allowed)) {
      return true;
    }
  }
  
  return false;
}

/// Cleans an asset path by removing leading slash and ensuring it starts with standard 'assets/'.
String cleanAssetPath(String path) {
  if (path.isEmpty) return 'assets/images/banner_image.png';
  var cleaned = path;
  if (cleaned.startsWith('/')) {
    cleaned = cleaned.substring(1);
  }
  if (!cleaned.startsWith('assets/')) {
    cleaned = 'assets/$cleaned';
  }
  return cleaned;
}
