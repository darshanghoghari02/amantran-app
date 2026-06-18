import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../data/models/guest_model.dart';
import '../data/repositories/guest_repository.dart';
import '../data/services/contact_service.dart';
import '../../../widgets/top_notification.dart';

class PhoneContactPickerScreen extends StatefulWidget {
  const PhoneContactPickerScreen({super.key});

  @override
  State<PhoneContactPickerScreen> createState() =>
      _PhoneContactPickerScreenState();
}

class _PhoneContactPickerScreenState extends State<PhoneContactPickerScreen> {
  final repo = GuestRepository();

  List<Contact> allContacts = [];
  List<Contact> filteredContacts = [];

  final Set<String> selectedIds = {};

  bool isLoading = true;
  bool selectAll = false;

  String searchQuery = "";

  // ------------------------------------------------------------
  // 🔄 LOAD CONTACTS
  // ------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    try {
      setState(() => isLoading = true);

      final contacts = await ContactService.getAllContacts();

      setState(() {
        allContacts = contacts;
        filteredContacts = contacts;
      });
    } catch (e) {
      _show("Permission denied or error");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ------------------------------------------------------------
  // 🔍 SEARCH
  // ------------------------------------------------------------
  void applySearch(String value) {
    setState(() {
      searchQuery = value;

      filteredContacts = allContacts.where((c) {
        return c.displayName.toLowerCase().contains(value.toLowerCase());
      }).toList();
    });
  }

  // ------------------------------------------------------------
  // ☑️ SELECT ALL
  // ------------------------------------------------------------
  void toggleSelectAll() {
    setState(() {
      selectAll = !selectAll;

      if (selectAll) {
        selectedIds.clear();
        for (var c in filteredContacts) {
          selectedIds.add(c.id);
        }
      } else {
        selectedIds.clear();
      }
    });
  }

  // ------------------------------------------------------------
  // 📥 IMPORT SELECTED
  // ------------------------------------------------------------
  Future<void> importSelected() async {
    if (selectedIds.isEmpty) {
      _show("No contacts selected");
      return;
    }

    final List<GuestModel> guests = [];

    for (var contact in allContacts) {
      if (selectedIds.contains(contact.id)) {
        final guest = ContactService.mapToGuest(contact);
        if (guest != null) guests.add(guest);
      }
    }

    final duplicates = await repo.addAll(guests);

    _show(
      "Imported: ${guests.length - duplicates.length}, "
      "Duplicates: ${duplicates.length}",
    );

    Navigator.pop(context, true);
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
      appBar: AppBar(
        title: Text("Select Contacts (${selectedIds.length})"),
        actions: [
          IconButton(
            icon: Icon(
              selectAll ? Icons.select_all : Icons.done_all,
            ),
            onPressed: toggleSelectAll,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // 🔍 SEARCH
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: "Search contacts",
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: applySearch,
              ),
            ),

            // 🔄 LOADING
            if (isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredContacts.isEmpty)
              const Expanded(
                child: Center(child: Text("No contacts found")),
              )
            else
              // 📱 CONTACT LIST
              Expanded(
                child: ListView.builder(
                  itemCount: filteredContacts.length,
                  itemBuilder: (context, index) {
                    final c = filteredContacts[index];

                    final selected = selectedIds.contains(c.id);

                    final phone =
                        c.phones.isNotEmpty ? c.phones.first.number : "No number";

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          c.displayName.isNotEmpty ? c.displayName[0] : "?",
                        ),
                      ),
                      title: Text(c.displayName),
                      subtitle: Text(phone),
                      trailing: Checkbox(
                        value: selected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedIds.add(c.id);
                            } else {
                              selectedIds.remove(c.id);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            selectedIds.remove(c.id);
                          } else {
                            selectedIds.add(c.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

            // 🔴 IMPORT BUTTON
            Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: importSelected,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.red,
                ),
                child: const Text("Import Selected"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
