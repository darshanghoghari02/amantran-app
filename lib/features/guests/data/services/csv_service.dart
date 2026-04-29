import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../models/guest_model.dart';

class CsvService {
  // ------------------------------------------------------------
  // 📥 IMPORT CSV FILE
  // ------------------------------------------------------------
  static Future<ImportResult> importFromCsvFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      throw Exception("File not found");
    }

    final csvString = await file.readAsString();

    final rows = const CsvToListConverter().convert(
      csvString,
      eol: '\n',
    );

    if (rows.isEmpty) {
      throw Exception("CSV file is empty");
    }

    final List<GuestModel> validGuests = [];
    final List<List<dynamic>> invalidRows = [];

    // Skip header (row 0)
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      try {
        if (row.length < 2) {
          invalidRows.add(row);
          continue;
        }

        final name = row[0]?.toString().trim() ?? "";
        final phone = _normalizePhone(row[1]?.toString() ?? "");

        if (name.isEmpty || !_isValidPhone(phone)) {
          invalidRows.add(row);
          continue;
        }

        final family = _parseFamily(row.length > 2 ? row[2] : null);
        final rsvp = _parseRsvp(row.length > 3 ? row[3] : null);

        validGuests.add(
          GuestModel(
            id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
            name: name,
            phone: phone,
            familySide: family,
            rsvpStatus: rsvp,
          ),
        );
      } catch (e) {
        invalidRows.add(row);
      }
    }

    return ImportResult(
      guests: validGuests,
      invalidRows: invalidRows,
    );
  }

  // ------------------------------------------------------------
  // 📤 EXPORT CSV FILE
  // ------------------------------------------------------------
  static Future<File> exportToCsv(List<GuestModel> guests) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add([
      "Name",
      "Phone",
      "Family Side",
      "RSVP Status",
    ]);

    // Data
    for (var g in guests) {
      rows.add([
        g.name,
        g.phone,
        g.familySide.name,
        g.rsvpStatus.name,
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/guests_export.csv");

    // UTF-8 encoding (important for Gujarati)
    await file.writeAsString(csvData, encoding: utf8);

    return file;
  }

  // ------------------------------------------------------------
  // 🔧 HELPERS
  // ------------------------------------------------------------

  static String _normalizePhone(String input) {
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool _isValidPhone(String phone) {
    return phone.length >= 10;
  }

  static FamilySide _parseFamily(dynamic value) {
    final v = value?.toString().toLowerCase();

    switch (v) {
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

  static RsvpStatus _parseRsvp(dynamic value) {
    final v = value?.toString().toLowerCase();

    switch (v) {
      case "confirmed":
        return RsvpStatus.confirmed;
      case "declined":
        return RsvpStatus.declined;
      default:
        return RsvpStatus.pending;
    }
  }
}

// ------------------------------------------------------------
// 📦 RESULT MODEL (FOR UI PREVIEW)
// ------------------------------------------------------------
class ImportResult {
  final List<GuestModel> guests;
  final List<List<dynamic>> invalidRows;

  ImportResult({
    required this.guests,
    required this.invalidRows,
  });
}
