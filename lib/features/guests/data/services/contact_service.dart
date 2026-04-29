import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/guest_model.dart';

class ContactService {
  static final _uuid = const Uuid();

  // ------------------------------------------------------------
  // 🔐 REQUEST PERMISSION (SAFE FOR WEB)
  // ------------------------------------------------------------
  static Future<bool> requestPermission() async {
    if (kIsWeb) {
      // ❌ Web does NOT support contacts
      return false;
    }

    try {
      final status = await Permission.contacts.status;

      if (status.isGranted) return true;

      final result = await Permission.contacts.request();

      if (result.isGranted) return true;

      if (result.isPermanentlyDenied) {
        await openAppSettings();
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ------------------------------------------------------------
  // 📱 LOAD CONTACTS
  // ------------------------------------------------------------
  static Future<List<Contact>> getAllContacts() async {
    if (kIsWeb) {
      throw Exception("Contacts not supported on Web");
    }

    final hasPermission = await requestPermission();

    if (!hasPermission) {
      throw Exception("Contacts permission denied");
    }

    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      return contacts;
    } catch (e) {
      throw Exception("Failed to load contacts");
    }
  }

  // ------------------------------------------------------------
  // 🔄 MAP CONTACT → GUEST
  // ------------------------------------------------------------
  static GuestModel? mapToGuest(Contact contact) {
    try {
      if (contact.phones.isEmpty) return null;

      final rawPhone = contact.phones.first.number;
      final phone = _normalizePhone(rawPhone);

      if (phone.isEmpty || phone.length < 10) return null;

      return GuestModel(
        id: _uuid.v4(),
        name: contact.displayName.isNotEmpty ? contact.displayName : "Unknown",
        phone: phone,
        familySide: FamilySide.unassigned,
        rsvpStatus: RsvpStatus.pending,
        addedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------
  // 📥 IMPORT FROM PHONE (SAFE + FILTERED)
  // ------------------------------------------------------------
  static Future<List<GuestModel>> importFromPhone() async {
    if (kIsWeb) {
      throw Exception("Phone import not supported on Web");
    }

    final contacts = await getAllContacts();

    final List<GuestModel> guests = [];
    final Set<String> seenPhones = {};

    for (var contact in contacts) {
      final guest = mapToGuest(contact);

      if (guest != null) {
        // ❌ REMOVE DUPLICATES
        if (!seenPhones.contains(guest.phone)) {
          seenPhones.add(guest.phone);
          guests.add(guest);
        }
      }
    }

    return guests;
  }

  // ------------------------------------------------------------
  // 🔧 NORMALIZE PHONE
  // ------------------------------------------------------------
  static String _normalizePhone(String input) {
    // Remove all non-numeric except +
    String cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');

    // Remove +91 (India)
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    }

    // Remove leading 0
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    return cleaned;
  }
}
