import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/guest_model.dart';

class PdfExportService {
  // ------------------------------------------------------------
  // 📤 EXPORT GUEST LIST AS PDF
  // ------------------------------------------------------------
  static Future<File> exportGuests(List<GuestModel> guests) async {
    final pdf = pw.Document();

    // 🔥 LOAD FONT (OPTIONAL GUJARATI SUPPORT)
    pw.Font? customFont;

    try {
      final fontData =
          await rootBundle.load("assets/fonts/NotoSansGujarati-Regular.ttf");
      customFont = pw.Font.ttf(fontData);
    } catch (_) {
      // fallback → default font
    }

    final textStyle = pw.TextStyle(
      font: customFont,
      fontSize: 10,
    );

    final headerStyle = pw.TextStyle(
      font: customFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          // 🔴 TITLE
          pw.Center(
            child: pw.Text(
              "Guest List",
              style: pw.TextStyle(
                font: customFont,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),

          pw.SizedBox(height: 15),

          // 🔥 TABLE
          pw.Table.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: textStyle,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey300,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.center,
            headers: [
              "No",
              "Name",
              "Phone",
              "Side",
              "RSVP",
            ],
            data: List.generate(guests.length, (index) {
              final g = guests[index];

              return [
                "${index + 1}",
                g.name,
                g.phone,
                g.familySide.name,
                g.rsvpStatus.name,
              ];
            }),
          ),
        ],
      ),
    );

    // ------------------------------------------------------------
    // 💾 SAVE FILE
    // ------------------------------------------------------------
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/guest_list.pdf");

    final Uint8List bytes = await pdf.save();
    await file.writeAsBytes(bytes);

    return file;
  }
}
