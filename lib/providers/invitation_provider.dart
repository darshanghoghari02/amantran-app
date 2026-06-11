import 'package:flutter/material.dart';
import 'dart:async';
import '../models/kankotri_data.dart';
import '../models/template_element.dart';
import '../models/page_model.dart';
import 'language_provider.dart';
import '../services/transliteration_engine.dart';
import '../services/language_registry.dart';

enum LogoType { preset, customSvg, customFile }

class LogoModel {
  LogoType type;
  String? presetAsset;
  String? customSvgPath;
  String? rawSvgContent;
  String? customFilePath; // For user-uploaded images from gallery

  LogoModel({
    this.type = LogoType.preset,
    this.presetAsset,
    this.customSvgPath,
    this.rawSvgContent,
    this.customFilePath,
  });
}

class InvitationProvider extends ChangeNotifier {
  // --- Logo ---
  LogoModel logo = LogoModel(
    type: LogoType.preset,
    presetAsset: 'assets/images/ganesh1.png',
  );

  void updateLogo(LogoModel newLogo) {
    logo = newLogo;
    _syncInternal();
    notifyListeners();
  }

  // --- Global State ---
  List<TemplateElement> elements = [];
  bool isGujarati = true;
  LanguageProvider? _lang;
  Timer? _debounce;
  Timer? _refineTimer;
  int _refineGeneration = 0;
  String templateCategory = 'Wedding';

  String _sanitizeCorruptedText(String text) {
    String res = text
        .replaceAll('ચિઇ', 'ચિ.')
        .replaceAll('તાઇ', 'તા.');
    
    // Replace any sequence of 4 or more 'ઇ' characters (optionally separated by spaces/newlines) with elegant dots
    res = res.replaceAll(RegExp(r'[ઇ\s]{4,}'), '...........................................');
    
    // Heal 'શ્રીલ' back to 'શ્રી,'
    res = res.replaceAll('શ્રીલ', 'શ્રી,');
    
    // Replace ૭ with / between Gujarati digits (e.g. ૨૫૭૦૧૭૨૦૨૬ -> ૨૫/૦૧/૨૦૨૬)
    res = res.replaceAllMapped(RegExp(r'([૦-૯])૭([૦-૯])'), (m) => '${m[1]}/${m[2]}');
    
    return res;
  }

  void setLanguageProvider(LanguageProvider lang) {
    _lang = lang;
  }

  void _syncInternal({String? invitationLanguage}) {
    if (_lang != null && elements.isNotEmpty) {
      applyLanguageInstant(_lang!, invitationLanguage: invitationLanguage);
    }
  }

  /// Debounced background translation — never blocks the UI.
  void scheduleLanguageRefine({
    bool force = false,
    Duration delay = const Duration(milliseconds: 900),
    String? invitationLanguage,
  }) {
    _refineTimer?.cancel();
    _refineTimer = Timer(delay, () {
      if (_lang == null) return;
      final generation = ++_refineGeneration;
      applyLanguageAsync(_lang!,
              force: force, invitationLanguage: invitationLanguage)
          .then((_) {
        if (generation == _refineGeneration) notifyListeners();
      });
    });
  }

  /// Shows Gujarati/English immediately, then Google-translates every other language.
  void applyLanguageInstant(LanguageProvider lang, {String? invitationLanguage}) {
    _lang = lang;
    final target = invitationLanguage ?? lang.activeInvitationLanguage;
    syncToElements(lang, invitationLanguage: target);
    _applyOfflineConversion(target);
    notifyListeners();
    if (target != 'English') {
      scheduleLanguageRefine(
        force: true,
        delay: const Duration(milliseconds: 150),
        invitationLanguage: target,
      );
    }
  }

  /// Google Translate for the full template (all admin-added languages).
  Future<void> applyLanguageAsync(LanguageProvider lang,
      {bool force = false, String? invitationLanguage}) async {
    _lang = lang;
    final target = invitationLanguage ?? lang.activeInvitationLanguage;
    syncToElements(lang, invitationLanguage: target);
    await transliterateAllElements(target, force: force);
    notifyListeners();
  }

  void _applyOfflineConversion(String targetLang) {
    if (!LanguageRegistry.instance.hasOfflineConversion(targetLang)) return;

    final langCode = TemplateElement.languageCodeFor(targetLang);
    for (final el in elements) {
      if (el.type != ElementType.text) continue;
      if ((el.contentMap[langCode] ?? '').isNotEmpty) continue;

      final gu = el.contentMap['gu'] ?? '';
      final en = el.content;
      final source = gu.isNotEmpty ? gu : en;
      if (source.isEmpty) continue;

      final converted = _instantScriptConvert(source, targetLang);
      if (converted.isNotEmpty && converted != source) {
        el.setLocalizedText(targetLang, converted);
      }
    }
  }

  String _instantScriptConvert(String source, String targetLang) {
    if (!TemplateElement.hasGujaratiScript(source)) return '';
    switch (targetLang) {
      case 'Hindi':
      case 'Marathi':
        return translateGujaratiToHindi(source);
      case 'Punjabi':
        return translateGujaratiToPunjabi(source);
      case 'Urdu':
        return _instantUrduFromGujarati(source);
      default:
        return '';
    }
  }

