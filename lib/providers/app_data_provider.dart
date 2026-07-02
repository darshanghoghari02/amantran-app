import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import 'package:hive/hive.dart';
import '../config/api_config.dart';
import '../models/category_model.dart';
import '../models/language_model.dart';
import '../models/template_model.dart';
import '../models/page_model.dart';
import '../repositories/template_repository.dart';
import '../services/font_service.dart';
import '../services/language_registry.dart';
import '../services/realtime_sse_client.dart';

class AppDataProvider extends ChangeNotifier {
  final TemplateRepository _repository = TemplateRepository();
  final FontService _fontService = FontService();

  Future<Box> _getCacheBox() async {
    const name = 'cms_cache';
    if (Hive.isBoxOpen(name)) {
      return Hive.box(name);
    }
    return await Hive.openBox(name);
  }
  
  List<CategoryModel> _categories = [];
  List<LanguageModel> _languages = [];
  List<TemplateModel> _allTemplates = [];

  bool _isLoading = true;
  String? _errorMessage;

  List<CategoryModel> get categories => _categories;
  List<LanguageModel> get languages => _languages;
  List<TemplateModel> get allTemplates => _allTemplates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  bool get isEmpty => !_isLoading && _allTemplates.isEmpty && _categories.isEmpty;

  StreamSubscription? _categoriesSub;
  StreamSubscription? _languagesSub;
  StreamSubscription? _templatesSub;
  Timer? _refreshTimer;
  RealtimeSSEClient? _sseClient;
  Timer? _fallbackPollTimer;

  bool _isFallbackPollingActive = false;
  DateTime? _lastRefreshTime;

  void _startFallbackPolling() {
    if (_isFallbackPollingActive) return;
    _isFallbackPollingActive = true;
    _pollData();
  }

  void _stopFallbackPolling() {
    _isFallbackPollingActive = false;
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
  }

  void _pollData() async {
    _fallbackPollTimer?.cancel();
    if (!_isFallbackPollingActive) return;

    debugPrint('🔄 SSE Fallback: Polling data from server...');
    try {
      await refreshDataSilently();
    } catch (e) {
      debugPrint('Error during fallback poll: $e');
    }

    if (_isFallbackPollingActive) {
      // 15 seconds in debug mode, 60 seconds in production
      final duration = kDebugMode ? const Duration(seconds: 15) : const Duration(seconds: 60);
      _fallbackPollTimer = Timer(duration, _pollData);
    }
  }

