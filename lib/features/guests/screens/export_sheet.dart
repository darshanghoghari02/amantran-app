import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';

import '../data/models/guest_model.dart';
import '../data/services/csv_service.dart';
import '../data/services/vcf_service.dart';
import '../data/services/pdf_export_service.dart';
import '../../../widgets/top_notification.dart';

class ExportSheet extends StatefulWidget {
  final List<GuestModel> guests;

  const ExportSheet({super.key, required this.guests});

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  bool isLoading = false;

  // ------------------------------------------------------------
  // 🔁 LOADING WRAPPER
  // ------------------------------------------------------------
  Future<void> _run(Future<void> Function() task) async {
    try {
      setState(() => isLoading = true);
      await task();
    } catch (e) {
      _showMessage("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String msg) {
    TopNotification.show(context, message: msg);
  }

  // ------------------------------------------------------------
  // 📤 EXPORT CSV
  // ------------------------------------------------------------
  Future<void> _exportCsv() async {
    await _run(() async {
      final file = await CsvService.exportToCsv(widget.guests);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Guest List (CSV)",
      );
    });
  }

  // ------------------------------------------------------------
  // 📤 EXPORT VCF
  // ------------------------------------------------------------
  Future<void> _exportVcf() async {
    await _run(() async {
      final file = await VcfService.exportToVcf(widget.guests);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: "Guest Contacts (VCF)",
      );
    });
  }

  // ------------------------------------------------------------
  // 📤 EXPORT PDF
  // ------------------------------------------------------------
  Future<void> _exportPdf() async {
    await _run(() async {
      final file = await PdfExportService.exportGuests(widget.guests);

      await OpenFile.open(file.path);
    });
  }

  // ------------------------------------------------------------
  // 🧩 UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🔴 HEADER
            const Text(
              "Export Guest List",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // 🔘 OPTIONS
            _tile(
              icon: Icons.table_chart,
              title: "Export as CSV",
              subtitle: "Open in Excel / Google Sheets",
              onTap: _exportCsv,
            ),

            _tile(
              icon: Icons.contacts,
              title: "Export as VCF",
              subtitle: "Import into phone contacts",
              onTap: _exportVcf,
            ),

            _tile(
              icon: Icons.picture_as_pdf,
              title: "Export as PDF",
              subtitle: "Printable guest list",
              onTap: _exportPdf,
            ),

            const SizedBox(height: 10),

            // 🔴 LOADING
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // 🔹 TILE WIDGET
  // ------------------------------------------------------------
  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: Colors.red),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: isLoading ? null : onTap,
      ),
    );
  }
}