  /// Curated label if available; otherwise Gujarati bridge for Google Translate.
  String _curatedLabel(
      LanguageProvider lang, String invLang, String Function(String) getter) {
    if (invLang == 'English') return getter('English');
    if (invLang == 'Gujarati') return getter('Gujarati');
    final localized = getter(invLang);
    if (localized != getter('English')) return localized;
    return getter('Gujarati');
  }

  String _instantUrduFromGujarati(String gujarati) {
    const Map<String, String> phrases = {
      '|| શ્રી ગણેશાય નમઃ ||': '|| سری گنیشای نمہ ||',
      'શુભ વિવાહ': 'شادی مبارک',
      'સંગ': 'سنگ',
      'તા.': 'تاریخ',
      'ચિ.': 'محترم',
      'નિમંત્રક': 'نمنترک',
      'સ્નેહી સ્વજન': 'محترم مہمان',
    };
    for (final entry in phrases.entries) {
      if (gujarati.contains(entry.key)) {
        return gujarati.replaceAll(entry.key, entry.value);
      }
    }
    return translateGujaratiToHindi(gujarati);
  }

  Future<void> transliterateAllElements(String targetLang,
      {bool force = false}) async {
    if (targetLang == 'English') return;

    final engine = TransliterationEngine();
    final langCode = TemplateElement.languageCodeFor(targetLang);

    final textElements =
        elements.where((e) => e.type == ElementType.text).toList();
    const batchSize = 6;
    for (var i = 0; i < textElements.length; i += batchSize) {
      final batch = textElements.skip(i).take(batchSize);
      await Future.wait(batch.map((el) async {
        final gu = el.contentMap['gu'] ?? el.contentGujarati;
        final en = el.content;
        final existing = el.contentMap[langCode] ?? '';

        if (!force && existing.isNotEmpty) {
          final isBridge = existing == gu ||
              existing == en ||
              (gu.isNotEmpty && existing == gu);
          if (!isBridge) return;
        }

        final String source = gu.isNotEmpty
            ? gu
            : (en.isNotEmpty ? en : existing);
        if (source.isEmpty) return;

        final translated = await engine.translateAsync(source, targetLang);
        if (translated.isNotEmpty &&
            TemplateElement.isTranslationValid(translated, targetLang, source)) {
          el.setLocalizedText(targetLang, translated);
        }
      }));
    }
  }

  void initElements(List<TemplateElement> initialElements) {
    if (elements.isEmpty) {
      if (initialElements.any((e) => e.content == 'Chandla Vidhi' || e.contentGujarati == 'શુભ સગાઈ' || e.contentGujarati == 'ચાંદલા વિધિ')) {
        templateCategory = 'Engagement';
      } else if (initialElements.any((e) => e.content == 'Shrimant Sanskar' || e.contentGujarati == 'શ્રીમંત સંસ્કાર')) {
        templateCategory = 'Baby Shower';
      } else {
        templateCategory = 'Wedding';
      }
      elements = initialElements.map((e) {
        var el = e.copyWith();
        if (el.fontFamily == 'KAP011') {
          el.fontFamily = 'Noto Serif Gujarati';
        }
        // Auto-migrate old side-by-side couple layout coordinates to new stacked layout coordinates
        if (templateCategory == 'Engagement' || templateCategory == 'Baby Shower') {
          if (el.id == 'p1_groom' && (el.x == 200 || el.x == 205 || el.width == 130 || el.width == 135)) {
            el = el.copyWith(x: 30, y: 254, width: 300, height: 32, fontSize: 22, textAlign: TextAlign.center);
          } else if (el.id == 'p1_sang' && (el.x == 160 || el.x == 165)) {
            el = el.copyWith(x: 30, y: 288, width: 300, height: 22, fontSize: 14, textAlign: TextAlign.center);
          } else if (el.id == 'p1_bride' && (el.x == 20 || el.x == 30 || el.width == 130 || el.width == 135)) {
            el = el.copyWith(x: 30, y: 312, width: 300, height: 32, fontSize: 22, textAlign: TextAlign.center);
          } else if (el.id == 'p1_snehi' && el.contentGujarati.contains('સ્નેહી શ્રી')) {
            el = el.copyWith(
              content: 'Dear Guest, ...........................................',
              contentGujarati: 'સ્નેહી સ્વજન...........................................................................',
              x: 20, y: 172, width: 320, height: 22, fontSize: 13, textAlign: TextAlign.center
            );
          } else if (el.id == 'ganesh_image' && el.y == 30) {
            el = el.copyWith(x: 147, y: 25, width: 66, height: 66);
          } else if (el.id == 'p1_shlok' && el.y == 120) {
            el = el.copyWith(x: 30, y: 98, width: 300, height: 22, fontSize: 12, textAlign: TextAlign.center);
          } else if (el.id == 'p1_title' && el.y == 160) {
            el = el.copyWith(
              content: templateCategory == 'Engagement' ? 'Chandla Vidhi' : el.content,
              contentGujarati: templateCategory == 'Engagement' ? 'ચાંદલા વિધિ' : el.contentGujarati,
              x: 30, y: 125, width: 300, height: 42, fontSize: 32, textAlign: TextAlign.center
            );
          } else if (el.id == 'p3_invite_text1' && el.y == 260) {
            el = el.copyWith(x: 25, y: 198, width: 310, height: 52, fontSize: 11, textAlign: TextAlign.center);
          } else if (el.id == 'p3_parents' && el.y == 385) {
            el = el.copyWith(x: 25, y: 348, width: 310, height: 38, fontSize: 11, textAlign: TextAlign.center);
          } else if (el.id == 'p1_date' && el.y == 440) {
            el = el.copyWith(x: 30, y: 390, width: 300, height: 38, fontSize: 13, textAlign: TextAlign.center);
          } else if (el.id == 'p0_sthal_address_map_url' && el.y == 485) {
            el = el.copyWith(x: 25, y: 434, width: 310, height: 68, fontSize: 11, textAlign: TextAlign.center);
          } else if (el.id == 'p1_nimantrak_name' && el.y == 555) {
            el = el.copyWith(x: 30, y: 508, width: 300, height: 54, fontSize: 11, textAlign: TextAlign.center);
          }
        }
        return el;
      }).toList();
      _restoreLogoFromElements(elements);
      _populateFieldsFromElements();
      _syncInternal();
      scheduleLanguageRefine();
    }
  }