  AppDataProvider() {
    _initWithCacheBust();
    // Dynamically listen to active fonts and register them in engine
    _fontService.initFontListener();

    // Background data polling every 5 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      refreshDataSilently();
    });
  }

  Future<void> _initWithCacheBust() async {
    // Clear stale Hive cache if the backend/version has changed
    await _repository.bustCacheIfVersionChanged();
    _initStreams();
  }

  Future<void> _initSSEAfterResolution() async {
    // Wait for baseUrl to be resolved before initializing SSE
    await ApiConfig.resolveBaseUrl();
    _initSSE();
  }

  void _initStreams() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _categoriesSub?.cancel();
    _languagesSub?.cancel();
    _templatesSub?.cancel();

    bool categoriesLoaded = false;
    bool languagesLoaded = false;
    bool templatesLoaded = false;

    bool sseInitialized = false;
    void updateLoadingState() {
      if (categoriesLoaded && languagesLoaded && templatesLoaded) {
        if (_isLoading) {
          _isLoading = false;
          notifyListeners();
        }
        if (!sseInitialized) {
          sseInitialized = true;
          _initSSEAfterResolution();
        }
      }
    }

    _categoriesSub = _repository.watchCategories().listen((data) {
      _categories = data..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      categoriesLoaded = true;
      _errorMessage = null;
      updateLoadingState();
      notifyListeners();
    }, onError: (e) {
      print("Error listening to categories: $e");
      _errorMessage = "Failed to load dynamic categories. Please check your internet connection.";
      _isLoading = false;
      notifyListeners();
    });

    _languagesSub = _repository.watchLanguages().listen((data) {
      _languages = data..sort((a, b) => a.name.compareTo(b.name));
      LanguageRegistry.instance.updateFromBackend(_languages);
      languagesLoaded = true;
      _errorMessage = null;
      updateLoadingState();
      notifyListeners();
    }, onError: (e) {
      print("Error listening to languages: $e");
      _isLoading = false;
      notifyListeners();
    });

    _templatesSub = _repository.watchTemplates().listen((data) {
      final activeTemplates = data.where((t) => t.isActive).toList();
      // Sort premium templates first
      activeTemplates.sort((a, b) {
        if (a.isPremium && !b.isPremium) return -1;
        if (!a.isPremium && b.isPremium) return 1;
        return 0;
      });
      _allTemplates = activeTemplates;
      templatesLoaded = true;
      _errorMessage = null;
      updateLoadingState();
      notifyListeners();
    }, onError: (e) {
      print("Error listening to templates: $e");
      _errorMessage = "Failed to load templates from CMS panel.";
      _isLoading = false;
      notifyListeners();
    });

    // Safeguard: Force-hide loading spinner after 2 seconds to prevent infinite hang on clean slow boot
    Future.delayed(const Duration(seconds: 2), () {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  void retryInit() {
    _initStreams();
  }

  List<TemplateModel> getTemplatesByCategory(String categoryId) {
    if (categoryId.isEmpty) return _allTemplates;
    return _allTemplates.where((t) => t.categoryId == categoryId).toList();
  }

  TemplateModel? getTemplateById(String id) {
    try {
      return _allTemplates.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  Stream<List<PageModel>> watchTemplatePages(String templateId) {
    return _repository.watchTemplatePages(templateId);
  }

  Future<List<PageModel>> getTemplatePages(String templateId) {
    return _repository.getTemplatePages(templateId);
  }

  Future<List<PageModel>> getTemplatePagesCachedFirst(String templateId) {
    return _repository.getTemplatePagesCachedFirst(templateId);
  }

  Future<void> refreshTemplateDetails(String templateId) async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/templates/$templateId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final template = TemplateModel.fromJson(Map<String, dynamic>.from(data), data['id'] ?? templateId);
        
        final index = _allTemplates.indexWhere((t) => t.id == templateId);
        if (index != -1) {
          _allTemplates[index] = template;
        } else {
          _allTemplates.add(template);
        }
        
        // Update Hive cache
        final box = await _getCacheBox();
        final List<dynamic>? cached = box.get('templates');
        if (cached != null) {
          final List<dynamic> updatedCached = cached.map((e) {
            if ((e['id'] ?? '') == templateId) {
              return data;
            }
            return e;
          }).toList();
          if (!updatedCached.any((e) => (e['id'] ?? '') == templateId)) {
            updatedCached.add(data);
          }
          await box.put('templates', updatedCached);
        }
        
        // Also fetch and update pages cache for this template
        await _repository.getTemplatePages(templateId);
        
        notifyListeners();
      }
    } catch (e) {
      print("Error refreshing template details: $e");
    }
  }

  Future<void> refreshDataSilently({bool force = false}) async {
    final now = DateTime.now();
    if (!force && _lastRefreshTime != null && now.difference(_lastRefreshTime!) < const Duration(seconds: 30)) {
      debugPrint("⏭️ Skipping silent refresh: last refresh was less than 30s ago");
      return;
    }
    _lastRefreshTime = now;

    // Run all 3 fetches in parallel — 3× faster than sequential awaits
    await Future.wait([
      _refreshCategories(),
      _refreshLanguages(),
      _refreshTemplates(),
    ]);
    notifyListeners();
  }

  Future<void> _refreshCategories() async {
    try {
      final r = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/categories'));
      if (r.statusCode == 200) {
        final List<dynamic> json = jsonDecode(r.body);
        _categories = json
            .map((d) => CategoryModel.fromJson(Map<String, dynamic>.from(d), d['id'] ?? ''))
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        final box = await _getCacheBox();
        await box.put('categories', json);
      }
    } catch (e) {
      print("Silent refresh categories error: $e");
    }
  }

  Future<void> _refreshLanguages() async {
    try {
      final r = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/languages'));
      if (r.statusCode == 200) {
        final List<dynamic> json = jsonDecode(r.body);
        _languages = json
            .map((d) => LanguageModel.fromJson(Map<String, dynamic>.from(d), d['id'] ?? ''))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        LanguageRegistry.instance.updateFromBackend(_languages);
        final box = await _getCacheBox();
        await box.put('languages', json);
      }
    } catch (e) {
      print("Silent refresh languages error: $e");
    }
  }

  Future<void> _refreshTemplates() async {
    try {
      final r = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/templates'));
      if (r.statusCode == 200) {
        final List<dynamic> json = jsonDecode(r.body);
        final active = json
            .map((d) => TemplateModel.fromJson(Map<String, dynamic>.from(d), d['id'] ?? ''))
            .where((t) => t.isActive)
            .toList()
          ..sort((a, b) {
            if (a.isPremium && !b.isPremium) return -1;
            if (!a.isPremium && b.isPremium) return 1;
            return 0;
          });
        _allTemplates = active;
        final box = await _getCacheBox();
        await box.put('templates', json);
      }
    } catch (e) {
      print("Silent refresh templates error: $e");
    }
  }

  void _initSSE() {
    final resolvedUrl = ApiConfig.baseUrl; // Use the already-resolved baseUrl
    _sseClient = RealtimeSSEClient(
      url: '$resolvedUrl/api/app/realtime',
      onConnected: () {
        debugPrint("✅ Realtime SSE Connected. Stopping fallback polling.");
        _stopFallbackPolling();
      },
      onDisconnected: () {
        debugPrint("⚠️ Realtime SSE Disconnected. Starting fallback polling.");
        _startFallbackPolling();
      },
      onEvent: (event) {
        final type = event['type']?.toString();
        if (type == 'refresh') {
          final collection = event['collection']?.toString();
          final action = event['action']?.toString();
          final id = event['id']?.toString() ?? '';
          _handleRealtimeUpdate(collection, action, id);
        }
      },
      onError: (err) {
        debugPrint("Realtime SSE connection error: $err. Starting fallback polling.");
        _startFallbackPolling();
      },
    );
    _sseClient?.connect();
    
    // Start fallback polling initially. It will be stopped once SSE connects.
    _startFallbackPolling();
  }

  Future<void> _handleRealtimeUpdate(String? collection, String? action, String id) async {
    print("🔄 Real-time Update Event: [Collection: $collection, Action: $action, ID: $id]");
    if (collection == 'categories') {
      await _refreshCategories();
      notifyListeners();
    } else if (collection == 'languages') {
      await _refreshLanguages();
      notifyListeners();
    } else if (collection == 'templates') {
      if (action == 'delete') {
        _allTemplates.removeWhere((t) => t.id == id);
        try {
          final box = await _getCacheBox();
          final List<dynamic>? cached = box.get('templates');
          if (cached != null) {
            final List<dynamic> updatedCached = cached.where((e) => (e['id'] ?? '') != id).toList();
            await box.put('templates', updatedCached);
          }
        } catch (e) {
          print("Error updating Hive cache on delete: $e");
        }
        notifyListeners();
      } else {
        await _refreshTemplates();
        if (id.isNotEmpty && (action == 'update' || action == 'add')) {
          await refreshTemplateDetails(id);
        }
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _sseClient?.dispose();
    _refreshTimer?.cancel();
    _fallbackPollTimer?.cancel();
    _categoriesSub?.cancel();
    _languagesSub?.cancel();
    _templatesSub?.cancel();
    super.dispose();
  }
}
