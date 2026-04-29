import 'template_element.dart';

class EventModel {
  String title;
  String titleGu;
  String date;
  String dateGu;
  String time;
  String timeGu;
  String place;
  String placeGu;

  EventModel({
    this.title = "",
    this.titleGu = "",
    this.date = "",
    this.dateGu = "",
    this.time = "",
    this.timeGu = "",
    this.place = "",
    this.placeGu = "",
  });
}

class KankotriData {
  // Page 1 — Ganesh & Family
  final String ganeshImage;
  final String familyName;
  final String familyNameGu;
  final String village;
  final String villageGu;
  final String taluka;
  final String talukaGu;
  final String district;
  final String districtGu;

  // Page 2 — Bride & Groom
  final String groomName;
  final String groomNameGu;
  final String brideName;
  final String brideNameGu;
  final String shlok1;
  final String shlok1Gu;
  final String nimantrakName;
  final String nimantrakNameGu;

  // Page 3 — Events
  final List<EventModel> events;
  final String sangeetQuote;
  final String sangeetQuoteGu;
  final String sangeetInvite;
  final String sangeetInviteGu;

  // Page 4 — Family Details (Groom Side) / Lagnotsav
  final String fatherName;
  final String fatherNameGu;
  final String motherName;
  final String motherNameGu;
  final String grandFatherName;
  final String grandFatherNameGu;
  final String grandMotherName;
  final String grandMotherNameGu;
  final String mamaName;
  final String mamaNameGu;
  final String kuldevi;
  final String kuldeviGu;
  final String nativePlace;
  final String nativePlaceGu;
  final String parentsNameFull;
  final String parentsNameFullGu;
  final String gujaratiDateFull;
  final String gujaratiDateFullGu;

  // Page 5 — Invitation Text & Quotes
  final String invitationText;
  final String invitationTextGu;
  final String lagnotsavFooter;
  final String lagnotsavFooterGu;
  final String parinayQuote;
  final String parinayQuoteGu;

  // Page 6 — Contact, Thanks & Nimantrak Lists
  final String contact;
  final String contact2;
  final String address;
  final String addressGu;
  final String thanksTitle;
  final String thanksTitleGu;
  final String thanksMessage;
  final String thanksMessageGu;
  final String nimantrakList;
  final String nimantrakListGu;
  final String noGiftsText;
  final String noGiftsTextGu;

  // Page 7 — Relative Lists (Snehdhin, Darshanabhilashi, etc)
  final String snehdhin;
  final String snehdhinGu;
  final String darshanabhilashi;
  final String darshanabhilashiGu;
  final String mameruMosal;
  final String mameruMosalGu;
  final String masiFoiLadla;
  final String masiFoiLadlaGu;
  final String tahuko;
  final String tahukoGu;
  final String weddingDate;
  final String weddingDateGu;

  final bool isGujarati;
  final List<TemplateElement>? customElements;

  KankotriData({
    required this.ganeshImage,
    required this.familyName,
    this.familyNameGu = "",
    required this.village,
    this.villageGu = "",
    this.taluka = "",
    this.talukaGu = "",
    this.district = "",
    this.districtGu = "",
    required this.groomName,
    this.groomNameGu = "",
    required this.brideName,
    this.brideNameGu = "",
    this.shlok1 = "",
    this.shlok1Gu = "",
    this.nimantrakName = "",
    this.nimantrakNameGu = "",
    required this.events,
    this.sangeetQuote = "",
    this.sangeetQuoteGu = "",
    this.sangeetInvite = "",
    this.sangeetInviteGu = "",
    required this.fatherName,
    this.fatherNameGu = "",
    required this.motherName,
    this.motherNameGu = "",
    required this.grandFatherName,
    this.grandFatherNameGu = "",
    required this.grandMotherName,
    this.grandMotherNameGu = "",
    this.mamaName = "",
    this.mamaNameGu = "",
    this.kuldevi = "",
    this.kuldeviGu = "",
    this.nativePlace = "",
    this.nativePlaceGu = "",
    this.parentsNameFull = "",
    this.parentsNameFullGu = "",
    this.gujaratiDateFull = "",
    this.gujaratiDateFullGu = "",
    required this.invitationText,
    this.invitationTextGu = "",
    this.lagnotsavFooter = "",
    this.lagnotsavFooterGu = "",
    this.parinayQuote = "",
    this.parinayQuoteGu = "",
    required this.contact,
    this.contact2 = "",
    required this.address,
    this.addressGu = "",
    this.thanksTitle = "",
    this.thanksTitleGu = "",
    this.thanksMessage = "",
    this.thanksMessageGu = "",
    this.nimantrakList = "",
    this.nimantrakListGu = "",
    this.noGiftsText = "",
    this.noGiftsTextGu = "",
    this.snehdhin = "",
    this.snehdhinGu = "",
    this.darshanabhilashi = "",
    this.darshanabhilashiGu = "",
    this.mameruMosal = "",
    this.mameruMosalGu = "",
    this.masiFoiLadla = "",
    this.masiFoiLadlaGu = "",
    this.tahuko = "",
    this.tahukoGu = "",
    this.weddingDate = "",
    this.weddingDateGu = "",
    this.isGujarati = true,
    this.customElements,
  });
}
