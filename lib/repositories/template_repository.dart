import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../services/firestore_service.dart';
import '../services/interaction_service.dart';
import '../models/category_model.dart';
import '../models/language_model.dart';
import '../models/template_model.dart';
import '../models/page_model.dart';
import '../models/template_element.dart';

class TemplateRepository {
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static const String _templatesCollection = 'templates';
  static const String _cacheBoxName = 'cms_cache';

  // ────────────────────────────────────────────────────────
  // 🔥 GLOBAL CONTENT STREAMS (FROM ADMIN + CACHE)
  // ────────────────────────────────────────────────────────

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

    yield* _db.collection('categories').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => CategoryModel.fromJson(doc.data(), doc.id)).toList();
      
      Hive.openBox(_cacheBoxName).then((box) {
        final cacheData = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();
        box.put('categories', cacheData);
      });

      return list;
    });
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

    yield* _db.collection('languages').snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => LanguageModel.fromJson(doc.data(), doc.id)).toList();
      
      Hive.openBox(_cacheBoxName).then((box) {
        final cacheData = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();
        box.put('languages', cacheData);
      });

      return list;
    });
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

    Query query = _db.collection('templates');
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    yield* query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => TemplateModel.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList();
      
      if (categoryId == null || categoryId.isEmpty) {
        Hive.openBox(_cacheBoxName).then((box) {
          final cacheData = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();
          box.put('templates', cacheData);
        });
      }

      return list;
    });
  }

  Future<List<PageModel>> getTemplatePagesFromSubcollections(String templateId) async {
    final pagesSnapshot = await _db
        .collection('templates')
        .doc(templateId)
        .collection('pages')
        .orderBy('pageNumber')
        .get(const GetOptions(source: Source.server));

    if (pagesSnapshot.docs.isEmpty) {
      return [];
    }

    final List<PageModel> pages = [];
    for (int i = 0; i < pagesSnapshot.docs.length; i++) {
      final doc = pagesSnapshot.docs[i];
      final pageData = doc.data();
      final String pageId = doc.id;
      final String bg = pageData['backgroundImage']?.toString() ?? '';
      final int pageNum = (pageData['pageNumber'] as num?)?.toInt() ?? (i + 1);
      final double width = (pageData['width'] as num?)?.toDouble() ?? 1080.0;
      final double height = (pageData['height'] as num?)?.toDouble() ?? 1920.0;

      final elementsSnapshot = await _db
          .collection('templates')
          .doc(templateId)
          .collection('pages')
          .doc(pageId)
          .collection('elements')
          .orderBy('zIndex')
          .get(const GetOptions(source: Source.server));

      final List<TemplateElement> elements = elementsSnapshot.docs.map((elDoc) {
        final elData = elDoc.data();
        return TemplateElement.fromJson({
          'id': elDoc.id,
          'pageIndex': i,
          ...elData
        });
      }).toList();

      pages.add(PageModel(
        id: pageId,
        backgroundImage: bg,
        pageNumber: pageNum,
        width: width,
        height: height,
        elements: elements,
      ));
    }
    return pages;
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

    yield* _db
        .collection('templates')
        .doc(templateId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (!snapshot.exists || snapshot.data() == null) return <PageModel>[];

      final data = snapshot.data() as Map<String, dynamic>;
      final pagesList = data['pages'] as List? ?? [];

      if (pagesList.isNotEmpty) {
        final List<PageModel> list = [];
        for (int i = 0; i < pagesList.length; i++) {
          var pageData = pagesList[i];
          if (pageData is Map) {
            final mapData = Map<String, dynamic>.from(pageData);
            final pNum = (mapData['pageNumber'] as num?)?.toInt() ?? (i + 1);
            list.add(PageModel(
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
        final cacheData = list.map((p) => p.toJson()).toList();
        box.put('pages_$templateId', cacheData);
        return list;
      }

      // Try fetching from subcollections as backup
      try {
        final subPages = await getTemplatePagesFromSubcollections(templateId);
        if (subPages.isNotEmpty) {
          final box = await Hive.openBox(_cacheBoxName);
          final cacheData = subPages.map((p) => p.toJson()).toList();
          box.put('pages_$templateId', cacheData);
          return subPages;
        }
      } catch (e) {
        print("Error fetching template pages from subcollections, trying fallback: $e");
      }

      return <PageModel>[];
    });
  }

  Future<List<PageModel>> getTemplatePages(String templateId) async {
    try {
      // 1. First check the main document's pages array directly from the server to bypass stale offline/Hive caches
      final snapshot = await _db
          .collection('templates')
          .doc(templateId)
          .get(const GetOptions(source: Source.server));
          
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        final pagesList = data['pages'] as List? ?? [];
        if (pagesList.isNotEmpty) {
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
      }
    } catch (e) {
      print("Error loading template pages from main document server snapshot: $e");
    }

    try {
      // 2. Try fetching from subcollections as a backup
      final subPages = await getTemplatePagesFromSubcollections(templateId);
      if (subPages.isNotEmpty) {
        final box = await Hive.openBox(_cacheBoxName);
        final cacheData = subPages.map((p) => p.toJson()).toList();
        await box.put('pages_$templateId', cacheData);
        return subPages;
      }
    } catch (e) {
      print("Error loading template pages from subcollections, trying fallback: $e");
    }

    try {
      // 3. Fallback to cached pages if server fetch fails
      final box = await Hive.openBox(_cacheBoxName);
      final List<dynamic>? cached = box.get('pages_$templateId');
      if (cached != null) {
        return cached.map((e) => PageModel.fromJson(Map<String, dynamic>.from(e), e['id'] ?? '')).toList();
      }
    } catch (e) {
      print("Error loading cached pages: $e");
    }

    return [];
  }

  // ────────────────────────────────────────────────────────
  // 🔥 USER-SPECIFIC DATA
  // ────────────────────────────────────────────────────────

  Stream<List<String>> watchFavoriteTemplateIds() {
    try {
      return _firestoreService
          .getUserSubcollection(_templatesCollection)
          .where('isFavorite', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      print("Error watching favorite template IDs: $e");
      return Stream.value([]);
    }
  }

  Future<void> toggleFavorite(String templateId, bool isFavorite) async {
    try {
      final docRef = _firestoreService.getUserDoc(_templatesCollection, templateId);
      if (isFavorite) {
        await docRef.set({
          'id': templateId,
          'isFavorite': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await InteractionService.logInteraction(
          type: 'add_favorite',
          description: 'Added template to favorites',
          details: {'templateId': templateId},
        );
      } else {
        await docRef.delete();
        await InteractionService.logInteraction(
          type: 'remove_favorite',
          description: 'Removed template from favorites',
          details: {'templateId': templateId},
        );
      }
    } catch (e) {
      throw Exception("Failed to toggle template favorite: $e");
    }
  }

  Future<bool> isFavorite(String templateId) async {
    try {
      final doc = await _firestoreService.getUserDoc(_templatesCollection, templateId).get();
      return doc.exists && doc.data()?['isFavorite'] == true;
    } catch (e) {
      print("Error checking favorite status: $e");
      return false;
    }
  }
}
