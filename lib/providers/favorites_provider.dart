import 'dart:async';
import 'package:flutter/material.dart';
import '../models/template_model.dart';
import '../repositories/template_repository.dart';
import '../providers/app_data_provider.dart';
import '../services/firestore_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final TemplateRepository _templateRepository = TemplateRepository();
  final List<TemplateModel> _favoriteTemplates = [];
  AppDataProvider? _appData;

  StreamSubscription? _favoritesSubscription;
  StreamSubscription? _authSubscription;

  List<TemplateModel> get favorites => _favoriteTemplates;

  FavoritesProvider() {
    _init();
  }

  List<String> _favoriteIds = [];

  void setAppDataProvider(AppDataProvider appData) {
    _appData = appData;
    _updateFavorites();
  }

  void _init() {
    _authSubscription = FirestoreService().resolvedUidStream.listen((uid) {
      if (uid != null) {
        _subscribeToStreams();
      } else {
        _unsubscribeFromStreams();
        _favoriteIds.clear();
        _favoriteTemplates.clear();
        notifyListeners();
      }
    });

    final initialUid = FirestoreService().resolvedUid;
    if (initialUid != null) {
      _subscribeToStreams();
    }
  }

  void _subscribeToStreams() {
    _unsubscribeFromStreams();

    _favoritesSubscription = _templateRepository.watchFavoriteTemplateIds().listen((ids) {
      _favoriteIds = ids;
      _updateFavorites();
    });
  }

  void _updateFavorites() {
    _favoriteTemplates.clear();
    if (_appData != null) {
      for (var id in _favoriteIds) {
        final template = _appData!.getTemplateById(id);
        if (template != null) {
          _favoriteTemplates.add(template);
        }
      }
    }
    notifyListeners();
  }

  void _unsubscribeFromStreams() {
    _favoritesSubscription?.cancel();
  }

  bool isFavorite(TemplateModel template) {
    return _favoriteTemplates.any((t) => t.id == template.id);
  }

  Future<void> toggleFavorite(TemplateModel template) async {
    final currentlyFavorite = isFavorite(template);
    try {
      // Optistically toggle locally to make the UI snappy
      if (currentlyFavorite) {
        _favoriteTemplates.removeWhere((t) => t.id == template.id);
      } else {
        _favoriteTemplates.add(template);
      }
      notifyListeners();

      // Perform Firestore save
      await _templateRepository.toggleFavorite(template.id, !currentlyFavorite);
    } catch (e) {
      debugPrint("Failed to toggle favorite: $e");
      // Rollback if Firestore failed
      if (currentlyFavorite) {
        _favoriteTemplates.add(template);
      } else {
        _favoriteTemplates.removeWhere((t) => t.id == template.id);
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromStreams();
    super.dispose();
  }
}
