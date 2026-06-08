import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_design.dart';
import '../models/template_model.dart';
import '../models/template_element.dart';
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

    try {
      final UserDesign finalDesign = design.id == targetId
          ? design
          : UserDesign(
              id: targetId,
              template: design.template,
              elements: design.elements,
              updatedAt: DateTime.now(),
              isDraft: design.isDraft,
            );

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
      debugPrint("Failed to save draft to Firestore: $e");
    }
    return targetId;
  }

  String _getBrideNameEn(List<TemplateElement> elements) {
    try {
      final el = elements.firstWhere((e) => e.id == 'p1_bride' || e.id.startsWith('p1_bride_'));
      return el.content.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getBrideNameGu(List<TemplateElement> elements) {
    try {
      final el = elements.firstWhere((e) => e.id == 'p1_bride' || e.id.startsWith('p1_bride_'));
      return el.contentGujarati.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getGroomNameEn(List<TemplateElement> elements) {
    try {
      final el = elements.firstWhere((e) => e.id == 'p1_groom' || e.id.startsWith('p1_groom_'));
      return el.content.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    } catch (_) {
      return '';
    }
  }

  String _getGroomNameGu(List<TemplateElement> elements) {
    try {
      final el = elements.firstWhere((e) => e.id == 'p1_groom' || e.id.startsWith('p1_groom_'));
      return el.contentGujarati.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    } catch (_) {
      return '';
    }
  }

  bool _areNamesEqual(List<TemplateElement> els1, List<TemplateElement> els2) {
    final b1En = _getBrideNameEn(els1);
    final b1Gu = _getBrideNameGu(els1);
    final g1En = _getGroomNameEn(els1);
    final g1Gu = _getGroomNameGu(els1);

    final b2En = _getBrideNameEn(els2);
    final b2Gu = _getBrideNameGu(els2);
    final g2En = _getGroomNameEn(els2);
    final g2Gu = _getGroomNameGu(els2);

    final placeholders = {
      '', 'groom name', 'bride name', 'groom', 'bride', 'var', 'kanya',
      'વરનું નામ', 'કન્યાનું નામ', 'વર', 'કન્યા', 'ચિ.', 'chi.', 'શુભ', 'શુભ લગ્ન'
    };

    final b1EnNorm = b1En.toLowerCase();
    final b2EnNorm = b2En.toLowerCase();
    final g1EnNorm = g1En.toLowerCase();
    final g2EnNorm = g2En.toLowerCase();

    if (placeholders.contains(b1EnNorm) || placeholders.contains(g1EnNorm) ||
        placeholders.contains(b2EnNorm) || placeholders.contains(g2EnNorm)) {
      return false;
    }

    final brideMatches = (b1EnNorm == b2EnNorm && b1EnNorm.isNotEmpty) || (b1Gu.trim() == b2Gu.trim() && b1Gu.trim().isNotEmpty);
    final groomMatches = (g1EnNorm == g2EnNorm && g1EnNorm.isNotEmpty) || (g1Gu.trim() == g2Gu.trim() && g1Gu.trim().isNotEmpty);

    return brideMatches && groomMatches;
  }

  Future<void> saveCompleted(UserDesign design) async {
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
      debugPrint("Failed to save completed card to Firestore: $e");
    }
  }

  Future<void> deleteDesign(String id) async {
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
      debugPrint("Failed to delete design from Firestore: $e");
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
    };
  }

  UserDesign userDesignFromJson(Map<String, dynamic> json) {
    final templateId = json['templateId']?.toString() ?? '';
    TemplateModel matchedTemplate = _appData?.getTemplateById(templateId) ?? TemplateModel(
      id: templateId,
      title: 'Unknown Template',
      slug: '',
      thumbnail: '',
      previewImage: '',
      categoryId: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final List<dynamic>? elementsList = json['elements'];
    final List<TemplateElement> parsedElements = [];
    if (elementsList != null) {
      for (var item in elementsList) {
        if (item is Map) {
          final Map<String, dynamic> elemJson = Map<String, dynamic>.from(item);
          parsedElements.add(TemplateElement.fromJson(elemJson));
        }
      }
    }

    // Try to parse updatedAt safely. If Firestore serverTimestamp is used, it might be represented in different ways.
    DateTime updatedAt = DateTime.now();
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now();
      } else if (json['updatedAt'] is Timestamp) {
        updatedAt = (json['updatedAt'] as Timestamp).toDate();
      }
    }

    return UserDesign(
      id: json['id']?.toString() ?? '',
      template: matchedTemplate,
      elements: parsedElements,
      updatedAt: updatedAt,
      isDraft: json['isDraft'] == true,
    );
  }

}
