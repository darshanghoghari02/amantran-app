import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import '../config/api_config.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Uploads a file to Laravel backend under `/api/uploads/single`.
  /// Allowed folders/types: `general`, `templates`, `previews` (mapped to `general`).
  /// Laravel accepted types: templates, categories, users, fonts, logos, qr, general
  Future<String> uploadFile({
    required File file,
    required String folder, // e.g. 'general', 'templates', 'previews'
    String? customFileName,
  }) async {
    // Map Flutter-side folder names to Laravel-accepted upload types
    final typeMap = {
      'uploads': 'general',
      'previews': 'general',
      'templates': 'templates',
      'categories': 'categories',
      'fonts': 'fonts',
      'logos': 'logos',
      'users': 'users',
      'qr': 'qr',
      'general': 'general',
    };
    final laravelType = typeMap[folder] ?? 'general';

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/api/uploads/single?type=$laravelType'),
      );
      
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        print("Error getting token for upload: $e");
      }
      
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final String path = json['filePath'] ?? json['flutterPath'] ?? '';
        if (path.isEmpty) {
          throw Exception("Server did not return a valid file path.");
        }
        // Convert relative path to full URL
        if (path.startsWith('/')) {
          return '${ApiConfig.baseUrl}$path';
        }
        return path;
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? "Upload failed";
        throw Exception("Server error: $errorMsg (Status ${response.statusCode})");
      }
    } catch (e) {
      throw Exception("Failed to upload file to backend: $e");
    }
  }

  /// Deletes a file from local backend using its URL.
  Future<void> deleteFile(String fileUrl) async {
    try {
      // Extract relative path from full URL
      String filePath = fileUrl;
      if (fileUrl.startsWith(ApiConfig.baseUrl)) {
        filePath = fileUrl.replaceFirst(ApiConfig.baseUrl, '');
      }

      print("Deleting file with path: $filePath");

      final response = await ApiClient.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/uploads/'),
        body: jsonEncode({'filePath': filePath}),
      );

      print("Delete response status: ${response.statusCode}");
      print("Delete response body: ${response.body}");

      if (response.statusCode != 200) {
        print("Failed to delete file from backend: status=${response.statusCode}");
      } else {
        print("File deleted successfully from backend");
      }
    } catch (e) {
      print("Failed to delete file from backend: $e");
    }
  }
}
