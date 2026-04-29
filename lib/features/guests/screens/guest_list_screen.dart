import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/guest_model.dart';
import '../data/repositories/guest_repository.dart';
import '../data/services/contact_service.dart';

import 'file_import_screen.dart';
import 'export_sheet.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key});

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  final repo = GuestRepository();

  List<GuestModel> guests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ------------------------------------------------------------
  // 🔄 LOAD
  // ------------------------------------------------------------
  void _load() async {
    final data = await repo.getAll();
    setState(() {
      guests = data;
      isLoading = false;
    });
  }

  // ------------------------------------------------------------
  // 📩 WHATSAPP
  // ------------------------------------------------------------
  Future<void> _sendWhatsApp(String phone, String name) async {
    final msg = "Hello $name,\nYou are invited 🎉";

    final Uri url =
        Uri.parse("https://wa.me/91$phone?text=${Uri.encodeComponent(msg)}");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ------------------------------------------------------------
  // 📱 IMPORT FROM PHONE
  // ------------------------------------------------------------
  Future<void> _importFromPhone() async {
    final list = await ContactService.importFromPhone();

    await repo.addAll(list);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Imported ${list.length} contacts")),
    );

    _load();
  }

  // ------------------------------------------------------------
  // 📂 IMPORT FILE (CSV/VCF)
  // ------------------------------------------------------------
  void _importFile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FileImportScreen()),
    ).then((_) => _load());
  }

  // ------------------------------------------------------------
  // ➕ ADD / EDIT FORM
  // ------------------------------------------------------------
  void _openForm({GuestModel? guest}) {
    final name = TextEditingController(text: guest?.name ?? "");
    final phone = TextEditingController(text: guest?.phone ?? "");

    RsvpStatus rsvp = guest?.rsvpStatus ?? RsvpStatus.pending;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      guest == null ? "Add Guest" : "Edit Guest",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: "Name"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Phone"),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<RsvpStatus>(
                      initialValue: rsvp,
                      items: RsvpStatus.values.map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(e.name),
                        );
                      }).toList(),
                      onChanged: (v) => setStateSheet(() => rsvp = v!),
                      decoration: const InputDecoration(labelText: "RSVP"),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (name.text.isEmpty || phone.text.isEmpty) return;

                        final newGuest = GuestModel(
                          id: guest?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          name: name.text,
                          phone: phone.text,
                          rsvpStatus: rsvp,
                        );

                        guest == null
                            ? await repo.add(newGuest)
                            : await repo.update(newGuest);

                        Navigator.pop(context);
                        _load();
                      },
                      child: const Text("Save"),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // 🎨 RSVP COLOR
  // ------------------------------------------------------------
  Color _rsvpColor(RsvpStatus status) {
    switch (status) {
      case RsvpStatus.confirmed:
        return Colors.green;
      case RsvpStatus.declined:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ------------------------------------------------------------
  // FAB MENU (🔥 IMPORTANT FIX)
  // ------------------------------------------------------------
  Widget _fabMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.add),
      onSelected: (v) {
        if (v == "manual") _openForm();
        if (v == "phone") _importFromPhone();
        if (v == "file") _importFile();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: "manual", child: Text("Add Manually")),
        PopupMenuItem(value: "phone", child: Text("Import Phone")),
        PopupMenuItem(value: "file", child: Text("Import CSV/VCF")),
      ],
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Guests (${guests.length})"),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (_) => ExportSheet(guests: guests),
              );
            },
          ),
        ],
      ),
      floatingActionButton: _fabMenu(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : guests.isEmpty
              ? const Center(
                  child: Text(
                    "No Guests Yet\nTap + to Add or Import",
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: guests.length,
                  itemBuilder: (_, i) {
                    final g = guests[i];

                    return Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: Text(g.name[0].toUpperCase()),
                        ),
                        title: Text(g.name),
                        subtitle: Text(g.phone),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _rsvpColor(g.rsvpStatus),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                g.rsvpStatus.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.message,
                                  color: Colors.green),
                              onPressed: () => _sendWhatsApp(g.phone, g.name),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openForm(guest: g),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
