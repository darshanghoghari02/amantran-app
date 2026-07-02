import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'api_client.dart';
import '../config/api_config.dart';
import '../utils/image_resolver.dart';
import '../models/font_model.dart';

class FontService {
  static final FontService _instance = FontService._internal();
  factory FontService() => _instance;
  FontService._internal();

  final Set<String> _registeredFonts = {};

  /// Static set of all font families that have been dynamically loaded and
  /// registered via FontLoader. Readable from anywhere without a FontService
  /// instance (e.g. from TemplateElement.getTextStyle).
  static final Set<String> registeredFamilies = {};


  /// Starts listening to the active fonts on the backend API and downloads/registers them
  Future<void> initFontListener() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/fonts'));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        for (var item in list) {
          try {
            final font = FontModel.fromJson(Map<String, dynamic>.from(item));
            final resolvedUrl = resolveImageUrl(font.fontUrl);
            if (font.isActive && font.fontFamily.isNotEmpty && resolvedUrl.isNotEmpty) {
              await loadFontDynamically(font.fontFamily, resolvedUrl);
            }
          } catch (e) {
            print("Error processing font item: $e");
          }
        }
      } else {
        print("Failed to fetch fonts from backend: status=${response.statusCode}");
      }
    } catch (e) {
      print("Error in initFontListener: $e");
    }
  }

  /// Downloads and registers a font dynamically
  Future<void> loadFontDynamically(String fontFamily, String url) async {
    if (_registeredFonts.contains(fontFamily)) return;

    try {
      final cacheFile = await _getCacheFile(fontFamily);
      Uint8List fontBytes;

      if (await cacheFile.exists()) {
        fontBytes = await cacheFile.readAsBytes();
      } else {
        print("Downloading font: $fontFamily from $url");
        final response = await ApiClient.get(Uri.parse(url));
        if (response.statusCode == 200) {
          fontBytes = response.bodyBytes;
          await cacheFile.writeAsBytes(fontBytes);
        } else {
          throw Exception("Failed to download font: Status ${response.statusCode}");
        }
      }

      final fontLoader = FontLoader(fontFamily);
      fontLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
      await fontLoader.load();
      
      _registeredFonts.add(fontFamily);
      FontService.registeredFamilies.add(fontFamily);
      print("Successfully registered dynamic font: $fontFamily");
    } catch (e) {
      print("Error loading dynamic font $fontFamily: $e");
    }
  }

  Future<File> _getCacheFile(String fontFamily) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fontsDir = Directory('${appDir.path}/fonts');
    if (!await fontsDir.exists()) {
      await fontsDir.create(recursive: true);
    }
    // Clean name for safe filename
    final safeName = fontFamily.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return File('${fontsDir.path}/$safeName.ttf');
  }
}
