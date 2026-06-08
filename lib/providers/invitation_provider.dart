import 'package:flutter/material.dart';
import 'dart:async';
import '../models/kankotri_data.dart';
import '../models/template_element.dart';
import '../models/page_model.dart';
import 'language_provider.dart';
import '../services/transliteration_engine.dart';

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
    _syncInternal();
  }

  void _syncInternal() {
    if (_lang != null) {
      syncToElements(_lang!);
      transliterateAllElements(_lang!.activeInvitationLanguage);
    }
  }

  Future<void> transliterateAllElements(String targetLang) async {
    if (targetLang == 'English') return;

    final engine = TransliterationEngine();

    // Filter out all text elements with non-empty contents, skipping those that already have a handcrafted Gujarati translation
    final textElements = elements
        .where((e) =>
            e.type == ElementType.text &&
            e.content.isNotEmpty &&
            e.contentGujarati.isEmpty)
        .toList();

    // Query the transliteration engine concurrently in parallel using Future.wait
    final futures = textElements.map((el) async {
      final translated =
          await engine.transliterateAsync(el.content, lang: targetLang);
      if (translated.isNotEmpty) {
        el.contentGujarati = translated;
      }
    }).toList();

    await Future.wait(futures);
    notifyListeners();
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
  void syncToElements(LanguageProvider lang) {
    final invLang = lang.activeInvitationLanguage;

    // Sync logo
    if (logo.type == LogoType.preset && logo.presetAsset != null) {
      _updateGaneshAsset(logo.presetAsset!);
    } else if (logo.type == LogoType.customSvg && logo.customSvgPath != null) {
      _updateGaneshAsset(logo.customSvgPath!);
    } else if (logo.type == LogoType.customFile && logo.customFilePath != null) {
      _updateGaneshAsset(logo.customFilePath!);
    }

    // Page 0 (Mangalik Prasango)
    _updateElement('p0_shlok1', lang.ganeshayNamahLabelFor('English'),
        lang.ganeshayNamahLabelFor(invLang));
    _updateElement('p0_title', lang.mangalikPrasangoLabelFor('English'),
        lang.mangalikPrasangoLabelFor(invLang));

    // Page 1 Title (Wedding / Engagement / Baby Shower Specifics)
    if (templateCategory == 'Engagement') {
      _updateElement('p1_title', 'Chandla Vidhi', 'ચાંદલા વિધિ');
    } else if (templateCategory == 'Baby Shower') {
      _updateElement('p1_title', 'Shrimant Sanskar', 'શ્રીમંત સંસ્કાર');
    } else {
      _updateElement('p1_title', lang.shubhVivahLabelFor('English'),
          lang.shubhVivahLabelFor(invLang));
    }
    _updateElement(
        'p1_sang', lang.sangLabelFor('English'), lang.sangLabelFor(invLang));
    
    if (templateCategory == 'Engagement' || templateCategory == 'Baby Shower') {
      _updateElement('p1_nimantrak_title', 'Inviter', 'નિમંત્રક');
    } else {
      _updateElement('p1_nimantrak_title', lang.nimantrakLabelFor('English'),
          lang.nimantrakLabelFor(invLang));
    }

    // Page 2 (Sangeet Sandhya)
    _updateElement('p2_shlok', lang.ganeshayNamahLabelFor('English'),
        lang.ganeshayNamahLabelFor(invLang));
    _updateElement('p2_title', lang.sangeetSandhyaLabelFor('English'),
        lang.sangeetSandhyaLabelFor(invLang));
    _updateElement(
        'p2_sang', lang.sangLabelFor('English'), lang.sangLabelFor(invLang));

    // Page 3 (Lagnotsav)
    _updateElement('p3_title', lang.lagnotsavLabelFor('English'),
        lang.lagnotsavLabelFor(invLang));
    _updateElement(
        'p3_sang', lang.sangLabelFor('English'), lang.sangLabelFor(invLang));

    // Page 4 (Parinay Utsav)
    _updateElement('p4_title', lang.parinayUtsavLabelFor('English'),
        lang.parinayUtsavLabelFor(invLang));
    _updateElement(
        'p4_sang', lang.sangLabelFor('English'), lang.sangLabelFor(invLang));

    // Page 0 & 4 (Events)
    if (events.isNotEmpty) {
      _updateElement('p0_event1_title', '— ${events[0].title} —',
          '— ${events[0].titleGu} —');
      _updateElement(
          'p0_event1_date',
          '${lang.dateLabelFor('English')} ${events[0].date}',
          '${lang.taLabelFor(invLang)} ${events[0].dateGu.isNotEmpty ? events[0].dateGu : events[0].date}');
      _updateElement(
          'p0_event1_time',
          '${lang.timeLabelFor('English')} ${events[0].time}',
          '${lang.samayLabelFor(invLang)} ${events[0].timeGu.isNotEmpty ? events[0].timeGu : events[0].time}');

      _updateElement('p4_event1_title', '— ${events[0].title} —',
          '— ${events[0].titleGu} —');
      _updateElement(
          'p4_event1_datetime',
          '${events[0].date}\n${events[0].time}',
          '${lang.taLabelFor(invLang)} ${events[0].dateGu.isNotEmpty ? events[0].dateGu : events[0].date}\n${events[0].timeGu.isNotEmpty ? events[0].timeGu : events[0].time}');

      if (events[0].place.isNotEmpty) {
        _updateElement('p0_sthal_address', events[0].place, events[0].placeGu);
        _updateElement('p2_sthal_address', events[0].place, events[0].placeGu);
        _updateElement('p4_sthal_address', events[0].place, events[0].placeGu);
      }
    }

    if (events.length > 1) {
      _updateElement('p0_event2_title', '— ${events[1].title} —',
          '— ${events[1].titleGu} —');
      _updateElement(
          'p0_event2_date',
          '${lang.dateLabelFor('English')} ${events[1].date}',
          '${lang.taLabelFor(invLang)} ${events[1].dateGu.isNotEmpty ? events[1].dateGu : events[1].date}');
      _updateElement(
          'p0_event2_time',
          '${lang.timeLabelFor('English')} ${events[1].time}',
          '${lang.samayLabelFor(invLang)} ${events[1].timeGu.isNotEmpty ? events[1].timeGu : events[1].time}');

      _updateElement('p4_event2_title', '— ${events[1].title} —',
          '— ${events[1].titleGu} —');
      _updateElement(
          'p4_event2_datetime',
          '${events[1].date}\n${events[1].time}',
          '${lang.taLabelFor(invLang)} ${events[1].dateGu.isNotEmpty ? events[1].dateGu : events[1].date}\n${events[1].timeGu.isNotEmpty ? events[1].timeGu : events[1].time}');
    }

    if (events.length > 2) {
      _updateElement('p0_event3_title', '— ${events[2].title} —',
          '— ${events[2].titleGu} —');
      _updateElement(
          'p0_event3_date',
          '${lang.dateLabelFor('English')} ${events[2].date}',
          '${lang.taLabelFor(invLang)} ${events[2].dateGu.isNotEmpty ? events[2].dateGu : events[2].date}');
      _updateElement(
          'p0_event3_time',
          '${lang.timeLabelFor('English')} ${events[2].time}',
          '${lang.samayLabelFor(invLang)} ${events[2].timeGu.isNotEmpty ? events[2].timeGu : events[2].time}');
    }

    // Bride & Groom / Couple Prefixes
    String bridePrefixEn = lang.chiLabelFor('English');
    String bridePrefixGu = lang.chiLabelFor(invLang);
    String groomPrefixEn = lang.chiLabelFor('English');
    String groomPrefixGu = lang.chiLabelFor(invLang);

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

    _updateElement('p1_bride', '$bridePrefixEn$brideNameEn', '$bridePrefixGu$brideNameGu');
    _updateElement('p2_bride', '$bridePrefixEn$brideNameEn', '$bridePrefixGu$brideNameGu');
    _updateElement('p3_bride', '$bridePrefixEn$brideNameEn', '$bridePrefixGu$brideNameGu');
    _updateElement('p4_bride', '$bridePrefixEn$brideNameEn', '$bridePrefixGu$brideNameGu');

    _updateElement('p1_groom', '$groomPrefixEn$groomNameEn', '$groomPrefixGu$groomNameGu');
    _updateElement('p2_groom', '$groomPrefixEn$groomNameEn', '$groomPrefixGu$groomNameGu');
    _updateElement('p3_groom', '$groomPrefixEn$groomNameEn', '$groomPrefixGu$groomNameGu');
    _updateElement('p4_groom', '$groomPrefixEn$groomNameEn', '$groomPrefixGu$groomNameGu');

    // Dates (CRITICAL GUARD: Only update Cover Page short date; do NOT overwrite separate Sangeet & Lagnotsav dates!)
    if (weddingDate.isNotEmpty) {
      _updateElement('p1_date', '${lang.dateLabelFor('English')} $weddingDate',
          '${lang.taLabelFor(invLang)} $weddingDate');
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
    _updateElement('p1_nimantrak_name', nimEn, nimGu);

    // Page 3
    _updateElement('p3_invite_text1', invitationTextEn, invitationTextGu);
    _updateElement('p3_parents', parentsNameFullEn, parentsNameFullGu);

    // Page 5
    _updateElement('p5_family_title', familyNameEn, familyNameGu);
    _updateElement('p5_nimantrak_names', nimantrakListEn, nimantrakListGu);
    _updateElement('p5_no_gifts', noGiftsTextEn, noGiftsTextGu);

    // Page 6 Lists
    _updateElement('p6_list1a', snehdhinEn, snehdhinGu);
    _updateElement('p6_list2a', darshanabhilashiEn, darshanabhilashiGu);
    _updateElement('p6_list3', mameruMosalEn, mameruMosalGu);
    _updateElement('p6_list4', masiFoiLadlaEn, masiFoiLadlaGu);
    _updateElement('p6_tahuko_text', tahukoEn, tahukoGu);

    notifyListeners();
  }

  void _updateElement(String id, String english, String gujarati) {
    try {
      final matches = elements.where((e) => e.id == id || e.id.startsWith('${id}_'));
      for (final el in matches) {
        if (english.isNotEmpty) el.content = english;
        if (gujarati.isNotEmpty) el.contentGujarati = gujarati;
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