  Future<void> loadNewTemplate(List<TemplateElement> initialElements, {String? category, bool isNew = false}) async {
    if (category != null) {
      templateCategory = category;
    } else {
      if (initialElements.any((e) => e.content == 'Chandla Vidhi' || e.contentGujarati == 'શુભ સગાઈ' || e.contentGujarati == 'ચાંદલા વિધિ')) {
        templateCategory = 'Engagement';
      } else if (initialElements.any((e) => e.content == 'Shrimant Sanskar' || e.contentGujarati == 'શ્રીમંત સંસ્કાર')) {
        templateCategory = 'Baby Shower';
      } else {
        templateCategory = 'Wedding';
      }
    }
    elements = initialElements.map((e) {
      var el = e.copyWith();
      if (el.fontFamily == 'KAP011') {
        el.fontFamily = 'Noto Serif Gujarati';
      }
      // Auto-migrate old side-by-side couple layout coordinates to new stacked layout coordinates
      if (templateCategory == 'Engagement' || templateCategory == 'Baby Shower') {
        if (el.id == 'p1_groom' && (el.x == 200 || el.x == 205 || el.width == 130 || el.width == 135)) {
          el = el.copyWith(x: 30, y: 254, width: 300, height: 32, fontSize: 22, textAlign: TextAlign.center);
        } else if (el.id == 'p1_sang' && (el.x == 160 || el.x == 165)) {
          el = el.copyWith(x: 30, y: 288, width: 300, height: 22, fontSize: 14, textAlign: TextAlign.center);
        } else if (el.id == 'p1_bride' && (el.x == 20 || el.x == 30 || el.width == 130 || el.width == 135)) {
          el = el.copyWith(x: 30, y: 312, width: 300, height: 32, fontSize: 22, textAlign: TextAlign.center);
        } else if (el.id == 'p1_snehi' && el.contentGujarati.contains('સ્નેહી શ્રી')) {
          el = el.copyWith(
            content: 'Dear Guest, ...........................................',
            contentGujarati: 'સ્નેહી સ્વજન...........................................................................',
            x: 20, y: 172, width: 320, height: 22, fontSize: 13, textAlign: TextAlign.center
          );
        } else if (el.id == 'ganesh_image' && el.y == 30) {
          el = el.copyWith(x: 147, y: 25, width: 66, height: 66);
        } else if (el.id == 'p1_shlok' && el.y == 120) {
          el = el.copyWith(x: 30, y: 98, width: 300, height: 22, fontSize: 12, textAlign: TextAlign.center);
        } else if (el.id == 'p1_title' && el.y == 160) {
          el = el.copyWith(
            content: templateCategory == 'Engagement' ? 'Chandla Vidhi' : el.content,
            contentGujarati: templateCategory == 'Engagement' ? 'ચાંદલા વિધિ' : el.contentGujarati,
            x: 30, y: 125, width: 300, height: 42, fontSize: 32, textAlign: TextAlign.center
          );
        } else if (el.id == 'p3_invite_text1' && el.y == 260) {
          el = el.copyWith(x: 25, y: 198, width: 310, height: 52, fontSize: 11, textAlign: TextAlign.center);
        } else if (el.id == 'p3_parents' && el.y == 385) {
          el = el.copyWith(x: 25, y: 348, width: 310, height: 38, fontSize: 11, textAlign: TextAlign.center);
        } else if (el.id == 'p1_date' && el.y == 440) {
          el = el.copyWith(x: 30, y: 390, width: 300, height: 38, fontSize: 13, textAlign: TextAlign.center);
        } else if (el.id == 'p0_sthal_address_map_url' && el.y == 485) {
          el = el.copyWith(x: 25, y: 434, width: 310, height: 68, fontSize: 11, textAlign: TextAlign.center);
        } else if (el.id == 'p1_nimantrak_name' && el.y == 555) {
          el = el.copyWith(x: 30, y: 508, width: 300, height: 54, fontSize: 11, textAlign: TextAlign.center);
        }
      }
      return el;
    }).toList();
    _restoreLogoFromElements(elements);
    _populateFieldsFromElements();
    _syncInternal();
    scheduleLanguageRefine();
    notifyListeners();
  }

