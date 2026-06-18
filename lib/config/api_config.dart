import 'dart:io';
import 'package:http/http.dart' as http;

class ApiConfig {
  static String _resolvedUrl = '';
  
  // Web Client ID from Google Cloud Console (Wedding Invitation App project 6374728923)
  // Go to: console.cloud.google.com → Credentials → "Web client (auto created by Google Service)"
  // REPLACE THIS with the full Web Client ID shown in Google Cloud Console
  static const String googleClientId = '6374728923-6m354i7velgv4qdgas7gpn5371oeld6g.apps.googleusercontent.com';
  



  /// Returns the dynamically resolved URL, or falls back to live backend defaults.
  static String get baseUrl {
    if (_resolvedUrl.isNotEmpty) {
      return _resolvedUrl;
    }
    return 'https://tan-quetzal-596149.hostingersite.com';
  }

  /// Sets the base URL to the live production backend.
  static Future<void> resolveBaseUrl() async {
    _resolvedUrl = 'https://tan-quetzal-596149.hostingersite.com';
    print("🌐 Resolved ApiConfig.baseUrl to live backend: $_resolvedUrl");
  }
}
