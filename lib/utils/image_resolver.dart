import 'dart:io';

String resolveImageUrl(String path) {
  if (path.isEmpty) return '';
  
  var resolvedPath = path;
  
  // Replace localhost or local IP URLs with the live backend URL
  if (resolvedPath.contains('localhost:') || 
      resolvedPath.contains('127.0.0.1:') || 
      resolvedPath.contains('10.0.2.2:') || 
      resolvedPath.contains('192.168.')) {
    final uri = Uri.tryParse(resolvedPath);
    if (uri != null) {
      resolvedPath = 'https://amantran-admin-backend.onrender.com${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    }
  }

  if (resolvedPath.startsWith('http://') || resolvedPath.startsWith('https://')) {
    return resolvedPath;
  }
  if (resolvedPath.startsWith('/assets/') || resolvedPath.startsWith('assets/')) {
    final cleanPath = resolvedPath.startsWith('/') ? resolvedPath : '/$resolvedPath';
    return 'https://amantran-admin-backend.onrender.com$cleanPath';
  }
  return resolvedPath;
}

/// Checks if the image path is a network asset (either standard http/https or dynamic unbundled assets).
bool isNetworkImage(String path) {
  if (path.isEmpty) return false;
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
  
  // 1. Must start with assets/
  if (!clean.startsWith('assets/')) return false;
  
  // 2. Check if it's a theme template
  if (clean.startsWith('assets/templates/theme_')) {
    return true;
  }
  
  // 3. Check if it's wedding templete1
  if (clean.startsWith('assets/images/wedding/templete1/')) {
    return true;
  }
  
  // 4. Check if it's in the root of assets/images/
  if (clean.startsWith('assets/images/')) {
    if (clean.contains('/royal_wedding/') || clean.contains('/defaults/') || clean.contains('/stickers/')) {
      return false;
    }
    // Count slashes in the path to identify deep subfolders
    final slashCount = '/'.allMatches(clean).length;
    if (slashCount > 3) {
      return false;
    }
    return true;
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