  void updateLanguage(bool guj) {
    isGujarati = guj;
    notifyListeners();
  }

  // --- Page 1 ---
  String familyNameEn = '';
  String familyNameGu = '';
  String nimantrakNameEn = '';
  String nimantrakNameGu = '';
  String villageEn = '';
  String villageGu = '';
  String talukaEn = '';
  String talukaGu = '';
  String districtEn = '';
  String districtGu = '';

  // --- Page 2 ---
  String groomNameEn = '';
  String groomNameGu = '';
  String brideNameEn = '';
  String brideNameGu = '';
  String weddingDate = '';

  // --- Page 3 ---
  List<EventModel> events = [
    EventModel(title: "Wedding Ceremony", titleGu: "લગ્ન વિધિ")
  ];

  // --- Page 4 ---
  String fatherNameEn = '';
  String fatherNameGu = '';
  String motherNameEn = '';
  String motherNameGu = '';
  String grandFatherNameEn = '';
  String grandFatherNameGu = '';
  String grandMotherNameEn = '';
  String grandMotherNameGu = '';
  String mamaNameEn = '';
  String mamaNameGu = '';
  String parentsNameFullEn = '';
  String parentsNameFullGu = '';

  // --- Page 5 ---
  String invitationTextEn = '';
  String invitationTextGu = '';
  String noGiftsTextEn = '';
  String noGiftsTextGu = '';

  // --- Page 6 ---
  String contact = '';
  String contact2 = '';
  String addressEn = '';
  String addressGu = '';
  String nimantrakListEn = '';
  String nimantrakListGu = '';

  // --- Page 7 ---
  String snehdhinEn = '';
  String snehdhinGu = '';
  String darshanabhilashiEn = '';
  String darshanabhilashiGu = '';
  String mameruMosalEn = '';
  String mameruMosalGu = '';
  String masiFoiLadlaEn = '';
  String masiFoiLadlaGu = '';
  String tahukoEn = '';
  String tahukoGu = '';

  // --- Helper Methods to read Element content ---
  String getGu(String id) {
    try {
      final text = elements.firstWhere((e) => e.id == id || e.id.startsWith('${id}_')).contentGujarati;
      return _sanitizeCorruptedText(text);
    } catch (_) {
      return '';
    }
  }

  String getEn(String id) {
    try {
      final text = elements.firstWhere((e) => e.id == id || e.id.startsWith('${id}_')).content;
      return _sanitizeCorruptedText(text);
    } catch (_) {
      return '';
    }
  }

  void _restoreLogoFromElements(List<TemplateElement> sourceElements) {
    try {
      final ganeshEl = sourceElements.firstWhere(
        (e) => e.id.toLowerCase().contains('ganesh') || (e.assetPath ?? '').toLowerCase().contains('ganesh'),
      );
      final path = ganeshEl.assetPath ?? '';
      if (path.isNotEmpty) {
        final pLower = path.toLowerCase();
        if (pLower.endsWith('.svg')) {
          logo = LogoModel(
            type: LogoType.customSvg,
            customSvgPath: path,
          );
        } else if (pLower.contains('ganesh1.png') || pLower.contains('ganesh.png')) {
          logo = LogoModel(
            type: LogoType.preset,
            presetAsset: 'assets/images/ganesh1.png',
          );
        } else if (pLower.contains('ganesh2.png')) {
          logo = LogoModel(
            type: LogoType.preset,
            presetAsset: 'assets/images/ganesh2.png',
          );
        } else if (pLower.contains('ganesh3.png')) {
          logo = LogoModel(
            type: LogoType.preset,
            presetAsset: 'assets/images/ganesh3.png',
          );
        } else {
          logo = LogoModel(
            type: LogoType.customFile,
            customFilePath: path,
          );
        }
      }
    } catch (_) {}
  }

  void _updateGaneshAsset(String path) {
    for (var el in elements) {
      final idLower = el.id.toLowerCase();
      final pathLower = (el.assetPath ?? '').toLowerCase();
      if (idLower.contains('ganesh') || pathLower.contains('ganesh')) {
        el.assetPath = path;
      }
    }
  }

