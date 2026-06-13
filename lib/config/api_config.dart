import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiConfig {
  static String _resolvedUrl = '';

  /// Returns the dynamically resolved URL, or falls back to local machine defaults.
  static String get baseUrl {
    if (_resolvedUrl.isNotEmpty) {
      return _resolvedUrl;
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5000';
      }
    } catch (_) {}
    return 'http://localhost:5000';
  }

  /// Attempts to discover the running Express backend across multiple local interfaces.
  /// Speeds up connection setups for Emulators, Simulators, and Physical Wi-Fi devices.
  static Future<void> resolveBaseUrl() async {
    final hosts = [
      'http://localhost:5000',
      'http://10.0.2.2:5000',
      'http://192.168.1.68:5000', // Host PC's current local Wi-Fi IP address
    ];

    for (final url in hosts) {
      try {
        final response = await http
            .get(Uri.parse('$url/api/app/categories'))
            .timeout(const Duration(milliseconds: 1500));
            
        if (response.statusCode == 200) {
          _resolvedUrl = url;
          print("🌐 Resolved ApiConfig.baseUrl to: $_resolvedUrl");
          return;
        }
      } catch (_) {
        // Continue and try the next potential host
      }
    }

    // Default fallback if no host responded
    try {
      if (Platform.isAndroid) {
        _resolvedUrl = 'http://10.0.2.2:5000';
      } else {
        _resolvedUrl = 'http://localhost:5000';
      }
    } catch (_) {
      _resolvedUrl = 'http://localhost:5000';
    }
    print("🌐 Dynamic host discovery failed. Defaulting to fallback: $_resolvedUrl");
  }
}
