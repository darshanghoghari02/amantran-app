import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/models/guest_model.dart';
import '../data/repositories/guest_repository.dart';
import '../data/services/csv_service.dart';
import '../data/services/vcf_service.dart';
import '../../../widgets/top_notification.dart';

class FileImportScreen extends StatefulWidget {
  const FileImportScreen({super.key});

  @override
  State<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends State<FileImportScreen> {
  final GuestRepository repo = GuestRepository();

  bool isLoading = false;

  List<GuestModel> previewGuests = [];
  List<dynamic> invalidData = [];

  String fileName = "";

  // ------------------------------------------------------------
  // 📂 PICK FILE
  // ------------------------------------------------------------
  Future<void> pickFile() async {
    try {
      setState(() => isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'vcf'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      fileName = result.files.single.name;

      if (file.path.endsWith(".csv")) {
        final res = await CsvService.importFromCsvFile(file.path);

        previewGuests = res.guests;
        invalidData = res.invalidRows;
      } else if (file.path.endsWith(".vcf")) {
        final res = await VcfService.importFromVcfFile(file.path);

        previewGuests = res.guests;
        invalidData = res.invalidEntries;
      }

      setState(() {});
    } catch (e) {
      _show("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ------------------------------------------------------------
  // 📥 IMPORT TO DB
  // ------------------------------------------------------------
  Future<void> importData() async {
    if (previewGuests.isEmpty) {
      _show("No valid data to import");
      return;
    }

    setState(() => isLoading = true);

    final duplicates = await repo.addAll(previewGuests);

    setState(() => isLoading = false);

    _show(
      "Imported: ${previewGuests.length - duplicates.length}, "
      "Duplicates: ${duplicates.length}",
    );

    Navigator.pop(context);
  }

  void _show(String msg) {
    TopNotification.show(context, message: msg);
  }

  // ------------------------------------------------------------
  // 🧩 UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import Guests")),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 🔘 PICK FILE BUTTON
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text("Select CSV / VCF File"),
            ),
          ),

          if (fileName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text("Selected: $fileName"),
            ),

          // 🔄 LOADING
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),

          // 🔥 PREVIEW LIST
          Expanded(
            child: previewGuests.isEmpty
                ? const Center(
                    child: Text("No data loaded"),
                  )
                : ListView.builder(
                    itemCount: previewGuests.length,
                    itemBuilder: (context, index) {
                      final g = previewGuests[index];

                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(g.name),
                        subtitle: Text(g.phone),
                      );
                    },
                  ),
          ),

          // ⚠️ INVALID DATA
          if (invalidData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                "Invalid entries: ${invalidData.length}",
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // 🔴 IMPORT BUTTON
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: isLoading ? null : importData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.red,
              ),
              child: const Text("Import Guests"),
            ),
          ),
        ],
      ),
    );
  }
}