  void _populateFieldsFromElements() {
    // Page 1 / Bride & Groom (Strip prefixes to keep clean input fields)
    brideNameGu = getGu('p1_bride').replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    brideNameEn = getEn('p1_bride').replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    groomNameGu = getGu('p1_groom').replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    groomNameEn = getEn('p1_groom').replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();

    // Date (Extract cleanly from Page 1 short date)
    final rawDate = getGu('p1_date');
    if (rawDate.isNotEmpty) {
      weddingDate = rawDate.replaceAll('તા. ', '').replaceAll('Date: ', '').trim();
    }

    // Nimantrak (Page 1)
    nimantrakNameGu = getGu('p1_nimantrak_name');
    nimantrakNameEn = getEn('p1_nimantrak_name');

    // Page 3 Lagnotsav
    parentsNameFullGu = getGu('p3_parents');
    parentsNameFullEn = getEn('p3_parents');
    invitationTextGu = getGu('p3_invite_text1');
    invitationTextEn = getEn('p3_invite_text1');

    // Page 5 Pratikshama
    familyNameGu = getGu('p5_family_title');
    familyNameEn = getEn('p5_family_title');
    nimantrakListGu = getGu('p5_nimantrak_names');
    nimantrakListEn = getEn('p5_nimantrak_names');
    noGiftsTextGu = getGu('p5_no_gifts');
    noGiftsTextEn = getEn('p5_no_gifts');

    // Page 6 Lists
    snehdhinGu = getGu('p6_list1a');
    snehdhinEn = getEn('p6_list1a');
    darshanabhilashiGu = getGu('p6_list2a');
    darshanabhilashiEn = getEn('p6_list2a');
    mameruMosalGu = getGu('p6_list3');
    mameruMosalEn = getEn('p6_list3');
    masiFoiLadlaGu = getGu('p6_list4');
    masiFoiLadlaEn = getEn('p6_list4');
    tahukoGu = getGu('p6_tahuko_text');
    tahukoEn = getEn('p6_tahuko_text');
  }

  // --- Update Method ---
  void updateField(VoidCallback updateAction, {String? fieldName}) {
    updateAction();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _syncInternal();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refineTimer?.cancel();
    super.dispose();
  }

  void updateEvent(int index, EventModel event, [LanguageProvider? lang]) {
    if (index < events.length) {
      events[index] = event;
    } else {
      events.add(event);
    }
    if (lang != null) {
      syncToElements(lang);
    } else if (_lang != null) {
      syncToElements(_lang!);
    }
    notifyListeners();
  }

