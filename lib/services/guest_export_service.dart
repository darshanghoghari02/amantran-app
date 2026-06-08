import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/guest_model.dart';

class GuestExportService {
  // ------------------------------------------------------------
  // 📤 EXPORT AS CSV
  // ------------------------------------------------------------
  static Future<File> exportToCsv(List<GuestModel> guests) async {
    List<List<dynamic>> rows = [];

    // Header
    rows.add(["Name", "Phone", "Status"]);

    // Data
    for (var g in guests) {
      rows.add([g.name, g.phone, g.statusLabel]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/guests_export.csv");

    await file.writeAsString(csvData, encoding: utf8);
    return file;
  }

  // ------------------------------------------------------------
  // 📤 EXPORT AS VCF
  // ------------------------------------------------------------
  static Future<File> exportToVcf(List<GuestModel> guests) async {
    final buffer = StringBuffer();

    for (var g in guests) {
      buffer.writeln("BEGIN:VCARD");
      buffer.writeln("VERSION:3.0");
      buffer.writeln("FN:${g.name}");
      buffer.writeln("TEL;TYPE=CELL:${g.phone}");
      buffer.writeln("END:VCARD");
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/guests_export.vcf");

    await file.writeAsString(buffer.toString(), encoding: utf8);
    return file;
  }

  // ------------------------------------------------------------
  // 📤 EXPORT AS PDF
  // ------------------------------------------------------------
  static Future<File> exportToPdf(List<GuestModel> guests) async {
    final pdf = pw.Document();

    pw.Font? customFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/NotoSerifGujarati.ttf");
      customFont = pw.Font.ttf(fontData);
    } catch (_) {}

    final textStyle = pw.TextStyle(font: customFont, fontSize: 10);
    final headerStyle = pw.TextStyle(font: customFont, fontSize: 12, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "Guest List",
              style: pw.TextStyle(font: customFont, fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headerStyle: headerStyle,
            cellStyle: textStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ["No", "Name", "Phone", "Status"],
            data: List.generate(guests.length, (index) {
              final g = guests[index];
              return ["${index + 1}", g.name, g.phone, g.statusLabel];
            }),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/guests_list.pdf");
    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
