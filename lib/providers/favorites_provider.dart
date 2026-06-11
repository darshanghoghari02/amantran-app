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
  int get count => _favoriteTemplates.length;

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
    if (_appData == null) {
      notifyListeners();
      return;
    }

    final validIds = <String>[];
    for (final id in _favoriteIds) {
      final template = _appData!.getTemplateById(id);
      if (template != null) {
        _favoriteTemplates.add(template);
        validIds.add(id);
      }
    }

    // Remove stale entries (e.g. draft docs saved under templates collection)
    if (!_appData!.isLoading && validIds.length != _favoriteIds.length) {
      final orphans = _favoriteIds.where((id) => !validIds.contains(id)).toList();
      _favoriteIds = validIds;
      _cleanupOrphanFavorites(orphans);
    }

    notifyListeners();
  }

  Future<void> _cleanupOrphanFavorites(List<String> orphanIds) async {
    for (final id in orphanIds) {
      try {
        await _templateRepository.toggleFavorite(id, false);
      } catch (e) {
        debugPrint('Failed to cleanup orphan favorite $id: $e');
      }
    }
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
        _favoriteIds.remove(template.id);
      } else {
        _favoriteTemplates.add(template);
        if (!_favoriteIds.contains(template.id)) {
          _favoriteIds.add(template.id);
        }
      }
      notifyListeners();

      // Perform Firestore save
      await _templateRepository.toggleFavorite(template.id, !currentlyFavorite);
    } catch (e) {
      debugPrint("Failed to toggle favorite: $e");
      // Rollback if Firestore failed
      if (currentlyFavorite) {
        _favoriteTemplates.add(template);
        if (!_favoriteIds.contains(template.id)) {
          _favoriteIds.add(template.id);
        }
      } else {
        _favoriteTemplates.removeWhere((t) => t.id == template.id);
        _favoriteIds.remove(template.id);
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