  // --- Sync to Canvas Elements ---
  void syncToElements(LanguageProvider lang, {String? invitationLanguage}) {
    final invLang = invitationLanguage ?? lang.activeInvitationLanguage;
    String lbl(String Function(String) getter) =>
        _curatedLabel(lang, invLang, getter);

    void setEl(String id, String english, String localized) =>
        _updateElement(id, english, localized, targetLang: invLang);

    String userLocalized(String english, String gujarati) {
      if (invLang == 'English') return english;
      if (invLang == 'Gujarati') {
        return gujarati.isNotEmpty ? gujarati : english;
      }
      if (gujarati.isNotEmpty) {
        if (LanguageRegistry.instance.hasOfflineConversion(invLang)) {
          final converted = _instantScriptConvert(gujarati, invLang);
          if (converted.isNotEmpty) return converted;
        }
        return gujarati;
      }
      return english;
    }

    // Sync logo
    if (logo.type == LogoType.preset && logo.presetAsset != null) {
      _updateGaneshAsset(logo.presetAsset!);
    } else if (logo.type == LogoType.customSvg && logo.customSvgPath != null) {
      _updateGaneshAsset(logo.customSvgPath!);
    } else if (logo.type == LogoType.customFile && logo.customFilePath != null) {
      _updateGaneshAsset(logo.customFilePath!);
    }

    // Page 0 (Mangalik Prasango)
    setEl('p0_shlok1', lang.ganeshayNamahLabelFor('English'),
        lbl(lang.ganeshayNamahLabelFor));
    setEl('p0_title', lang.mangalikPrasangoLabelFor('English'),
        lbl(lang.mangalikPrasangoLabelFor));

    // Page 1 Title (Wedding / Engagement / Baby Shower Specifics)
    if (templateCategory == 'Engagement') {
      setEl('p1_title', 'Chandla Vidhi', 'ચાંદલા વિધિ');
    } else if (templateCategory == 'Baby Shower') {
      setEl('p1_title', 'Shrimant Sanskar', 'શ્રીમંત સંસ્કાર');
    } else {
      setEl('p1_title', lang.shubhVivahLabelFor('English'),
          lbl(lang.shubhVivahLabelFor));
    }
    setEl('p1_sang', lang.sangLabelFor('English'), lbl(lang.sangLabelFor));
    setEl('p1_shlok', lang.ganeshayNamahLabelFor('English'),
        lbl(lang.ganeshayNamahLabelFor));
    setEl('p1_snehi', lang.dearGuestLabelFor('English'),
        lbl(lang.dearGuestLabelFor));

    if (templateCategory == 'Engagement' || templateCategory == 'Baby Shower') {
      setEl('p1_nimantrak_title', 'Inviter', 'નિમંત્રક');
    } else {
      setEl('p1_nimantrak_title', lang.nimantrakLabelFor('English'),
          lbl(lang.nimantrakLabelFor));
    }

    // Page 2 (Sangeet Sandhya)
    setEl('p2_shlok', lang.ganeshayNamahLabelFor('English'),
        lbl(lang.ganeshayNamahLabelFor));
    setEl('p2_title', lang.sangeetSandhyaLabelFor('English'),
        lbl(lang.sangeetSandhyaLabelFor));
    setEl('p2_sang', lang.sangLabelFor('English'), lbl(lang.sangLabelFor));

    // Page 3 (Lagnotsav)
    setEl('p3_title', lang.lagnotsavLabelFor('English'),
        lbl(lang.lagnotsavLabelFor));
    setEl('p3_sang', lang.sangLabelFor('English'), lbl(lang.sangLabelFor));

    // Page 4 (Parinay Utsav)
    setEl('p4_title', lang.parinayUtsavLabelFor('English'),
        lbl(lang.parinayUtsavLabelFor));
    setEl('p4_sang', lang.sangLabelFor('English'), lbl(lang.sangLabelFor));

    // Page 0 & 4 (Events)
    if (events.isNotEmpty) {
      setEl(
          'p0_event1_title',
          '— ${events[0].title} —',
          userLocalized('— ${events[0].title} —', '— ${events[0].titleGu} —'));
      setEl(
          'p0_event1_date',
          '${lang.dateLabelFor('English')} ${events[0].date}',
          '${lbl(lang.taLabelFor)} ${events[0].dateGu.isNotEmpty ? events[0].dateGu : events[0].date}');
      setEl(
          'p0_event1_time',
          '${lang.timeLabelFor('English')} ${events[0].time}',
          '${lbl(lang.samayLabelFor)} ${events[0].timeGu.isNotEmpty ? events[0].timeGu : events[0].time}');

      setEl(
          'p4_event1_title',
          '— ${events[0].title} —',
          userLocalized('— ${events[0].title} —', '— ${events[0].titleGu} —'));
      setEl(
          'p4_event1_datetime',
          '${events[0].date}\n${events[0].time}',
          '${lbl(lang.taLabelFor)} ${events[0].dateGu.isNotEmpty ? events[0].dateGu : events[0].date}\n${events[0].timeGu.isNotEmpty ? events[0].timeGu : events[0].time}');

      if (events[0].place.isNotEmpty) {
        final placeLocalized =
            userLocalized(events[0].place, events[0].placeGu);
        setEl('p0_sthal_address', events[0].place, placeLocalized);
        setEl('p2_sthal_address', events[0].place, placeLocalized);
        setEl('p4_sthal_address', events[0].place, placeLocalized);
      }
    }

    if (events.length > 1) {
      setEl(
          'p0_event2_title',
          '— ${events[1].title} —',
          userLocalized('— ${events[1].title} —', '— ${events[1].titleGu} —'));
      setEl(
          'p0_event2_date',
          '${lang.dateLabelFor('English')} ${events[1].date}',
          '${lbl(lang.taLabelFor)} ${events[1].dateGu.isNotEmpty ? events[1].dateGu : events[1].date}');
      setEl(
          'p0_event2_time',
          '${lang.timeLabelFor('English')} ${events[1].time}',
          '${lbl(lang.samayLabelFor)} ${events[1].timeGu.isNotEmpty ? events[1].timeGu : events[1].time}');

      setEl(
          'p4_event2_title',
          '— ${events[1].title} —',
          userLocalized('— ${events[1].title} —', '— ${events[1].titleGu} —'));
      setEl(
          'p4_event2_datetime',
          '${events[1].date}\n${events[1].time}',
          '${lbl(lang.taLabelFor)} ${events[1].dateGu.isNotEmpty ? events[1].dateGu : events[1].date}\n${events[1].timeGu.isNotEmpty ? events[1].timeGu : events[1].time}');
    }

    if (events.length > 2) {
      setEl(
          'p0_event3_title',
          '— ${events[2].title} —',
          userLocalized('— ${events[2].title} —', '— ${events[2].titleGu} —'));
      setEl(
          'p0_event3_date',
          '${lang.dateLabelFor('English')} ${events[2].date}',
          '${lbl(lang.taLabelFor)} ${events[2].dateGu.isNotEmpty ? events[2].dateGu : events[2].date}');
      setEl(
          'p0_event3_time',
          '${lang.timeLabelFor('English')} ${events[2].time}',
          '${lbl(lang.samayLabelFor)} ${events[2].timeGu.isNotEmpty ? events[2].timeGu : events[2].time}');
    }

    // Bride & Groom / Couple Prefixes
    String bridePrefixEn = lang.chiLabelFor('English');
    String bridePrefixGu = lbl(lang.chiLabelFor);
    String groomPrefixEn = lang.chiLabelFor('English');
    String groomPrefixGu = lbl(lang.chiLabelFor);

    if (templateCategory == 'Engagement') {
      bridePrefixEn = 'Chi. ';
      bridePrefixGu = 'ચિ. ';
      groomPrefixEn = 'Chi. ';
      groomPrefixGu = 'ચિ. ';
    } else if (templateCategory == 'Baby Shower') {
      bridePrefixEn = 'Sou. ';
      bridePrefixGu = 'અ.સૌ. ';
      groomPrefixEn = 'Shri ';
      groomPrefixGu = 'શ્રી ';
    }

    final brideLocalized = userLocalized(
        '$bridePrefixEn$brideNameEn', '$bridePrefixGu$brideNameGu');
    final groomLocalized = userLocalized(
        '$groomPrefixEn$groomNameEn', '$groomPrefixGu$groomNameGu');
    setEl('p1_bride', '$bridePrefixEn$brideNameEn', brideLocalized);
    setEl('p2_bride', '$bridePrefixEn$brideNameEn', brideLocalized);
    setEl('p3_bride', '$bridePrefixEn$brideNameEn', brideLocalized);
    setEl('p4_bride', '$bridePrefixEn$brideNameEn', brideLocalized);

    setEl('p1_groom', '$groomPrefixEn$groomNameEn', groomLocalized);
    setEl('p2_groom', '$groomPrefixEn$groomNameEn', groomLocalized);
    setEl('p3_groom', '$groomPrefixEn$groomNameEn', groomLocalized);
    setEl('p4_groom', '$groomPrefixEn$groomNameEn', groomLocalized);

    // Dates (CRITICAL GUARD: Only update Cover Page short date; do NOT overwrite separate Sangeet & Lagnotsav dates!)
    if (weddingDate.isNotEmpty) {
      setEl('p1_date', '${lang.dateLabelFor('English')} $weddingDate',
          '${lbl(lang.taLabelFor)} $weddingDate');
    }

    // Nimantrak (Page 1)
    String nimEn = [fatherNameEn, motherNameEn, addressEn]
        .where((e) => e.isNotEmpty)
        .join('\n');
    String nimGu = [fatherNameGu, motherNameGu, addressGu]
        .where((e) => e.isNotEmpty)
        .join('\n');
    if (nimEn.isEmpty) nimEn = nimantrakNameEn;
    if (nimGu.isEmpty) nimGu = nimantrakNameGu;
    setEl('p1_nimantrak_name', nimEn, userLocalized(nimEn, nimGu));

    // Page 3
    setEl('p3_invite_text1', invitationTextEn,
        userLocalized(invitationTextEn, invitationTextGu));
    setEl('p3_parents', parentsNameFullEn,
        userLocalized(parentsNameFullEn, parentsNameFullGu));

    // Page 5
    setEl('p5_family_title', familyNameEn,
        userLocalized(familyNameEn, familyNameGu));
    setEl('p5_nimantrak_names', nimantrakListEn,
        userLocalized(nimantrakListEn, nimantrakListGu));
    setEl('p5_no_gifts', noGiftsTextEn,
        userLocalized(noGiftsTextEn, noGiftsTextGu));

    // Page 6 Lists
    setEl('p6_list1a', snehdhinEn, userLocalized(snehdhinEn, snehdhinGu));
    setEl('p6_list2a', darshanabhilashiEn,
        userLocalized(darshanabhilashiEn, darshanabhilashiGu));
    setEl('p6_list3', mameruMosalEn,
        userLocalized(mameruMosalEn, mameruMosalGu));
    setEl('p6_list4', masiFoiLadlaEn,
        userLocalized(masiFoiLadlaEn, masiFoiLadlaGu));
    setEl('p6_tahuko_text', tahukoEn, userLocalized(tahukoEn, tahukoGu));

    notifyListeners();
  }

