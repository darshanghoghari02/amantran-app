import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiClient {
  static const String _authTokenKey = 'auth_token';

  static Future<Map<String, String>> _getHeaders(Map<String, String>? customHeaders) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      print("Error reading auth token for headers: $e");
    }

    return headers;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final mergedHeaders = await _getHeaders(headers);
    return http.get(url, headers: mergedHeaders);
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final mergedHeaders = await _getHeaders(headers);
    return http.post(url, headers: mergedHeaders, body: body);
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final mergedHeaders = await _getHeaders(headers);
    return http.put(url, headers: mergedHeaders, body: body);
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
    final mergedHeaders = await _getHeaders(headers);
    return http.delete(url, headers: mergedHeaders, body: body);
  }
}
