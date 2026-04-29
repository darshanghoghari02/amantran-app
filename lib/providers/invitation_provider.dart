import 'package:flutter/material.dart';
import 'dart:async';
import '../models/kankotri_data.dart';
import '../models/template_element.dart';

enum LogoType { preset, customSvg }

class LogoModel {
  LogoType type;
  String? presetAsset;
  String? customSvgPath;
  String? rawSvgContent;

  LogoModel({
    this.type = LogoType.preset,
    this.presetAsset,
    this.customSvgPath,
    this.rawSvgContent,
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
    _syncToElements();
    notifyListeners();
  }

  // --- Global State ---
  List<TemplateElement> elements = [];
  bool isGujarati = true;
  Timer? _debounce;

  void initElements(List<TemplateElement> initialElements) {
    if (elements.isEmpty) {
      elements = initialElements.map((e) => e.copyWith()).toList();
      _syncToElements();
    }
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

  // --- Update Method ---
  void updateField(VoidCallback updateAction) {
    updateAction();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _syncToElements();
      notifyListeners();
    });
  }

  void updateEvent(int index, EventModel event) {
    if (index < events.length) {
      events[index] = event;
    } else {
      events.add(event);
    }
    _syncToElements();
    notifyListeners();
  }

  // --- Sync to Canvas Elements ---
  void _syncToElements() {
    // Sync logo
    if (logo.type == LogoType.preset && logo.presetAsset != null) {
      _updateAsset('ganesh_image', logo.presetAsset!);
    }

    // Page 0 (Events)
    if (events.isNotEmpty) {
      _updateElement('p0_event1_title', ':: ${events[0].title} ::', ':: ${events[0].titleGu} ::');
      _updateElement('p0_event1_date', 'Date: ${events[0].date}', 'તા. ${events[0].dateGu.isNotEmpty ? events[0].dateGu : events[0].date}');
      _updateElement('p0_event1_time', 'Time: ${events[0].time}', 'સમય: ${events[0].timeGu.isNotEmpty ? events[0].timeGu : events[0].time}');
      
      _updateElement('p4_event1_title', ':: ${events[0].title} ::', ':: ${events[0].titleGu} ::');
      _updateElement('p4_event1_datetime', '${events[0].date}\\n${events[0].time}', 'તા. ${events[0].dateGu.isNotEmpty ? events[0].dateGu : events[0].date}\\n${events[0].timeGu.isNotEmpty ? events[0].timeGu : events[0].time}');

      if (events[0].place.isNotEmpty) {
        _updateElement('p0_sthal_address', events[0].place, events[0].placeGu);
        _updateElement('p2_sthal_address', events[0].place, events[0].placeGu);
        _updateElement('p4_sthal_address', events[0].place, events[0].placeGu);
      }
    }

    if (events.length > 1) {
      _updateElement('p0_event2_title', ':: ${events[1].title} ::', ':: ${events[1].titleGu} ::');
      _updateElement('p0_event2_date', 'Date: ${events[1].date}', 'તા. ${events[1].dateGu.isNotEmpty ? events[1].dateGu : events[1].date}');
      _updateElement('p0_event2_time', 'Time: ${events[1].time}', 'સમય: ${events[1].timeGu.isNotEmpty ? events[1].timeGu : events[1].time}');

      _updateElement('p4_event2_title', ':: ${events[1].title} ::', ':: ${events[1].titleGu} ::');
      _updateElement('p4_event2_datetime', '${events[1].date}\\n${events[1].time}', 'તા. ${events[1].dateGu.isNotEmpty ? events[1].dateGu : events[1].date}\\n${events[1].timeGu.isNotEmpty ? events[1].timeGu : events[1].time}');
    }

    if (events.length > 2) {
      _updateElement('p0_event3_title', ':: ${events[2].title} ::', ':: ${events[2].titleGu} ::');
      _updateElement('p0_event3_date', 'Date: ${events[2].date}', 'તા. ${events[2].dateGu.isNotEmpty ? events[2].dateGu : events[2].date}');
      _updateElement('p0_event3_time', 'Time: ${events[2].time}', 'સમય: ${events[2].timeGu.isNotEmpty ? events[2].timeGu : events[2].time}');
    }

    // Bride & Groom
    _updateElement('p1_bride', 'Chi. $brideNameEn', 'ચિ. $brideNameGu');
    _updateElement('p2_bride', 'Chi. $brideNameEn', 'ચિ. $brideNameGu');
    _updateElement('p3_bride', 'Chi. $brideNameEn', 'ચિ. $brideNameGu');
    _updateElement('p4_bride', 'Chi. $brideNameEn', 'ચિ. $brideNameGu');

    _updateElement('p1_groom', 'Chi. $groomNameEn', 'ચિ. $groomNameGu');
    _updateElement('p2_groom', 'Chi. $groomNameEn', 'ચિ. $groomNameGu');
    _updateElement('p3_groom', 'Chi. $groomNameEn', 'ચિ. $groomNameGu');
    _updateElement('p4_groom', 'Chi. $groomNameEn', 'ચિ. $groomNameGu');

    // Dates
    _updateElement('p1_date', 'Date: $weddingDate', 'તા. $weddingDate');
    _updateElement('p2_date_time', weddingDate, weddingDate);
    _updateElement('p3_date_long', weddingDate, weddingDate);

    // Nimantrak (Page 1)
    String nimEn = [fatherNameEn, motherNameEn, addressEn].where((e) => e.isNotEmpty).join('\\n');
    String nimGu = [fatherNameGu, motherNameGu, addressGu].where((e) => e.isNotEmpty).join('\\n');
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
  }

  void _updateElement(String id, String english, String gujarati) {
    try {
      final el = elements.firstWhere((e) => e.id == id);
      if (english.isNotEmpty) el.content = english;
      if (gujarati.isNotEmpty) el.contentGujarati = gujarati;
    } catch (_) {}
  }

  void _updateAsset(String id, String path) {
    try {
      final el = elements.firstWhere((e) => e.id == id);
      el.assetPath = path;
    } catch (_) {}
  }

  // --- Inline Edit Sync Back to Provider ---
  void syncElementBackToProvider(TemplateElement element) {
    // Reverse map from element ID to provider field
    // Just an example; full mapping can be complex
    if (element.id == 'p1_bride') {
      brideNameGu = element.contentGujarati.replaceAll('ચિ. ', '');
      brideNameEn = element.content.replaceAll('Chi. ', '');
    } else if (element.id == 'p1_groom') {
      groomNameGu = element.contentGujarati.replaceAll('ચિ. ', '');
      groomNameEn = element.content.replaceAll('Chi. ', '');
    }
    notifyListeners();
  }

  KankotriData get data {
    return KankotriData(
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
