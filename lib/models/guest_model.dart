/// RSVP status for a guest invitation
enum RsvpStatus { pending, sent, viewed }

/// Represents a single guest entry
class GuestModel {
  String id;
  String name;
  String phone;
  String note;
  RsvpStatus rsvpStatus;

  GuestModel({
    required this.id,
    required this.name,
    required this.phone,
    this.note = '',
    this.rsvpStatus = RsvpStatus.pending,
  });

  String get statusLabel {
    switch (rsvpStatus) {
      case RsvpStatus.pending:
        return 'Pending';
      case RsvpStatus.sent:
        return 'Sent';
      case RsvpStatus.viewed:
        return 'Viewed';
    }
  }

  /// First letter for the avatar circle
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  GuestModel copyWith({
    String? name,
    String? phone,
    String? note,
    RsvpStatus? rsvpStatus,
  }) {
    return GuestModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      rsvpStatus: rsvpStatus ?? this.rsvpStatus,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'note': note,
    'rsvpStatus': rsvpStatus.name,
  };

  factory GuestModel.fromJson(Map<String, dynamic> json) => GuestModel(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    note: json['note']?.toString() ?? '',
    rsvpStatus: RsvpStatus.values.firstWhere(
      (e) => e.name == json['rsvpStatus'],
      orElse: () => RsvpStatus.pending,
    ),
  );
}
