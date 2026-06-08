import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/font_model.dart';

class FontService {
  static final FontService _instance = FontService._internal();
  factory FontService() => _instance;
  FontService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Set<String> _registeredFonts = {};

  /// Static set of all font families that have been dynamically loaded and
  /// registered via FontLoader. Readable from anywhere without a FontService
  /// instance (e.g. from TemplateElement.getTextStyle).
  static final Set<String> registeredFamilies = {};


  /// Starts listening to the active fonts on Firestore and downloads/registers them
  void initFontListener() {
    _db.collection('fonts').snapshots().listen((snapshot) async {
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final font = FontModel.fromJson(data);
          if (font.isActive && font.fontFamily.isNotEmpty && font.fontUrl.isNotEmpty) {
            await loadFontDynamically(font.fontFamily, font.fontUrl);
          }
        } catch (e) {
          print("Error processing font doc: $e");
        }
      }
    });
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
        final response = await http.get(Uri.parse(url));
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