  void _updateElement(String id, String english, String localized,
      {required String targetLang}) {
    try {
      final langCode = TemplateElement.languageCodeFor(targetLang);
      final matches =
          elements.where((e) => e.id == id || e.id.startsWith('${id}_'));
      for (final el in matches) {
        if (english.isNotEmpty) el.content = english;
        if (localized.isNotEmpty) {
          el.contentMap[langCode] = localized;
          if (langCode == 'gu') el.contentGujarati = localized;
        }
      }
    } catch (_) {}
  }

  void _updateAsset(String id, String path) {
    try {
      final matches = elements.where((e) => e.id == id || e.id.startsWith('${id}_'));
      for (final el in matches) {
        el.assetPath = path;
      }
    } catch (_) {}
  }

  // --- Inline Canvas Edit Sync Back to Provider ---
  void syncElementBackToProvider(TemplateElement element) {
    final id = element.id;
    if (id == 'p1_bride' || id == 'p2_bride' || id == 'p3_bride' || id == 'p4_bride') {
      brideNameGu = element.contentGujarati.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
      brideNameEn = element.content.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    } else if (id == 'p1_groom' || id == 'p2_groom' || id == 'p3_groom' || id == 'p4_groom') {
      groomNameGu = element.contentGujarati.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
      groomNameEn = element.content.replaceAll('ચિ. ', '').replaceAll('Chi. ', '').trim();
    } else if (id == 'p5_family_title') {
      familyNameGu = element.contentGujarati;
      familyNameEn = element.content;
    } else if (id == 'p3_invite_text1') {
      invitationTextGu = element.contentGujarati;
      invitationTextEn = element.content;
    } else if (id == 'p3_parents') {
      parentsNameFullGu = element.contentGujarati;
      parentsNameFullEn = element.content;
    } else if (id == 'p1_nimantrak_name') {
      nimantrakNameGu = element.contentGujarati;
      nimantrakNameEn = element.content;
    } else if (id == 'p5_nimantrak_names') {
      nimantrakListGu = element.contentGujarati;
      nimantrakListEn = element.content;
    } else if (id == 'p5_no_gifts') {
      noGiftsTextGu = element.contentGujarati;
      noGiftsTextEn = element.content;
    } else if (id == 'p6_list1a') {
      snehdhinGu = element.contentGujarati;
      snehdhinEn = element.content;
    } else if (id == 'p6_list2a') {
      darshanabhilashiGu = element.contentGujarati;
      darshanabhilashiEn = element.content;
    } else if (id == 'p6_list3') {
      mameruMosalGu = element.contentGujarati;
      mameruMosalEn = element.content;
    } else if (id == 'p6_list4') {
      masiFoiLadlaGu = element.contentGujarati;
      masiFoiLadlaEn = element.content;
    } else if (id == 'p6_tahuko_text') {
      tahukoGu = element.contentGujarati;
      tahukoEn = element.content;
    } else if (id == 'p1_date') {
      weddingDate = element.contentGujarati.replaceAll('તા. ', '').replaceAll('Date: ', '').trim();
    }
    notifyListeners();
  }

