import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/language_model.dart';
import '../models/template_model.dart';
import '../models/page_model.dart';
import '../repositories/template_repository.dart';
import '../services/font_service.dart';
import '../services/language_registry.dart';

class AppDataProvider extends ChangeNotifier {
  final TemplateRepository _repository = TemplateRepository();
  final FontService _fontService = FontService();
  
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

  AppDataProvider() {
    _initStreams();
    // Dynamically listen to active fonts and register them in engine
    _fontService.initFontListener();
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

    void updateLoadingState() {
      if (categoriesLoaded && languagesLoaded && templatesLoaded) {
        if (_isLoading) {
          _isLoading = false;
          notifyListeners();
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

    // Safeguard: Force-hide loading spinner after 5 seconds to prevent infinite hang on clean slow boot
    Future.delayed(const Duration(seconds: 5), () {
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

  @override
  void dispose() {
    _categoriesSub?.cancel();
    _languagesSub?.cancel();
    _templatesSub?.cancel();
    super.dispose();
  }
}
