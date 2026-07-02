import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_design.dart';
import '../models/template_element.dart';
import '../models/template_model.dart';
import '../repositories/draft_repository.dart';
import '../providers/app_data_provider.dart';
import '../services/interaction_service.dart';
import '../services/firestore_service.dart';

class DesignsProvider extends ChangeNotifier {
  final DraftRepository _draftRepository = DraftRepository();
  final List<UserDesign> _designs = [];
  AppDataProvider? _appData;
  
  
  StreamSubscription? _draftsSubscription;
  StreamSubscription? _cardsSubscription;
  StreamSubscription? _authSubscription;

  List<UserDesign> get drafts {
    final list = _designs.where((d) => d.isDraft).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<UserDesign> get completed {
    final list = _designs.where((d) => !d.isDraft).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  DesignsProvider() {
    _init();
  }

  List<Map<String, dynamic>> _rawDrafts = [];
  List<Map<String, dynamic>> _rawCards = [];

  void setAppDataProvider(AppDataProvider appData) {
    _appData = appData;
    _reparseDesigns();
  }

  void _init() {
    _authSubscription = FirestoreService().resolvedUidStream.listen((uid) {
      if (uid != null) {
        _subscribeToStreams();
      } else {
        _unsubscribeFromStreams();
        _rawDrafts.clear();
        _rawCards.clear();
        _designs.clear();
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

    _draftsSubscription = _draftRepository.watchDrafts().listen((rawList) {
      _rawDrafts = rawList;
      _reparseDesigns();
    });

    _cardsSubscription = _draftRepository.watchCards().listen((rawList) {
      _rawCards = rawList;
      _reparseDesigns();
    });
  }

  void _unsubscribeFromStreams() {
    _draftsSubscription?.cancel();
    _cardsSubscription?.cancel();
  }

  Future<void> refreshDesigns() async {
    final uid = FirestoreService().resolvedUid;
    if (uid == null) return;

    try {
      final rawDrafts = await _draftRepository.fetchDrafts(uid);
      final rawCards = await _draftRepository.fetchCards(uid);
      _rawDrafts = rawDrafts;
      _rawCards = rawCards;
      _reparseDesigns();
    } catch (e) {
      debugPrint("Error refreshing designs: $e");
    }
  }

  void _reparseDesigns() {
    _designs.clear();

    for (var item in _rawDrafts) {
      try {
        final design = userDesignFromJson(item);
        _designs.add(design.copyWith(isDraft: true));
      } catch (e) {
        debugPrint("Error parsing draft from Firestore: $e");
      }
    }

    for (var item in _rawCards) {
      try {
        final design = userDesignFromJson(item);
        _designs.add(design.copyWith(isDraft: false));
      } catch (e) {
        debugPrint("Error parsing completed card from Firestore: $e");
      }
    }
    notifyListeners();
  }

  Future<String> saveDraft(UserDesign design) async {
    String targetId = design.id;
    
    // Check if there is an existing draft for the same template
    for (var d in _designs) {
      if (d.isDraft && d.id != design.id && d.template.id == design.template.id) {
        targetId = d.id;
        break;
      }
    }

    final UserDesign finalDesign = design.id == targetId
        ? design
        : UserDesign(
            id: targetId,
            template: design.template,
            elements: design.elements,
            updatedAt: DateTime.now(),
            isDraft: true,
          );

    // Instantly update in-memory collections and notify listeners
    _designs.removeWhere((d) => d.id == targetId || d.id == design.id);
    _designs.add(finalDesign);

    _rawDrafts.removeWhere((d) => d['id'] == targetId || d['id'] == design.id);
    _rawDrafts.add(userDesignToJson(finalDesign));

    notifyListeners();

    try {
      final json = userDesignToJson(finalDesign);
      await _draftRepository.saveDraft(targetId, json);
      
      // If we saved to an existing draft's ID, delete the temporary new draft ID from Firestore
      if (design.id != targetId) {
        await _draftRepository.deleteDraft(design.id);
      }

      await InteractionService.logInteraction(
        type: 'save_draft',
        description: 'Saved draft invitation design: ${design.template.title}',
        details: {
          'designId': targetId,
          'originalDesignId': design.id,
          'templateId': design.template.id,
          'isDraft': true,
        },
      );
    } catch (e) {
      debugPrint("Failed to save draft to database: $e");
    }
    return targetId;
  }



  Future<void> saveCompleted(UserDesign design) async {
    // Instantly update in-memory collections and notify listeners
    final completedDesign = design.copyWith(isDraft: false);
    _designs.removeWhere((d) => d.id == design.id);
    _designs.add(completedDesign);

    _rawDrafts.removeWhere((d) => d['id'] == design.id);
    _rawCards.removeWhere((d) => d['id'] == design.id);
    _rawCards.add(userDesignToJson(completedDesign));

    notifyListeners();

    try {
      final json = userDesignToJson(design);
      await _draftRepository.saveCompleted(design.id, json);
      await InteractionService.logInteraction(
        type: 'save_completed_card',
        description: 'Successfully finalized and saved completed invitation design: ${design.template.title}',
        details: {
          'designId': design.id,
          'templateId': design.template.id,
          'isDraft': false,
        },
      );
    } catch (e) {
      debugPrint("Failed to save completed card to database: $e");
    }
  }

  Future<void> deleteDesign(String id) async {
    // Instantly update in-memory collections and notify listeners
    _designs.removeWhere((d) => d.id == id);
    _rawDrafts.removeWhere((d) => d['id'] == id);
    _rawCards.removeWhere((d) => d['id'] == id);
    notifyListeners();

    try {
      await _draftRepository.deleteDraft(id);
      await _draftRepository.deleteCard(id);
      await InteractionService.logInteraction(
        type: 'delete_design',
        description: 'Deleted design from drafts and completed cards',
        details: {
          'designId': id,
        },
      );
    } catch (e) {
      debugPrint("Failed to delete design from database: $e");
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _unsubscribeFromStreams();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────
  // ⚡ JSON SERIALIZATION UTILS
  // ────────────────────────────────────────────────────────

  Map<String, dynamic> userDesignToJson(UserDesign design) {
    return {
      'id': design.id,
      'templateId': design.template.id,
      'updatedAt': design.updatedAt.toIso8601String(),
      'isDraft': design.isDraft,
      'elements': design.elements.map((e) => e.toJson()).toList(),
      'pdfName': design.pdfName,
    };
  }

  UserDesign userDesignFromJson(Map<String, dynamic> json) {
    var customizedData = json['customizedData'];
    Map<String, dynamic>? customizedMap;
    if (customizedData is Map) {
      customizedMap = Map<String, dynamic>.from(customizedData);
    } else if (customizedData is String && customizedData.isNotEmpty) {
      try {
        customizedMap = Map<String, dynamic>.from(jsonDecode(customizedData));
      } catch (_) {}
    }

    final templateId = json['templateId']?.toString() ?? customizedMap?['templateId']?.toString() ?? '';
    if (templateId.isEmpty) {
      throw Exception("Missing template ID");
    }

    final List<dynamic>? elementsList = json['elements'] ?? customizedMap?['elements'];
    final List<TemplateElement> parsedElements = [];
    if (elementsList != null) {
      for (var item in elementsList) {
        if (item is Map) {
          final Map<String, dynamic> elemJson = Map<String, dynamic>.from(item);
          parsedElements.add(TemplateElement.fromJson(elemJson));
        }
      }
    }

    // Try to parse updatedAt safely.
    DateTime updatedAt = DateTime.now();
    final rawUpdatedAt = json['updatedAt'] ?? customizedMap?['updatedAt'];
    if (rawUpdatedAt != null) {
      if (rawUpdatedAt is String) {
        updatedAt = DateTime.tryParse(rawUpdatedAt.toString()) ?? DateTime.now();
      } else if (rawUpdatedAt is Timestamp) {
        updatedAt = rawUpdatedAt.toDate();
      }
    }

    final rawIsDraft = json['isDraft'] ?? customizedMap?['isDraft'];
    final isDraft = rawIsDraft == true;
    final pdfName = json['pdfName']?.toString() ?? customizedMap?['pdfName']?.toString();

    final matchedTemplate = _appData?.getTemplateById(templateId);
    if (matchedTemplate == null) {
      debugPrint("Warning: Template $templateId is inactive or not found in backend. Creating fallback template.");
      // Create a fallback template to allow the design to load even if template is inactive
      final fallbackTemplate = TemplateModel(
        id: templateId,
        title: 'Template (Inactive)',
        slug: 'inactive-template',
        categoryId: 'unknown',
        thumbnail: '',
        previewImage: '',
        isActive: false,
        isPremium: false,
        includedInMonthlyPlan: false,
        includedInYearlyPlan: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return UserDesign(
        id: json['id']?.toString() ?? customizedMap?['id']?.toString() ?? '',
        template: fallbackTemplate,
        elements: parsedElements,
        updatedAt: updatedAt,
        isDraft: isDraft,
        pdfName: pdfName,
      );
    }

    return UserDesign(
      id: json['id']?.toString() ?? customizedMap?['id']?.toString() ?? '',
      template: matchedTemplate,
      elements: parsedElements,
      updatedAt: updatedAt,
      isDraft: isDraft,
      pdfName: pdfName,
    );
  }

}