  void alignAndCenterAllElements({List<PageModel>? pages, bool force = false}) {
    for (var el in elements) {
      if (el.type == ElementType.text || el.type == ElementType.sticker || el.type == ElementType.image) {
        double pageWidth = 1080.0;
        if (pages != null && el.pageIndex >= 0 && el.pageIndex < pages.length) {
          pageWidth = pages[el.pageIndex].width;
        }
        
        // Skip left/right columns unless forced, or center everything if forced
        final String id = el.id.toLowerCase();
        final bool isLeftColumn = id.contains('event1') || 
                                  id.contains('bhojan_title') || 
                                  id.contains('bhojan_time') || 
                                  id.contains('list1a') || 
                                  id.contains('list2a') || 
                                  id.contains('list3a') || 
                                  id.endsWith('_left');
                                  
        final bool isRightColumn = id.contains('event2') || 
                                   id.contains('sthal_title') || 
                                   id.contains('sthal_address') || 
                                   id.contains('list1b') || 
                                   id.contains('list2b') || 
                                   id.contains('list3b') || 
                                   id.endsWith('_right');
        
        final bool shouldCenter = force || (!isLeftColumn && !isRightColumn);
        
        if (shouldCenter) {
          el.x = (pageWidth - el.width) / 2;
          if (el.type == ElementType.text) {
            el.textAlign = TextAlign.center;
          }
        }
      }
    }
    notifyListeners();
  }

  double getMaxConstraintWidthForElement(TemplateElement el) {
    final String id = el.id.toLowerCase();
    final bool isLeftColumn = id.contains('event1') || 
                              id.contains('bhojan_title') || 
                              id.contains('bhojan_time') || 
                              id.contains('list1a') || 
                              id.contains('list2a') || 
                              id.contains('list3a') || 
                              id.endsWith('_left');
                              
    final bool isRightColumn = id.contains('event2') || 
                               id.contains('sthal_title') || 
                               id.contains('sthal_address') || 
                               id.contains('list1b') || 
                               id.contains('list2b') || 
                               id.contains('list3b') || 
                               id.endsWith('_right');

    if (isLeftColumn || isRightColumn) {
      return 160.0;
    }
    return 320.0;
  }

  KankotriData get data {
    return KankotriData(
      customElements: elements,
      activeLanguage: _lang?.activeInvitationLanguage ?? 'English',
      ganeshImage: logo.presetAsset ?? 'assets/images/ganesh1.png',
      familyName: familyNameEn,
      familyNameGu: familyNameGu,
      village: villageEn,
      villageGu: villageGu,
      taluka: talukaEn,
      talukaGu: talukaGu,
      district: districtEn,
      districtGu: districtGu,
      groomName: groomNameEn,
      groomNameGu: groomNameGu,
      brideName: brideNameEn,
      brideNameGu: brideNameGu,
      events: events,
      fatherName: fatherNameEn,
      fatherNameGu: fatherNameGu,
      motherName: motherNameEn,
      motherNameGu: motherNameGu,
      grandFatherName: grandFatherNameEn,
      grandFatherNameGu: grandFatherNameGu,
      grandMotherName: grandMotherNameEn,
      grandMotherNameGu: grandMotherNameGu,
      mamaName: mamaNameEn,
      mamaNameGu: mamaNameGu,
      nimantrakName: nimantrakNameEn,
      nimantrakNameGu: nimantrakNameGu,
      invitationText: invitationTextEn,
      invitationTextGu: invitationTextGu,
      contact: contact,
      contact2: contact2,
      address: addressEn,
      addressGu: addressGu,
      weddingDate: weddingDate,
      weddingDateGu: weddingDate,
      nimantrakList: nimantrakListEn,
      nimantrakListGu: nimantrakListGu,
      parentsNameFull: parentsNameFullEn,
      parentsNameFullGu: parentsNameFullGu,
      snehdhin: snehdhinEn,
      snehdhinGu: snehdhinGu,
      darshanabhilashi: darshanabhilashiEn,
      darshanabhilashiGu: darshanabhilashiGu,
      mameruMosal: mameruMosalEn,
      mameruMosalGu: mameruMosalGu,
      masiFoiLadla: masiFoiLadlaEn,
      masiFoiLadlaGu: masiFoiLadlaGu,
      tahuko: tahukoEn,
      tahukoGu: tahukoGu,
      noGiftsText: noGiftsTextEn,
      noGiftsTextGu: noGiftsTextGu,
    );
  }
}
