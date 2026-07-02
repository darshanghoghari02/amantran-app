import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  static String _resolvedUrl = '';

  // Web Client ID from Google Cloud Console (Wedding Invitation App project 6374728923)
  static const String googleClientId =
      '6374728923-6m354i7velgv4qdgas7gpn5371oeld6g.apps.googleusercontent.com';

  static const String productionUrl =
      'https://darkgoldenrod-stork-377172.hostingersite.com';

  static String get developmentUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  /// Cache version — bump this string whenever the backend changes significantly
  /// (e.g., switched from Node.js to Laravel) to bust stale Hive cache.
  static const String cacheVersion = 'v3_laravel_2026_prod';

  /// Returns the resolved URL. Points to productionUrl.
  static String get baseUrl {
    return _resolvedUrl.isNotEmpty ? _resolvedUrl : productionUrl;
  }

  /// Sets resolved URL to production URL.
  static Future<void> resolveBaseUrl() async {
    _resolvedUrl = productionUrl;
    debugPrint('🌐 ApiConfig: Resolved PRODUCTION server → $_resolvedUrl');
  }
}
