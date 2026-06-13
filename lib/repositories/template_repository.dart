import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import '../config/api_config.dart';
import '../services/firestore_service.dart';
import '../services/interaction_service.dart';
import '../models/category_model.dart';
import '../models/language_model.dart';
import '../models/template_model.dart';
import '../models/page_model.dart';
import '../models/template_element.dart';

class TemplateRepository {
  static const String _cacheBoxName = 'cms_cache';

  // -------------------------------------------------------------
  // 🔥 GLOBAL CONTENT STREAMS (FROM ADMIN API + CACHE)
  // -------------------------------------------------------------

  Stream<List<CategoryModel>> watchCategories() async* {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('categories');
      if (cached != null) {
        yield cached.map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e), e['id'] ?? '')).toList();
      }
    } catch (e) {
      print("Error loading cached categories: $e");
    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/categories'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final list = jsonList.map((data) => CategoryModel.fromJson(Map<String, dynamic>.from(data), data['id'] ?? '')).toList();
        
        final box = await Hive.openBox(_cacheBoxName);
        await box.put('categories', jsonList);
        yield list;
      }
    } catch (e) {
      print("Error fetching categories from API: $e");
    }
  }

  Stream<List<LanguageModel>> watchLanguages() async* {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('languages');
      if (cached != null) {
        yield cached.map((e) => LanguageModel.fromJson(Map<String, dynamic>.from(e), e['id'] ?? '')).toList();
      }
    } catch (e) {
      print("Error loading cached languages: $e");
    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/languages'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final list = jsonList.map((data) => LanguageModel.fromJson(Map<String, dynamic>.from(data), data['id'] ?? '')).toList();
        
        final box = await Hive.openBox(_cacheBoxName);
        await box.put('languages', jsonList);
        yield list;
      }
    } catch (e) {
      print("Error fetching languages from API: $e");
    }
  }

  Stream<List<TemplateModel>> watchTemplates({String? categoryId}) async* {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('templates');
      if (cached != null) {
        final list = cached.map((e) => TemplateModel.fromJson(Map<String, dynamic>.from(e), e['id'] ?? '')).toList();
        if (categoryId != null && categoryId.isNotEmpty) {
          yield list.where((t) => t.categoryId == categoryId).toList();
        } else {
          yield list;
        }
      }
    } catch (e) {
      print("Error loading cached templates: $e");
    }

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/templates'));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final list = jsonList.map((data) => TemplateModel.fromJson(Map<String, dynamic>.from(data), data['id'] ?? '')).toList();
        
        if (categoryId == null || categoryId.isEmpty) {
          final box = await Hive.openBox(_cacheBoxName);
          await box.put('templates', jsonList);
        }
        
        if (categoryId != null && categoryId.isNotEmpty) {
          yield list.where((t) => t.categoryId == categoryId).toList();
        } else {
          yield list;
        }
      }
    } catch (e) {
      print("Error fetching templates from API: $e");
    }
  }

  Stream<List<PageModel>> watchTemplatePages(String templateId) async* {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('pages_$templateId');
      if (cached != null) {
        yield cached.map((e) => PageModel.fromJson(Map<String, dynamic>.from(e), e['id'] ?? '')).toList();
      }
    } catch (e) {
      print("Error loading cached pages: $e");
    }

    try {
      final pages = await getTemplatePages(templateId);
      yield pages;
    } catch (e) {
      print("Error watching template pages: $e");
    }
  }

  /// Returns cached pages instantly when available; refreshes from server in background.
  Future<List<PageModel>> getTemplatePagesCachedFirst(String templateId) async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('pages_$templateId');
      if (cached != null && cached.isNotEmpty) {
        final pages = cached.map((e) => PageModel.fromJson(Map<String, dynamic>.from(e), e['id']?.toString() ?? '')).toList();
        // Refresh from server without blocking the editor open.
        getTemplatePages(templateId);
        return pages;
      }
    } catch (e) {
      print('Error loading cached template pages: $e');
    }
    return getTemplatePages(templateId);
  }

  Future<List<PageModel>> getTemplatePages(String templateId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/templates/$templateId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final pagesList = data['pages'] as List? ?? [];
        final List<PageModel> pages = [];
        for (int i = 0; i < pagesList.length; i++) {
          var pageData = pagesList[i];
          if (pageData is Map) {
            final mapData = Map<String, dynamic>.from(pageData);
            final pNum = (mapData['pageNumber'] as num?)?.toInt() ?? (i + 1);
            pages.add(PageModel(
              id: mapData['id']?.toString() ?? 'page_$i',
              backgroundImage: mapData['backgroundImage']?.toString() ?? '',
              pageNumber: pNum,
              width: (mapData['width'] as num?)?.toDouble() ?? 1080.0,
              height: (mapData['height'] as num?)?.toDouble() ?? 1920.0,
              elements: (mapData['elements'] as List? ?? [])
                  .map<TemplateElement>((e) => TemplateElement.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList(),
            ));
          }
        }
        
        final box = await Hive.openBox(_cacheBoxName);
        final cacheData = pages.map((p) => p.toJson()).toList();
        await box.put('pages_$templateId', cacheData);
        return pages;
      }
    } catch (e) {
      print("Error loading template pages from API: $e");
    }

    // fallback to cache
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('pages_$templateId');
      if (cached != null) {
        return (cached as List)
            .map((e) => PageModel.fromJson(Map<String, dynamic>.from(e), e['id']?.toString() ?? ''))
            .toList();
      }
    } catch (e) {
      print("Error loading cached pages fallback: $e");
    }

    return [];
  }

  // -------------------------------------------------------------
  // 🔥 USER-SPECIFIC DATA (FAVORITES)
  // -------------------------------------------------------------

  Stream<List<String>> watchFavoriteTemplateIds() {
    final uid = FirestoreService().resolvedUid;
    if (uid == null) return Stream.value([]);
    
    return Stream.fromFuture(getFavoriteTemplateIds(uid));
  }

  Future<List<String>> getFavoriteTemplateIds(String userId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/favorites/$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => e.toString()).toList();
      }
    } catch (e) {
      print("Error fetching favorite template IDs: $e");
    }
    return [];
  }

  Future<void> toggleFavorite(String templateId, bool isFavorite) async {
    final uid = FirestoreService().resolvedUid;
    if (uid == null) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/favorites'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': uid,
          'templateId': templateId,
          'isFavorite': isFavorite
        }),
      );

      if (response.statusCode == 200) {
        await InteractionService.logInteraction(
          type: isFavorite ? 'add_favorite' : 'remove_favorite',
          description: isFavorite ? 'Added template to favorites' : 'Removed template from favorites',
          details: {'templateId': templateId},
        );
      } else {
        throw Exception("Failed to toggle favorite: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to toggle template favorite: $e");
    }
  }

  Future<bool> isFavorite(String templateId) async {
    final uid = FirestoreService().resolvedUid;
    if (uid == null) return false;
    try {
      final list = await getFavoriteTemplateIds(uid);
      return list.contains(templateId);
    } catch (e) {
      print("Error checking favorite status: $e");
      return false;
    }
  }
}
