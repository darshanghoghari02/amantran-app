import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/guest_model.dart';

class VcfService {
  static final _uuid = const Uuid();

  // ------------------------------------------------------------
  // 📥 IMPORT FROM VCF FILE
  // ------------------------------------------------------------
  static Future<VcfImportResult> importFromVcfFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception("VCF file not found");
    }

    final content = await file.readAsString(encoding: utf8);

    final entries = content.split(RegExp(r'END:VCARD', caseSensitive: false));

    final List<GuestModel> guests = [];
    final List<String> invalidEntries = [];

    for (var raw in entries) {
      final entry = raw.trim();

      if (entry.isEmpty) continue;

      try {
        final name = _extractName(entry);
        final phone = _extractPhone(entry);

        if (name.isEmpty || phone.isEmpty) {
          invalidEntries.add(entry);
          continue;
        }

        guests.add(
          GuestModel(
            id: _uuid.v4(),
            name: name,
            phone: phone,
            familySide: FamilySide.unassigned,
            rsvpStatus: RsvpStatus.pending,
          ),
        );
      } catch (e) {
        invalidEntries.add(entry);
      }
    }

    return VcfImportResult(
      guests: guests,
      invalidEntries: invalidEntries,
    );
  }

  // ------------------------------------------------------------
  // 📤 EXPORT TO VCF FILE
  // ------------------------------------------------------------
  static Future<File> exportToVcf(List<GuestModel> guests) async {
    final buffer = StringBuffer();

    for (var g in guests) {
      buffer.writeln("BEGIN:VCARD");
      buffer.writeln("VERSION:3.0");
      buffer.writeln("FN:${_escape(g.name)}");
      buffer.writeln("TEL;TYPE=CELL:${_formatPhone(g.phone)}");
      buffer.writeln("END:VCARD");
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/guests_export.vcf");

    await file.writeAsString(buffer.toString(), encoding: utf8);

    return file;
  }

  // ------------------------------------------------------------
  // 🔍 EXTRACT NAME
  // ------------------------------------------------------------
  static String _extractName(String vcard) {
    // Try FN first
    final fnMatch = RegExp(r'FN:(.+)', caseSensitive: false).firstMatch(vcard);

    if (fnMatch != null) {
      return fnMatch.group(1)?.trim() ?? "";
    }

    // Fallback to N:
    final nMatch = RegExp(r'N:(.+)', caseSensitive: false).firstMatch(vcard);

    if (nMatch != null) {
      final parts = nMatch.group(1)?.split(';') ?? [];
      return parts.where((e) => e.trim().isNotEmpty).join(' ');
    }

    return "";
  }

  // ------------------------------------------------------------
  // 📞 EXTRACT PHONE
  // ------------------------------------------------------------
  static String _extractPhone(String vcard) {
    final match =
        RegExp(r'TEL[^:]*:(.+)', caseSensitive: false).firstMatch(vcard);

    if (match == null) return "";

    return _normalizePhone(match.group(1) ?? "");
  }

  // ------------------------------------------------------------
  // 🔧 HELPERS
  // ------------------------------------------------------------

  static String _normalizePhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');

    // Handle Indian format
    if (cleaned.startsWith('+91')) {
      return cleaned.substring(3);
    }

    return cleaned;
  }

  static String _formatPhone(String phone) {
    if (phone.startsWith('+')) return phone;
    return "+91$phone"; // default India format
  }

  static String _escape(String input) {
    return input.replaceAll(',', r'\,').replaceAll(';', r'\;');
  }
}

// ------------------------------------------------------------
// 📦 IMPORT RESULT MODEL
// ------------------------------------------------------------
class VcfImportResult {
  final List<GuestModel> guests;
  final List<String> invalidEntries;

  VcfImportResult({
    required this.guests,
    required this.invalidEntries,
  });
}
