import 'package:hive/hive.dart';

part 'guest_model.g.dart';

/// =======================================================
/// 🧍 Guest Model (Stored in Hive)
/// =======================================================
@HiveType(typeId: 1)
class GuestModel extends HiveObject {
  /// 🔑 Unique ID (UUID recommended)
  @HiveField(0)
  String id;

  /// 👤 Guest Name
  @HiveField(1)
  String name;

  /// 📞 Phone Number (normalized)
  @HiveField(2)
  String phone;

  /// 👪 Family Side
  @HiveField(3)
  FamilySide familySide;

  /// 📩 RSVP Status
  @HiveField(4)
  RsvpStatus rsvpStatus;

  /// 🕒 Added Time
  @HiveField(5)
  DateTime addedAt;

  /// 📝 Optional Notes
  @HiveField(6)
  String? notes;

  // ------------------------------------------------------
  // 🏗️ CONSTRUCTOR
  // ------------------------------------------------------
  GuestModel({
    required this.id,
    required this.name,
    required String phone,
    this.familySide = FamilySide.unassigned,
    this.rsvpStatus = RsvpStatus.pending,
    DateTime? addedAt,
    this.notes,
  })  : phone = _normalizePhone(phone),
        addedAt = addedAt ?? DateTime.now();

  // ------------------------------------------------------
  // 🔧 HELPERS
  // ------------------------------------------------------

  /// Normalize phone number
  static String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  /// Copy (used in edit)
  GuestModel copyWith({
    String? id,
    String? name,
    String? phone,
    FamilySide? familySide,
    RsvpStatus? rsvpStatus,
    DateTime? addedAt,
    String? notes,
  }) {
    return GuestModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      familySide: familySide ?? this.familySide,
      rsvpStatus: rsvpStatus ?? this.rsvpStatus,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }

  // ------------------------------------------------------
  // 📤 JSON (for CSV / API / Debug)
  // ------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "phone": phone,
      "familySide": familySide.name,
      "rsvpStatus": rsvpStatus.name,
      "addedAt": addedAt.toIso8601String(),
      "notes": notes,
    };
  }

  factory GuestModel.fromJson(Map<String, dynamic> json) {
    return GuestModel(
      id: json["id"] ?? "",
      name: json["name"] ?? "",
      phone: json["phone"] ?? "",
      familySide: _parseFamily(json["familySide"]),
      rsvpStatus: _parseRsvp(json["rsvpStatus"]),
      addedAt: DateTime.tryParse(json["addedAt"] ?? "") ?? DateTime.now(),
      notes: json["notes"],
    );
  }

  static FamilySide _parseFamily(String? value) {
    switch (value) {
      case "bride":
        return FamilySide.bride;
      case "groom":
        return FamilySide.groom;
      case "common":
        return FamilySide.common;
      default:
        return FamilySide.unassigned;
    }
  }

  static RsvpStatus _parseRsvp(String? value) {
    switch (value) {
      case "confirmed":
        return RsvpStatus.confirmed;
      case "declined":
        return RsvpStatus.declined;
      default:
        return RsvpStatus.pending;
    }
  }

  // ------------------------------------------------------
  // 🖥️ UI HELPERS
  // ------------------------------------------------------

  String get familyLabel {
    switch (familySide) {
      case FamilySide.bride:
        return "Bride Side";
      case FamilySide.groom:
        return "Groom Side";
      case FamilySide.common:
        return "Common";
      case FamilySide.unassigned:
        return "Unassigned";
    }
  }

  String get rsvpLabel {
    switch (rsvpStatus) {
      case RsvpStatus.pending:
        return "Pending";
      case RsvpStatus.confirmed:
        return "Confirmed";
      case RsvpStatus.declined:
        return "Declined";
    }
  }
}

/// =======================================================
/// 👪 Family Side Enum
/// =======================================================
@HiveType(typeId: 2)
enum FamilySide {
  @HiveField(0)
  bride,

  @HiveField(1)
  groom,

  @HiveField(2)
  common,

  @HiveField(3)
  unassigned,
}

/// =======================================================
/// 📩 RSVP Status Enum
/// =======================================================
@HiveType(typeId: 3)
enum RsvpStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  confirmed,

  @HiveField(2)
  declined,
}
