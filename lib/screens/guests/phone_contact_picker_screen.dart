import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/guest_model.dart';
import '../../providers/guest_provider.dart';
import '../../widgets/top_notification.dart';
import '../../providers/language_provider.dart';

class PhoneContactPickerScreen extends StatefulWidget {
  const PhoneContactPickerScreen({super.key});

  @override
  State<PhoneContactPickerScreen> createState() => _PhoneContactPickerScreenState();
}

class _PhoneContactPickerScreenState extends State<PhoneContactPickerScreen> {
  final _uuid = const Uuid();
  List<Contact> allContacts = [];
  List<Contact> filteredContacts = [];
  final Set<String> selectedIds = {};
  bool isLoading = true;
  bool selectAll = false;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() => isLoading = true);

      // Check / request permission
      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final contacts = await FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: false,
        );

        // Filter out contacts without phone numbers
        final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList();

        setState(() {
          allContacts = withPhones;
          filteredContacts = withPhones;
        });
      } else {
        if (mounted) {
          TopNotification.show(context, message: "Permission to access contacts was denied", type: NotificationType.error);
        }
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, message: "Error loading contacts: $e", type: NotificationType.error);
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applySearch(String value) {
    setState(() {
      searchQuery = value;
      filteredContacts = allContacts.where((c) {
        final nameMatch = c.displayName.toLowerCase().contains(value.toLowerCase());
        final phoneMatch = c.phones.any((p) => p.number.replaceAll(RegExp(r'[^0-9]'), '').contains(value));
        return nameMatch || phoneMatch;
      }).toList();
    });
  }

  void _toggleSelectAll() {
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

  void _importSelected() {
    if (selectedIds.isEmpty) {
      TopNotification.show(context, message: "No contacts selected", type: NotificationType.error);
      return;
    }

    final List<GuestModel> guestsToImport = [];
    for (var contact in allContacts) {
      if (selectedIds.contains(contact.id)) {
        final rawPhone = contact.phones.first.number;
        final phone = _normalizePhone(rawPhone);
        if (phone.length >= 10) {
          guestsToImport.add(GuestModel(
            id: _uuid.v4(),
            name: contact.displayName.isNotEmpty ? contact.displayName : "Unknown",
            phone: phone,
            note: '',
            rsvpStatus: RsvpStatus.pending,
          ));
        }
      }
    }

    if (guestsToImport.isEmpty) {
      TopNotification.show(context, message: "Selected contacts do not have valid 10-digit phone numbers", type: NotificationType.error);
      return;
    }

    final gp = context.read<GuestProvider>();
    gp.addGuests(guestsToImport);

    TopNotification.show(context, message: "Successfully imported ${guestsToImport.length} guests");
    Navigator.pop(context, true);
  }

  String _normalizePhone(String input) {
    String cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned.replaceAll(RegExp(r'[^0-9]'), '');
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F9),
      appBar: AppBar(
        title: Text("${lang.selectContacts} (${selectedIds.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(selectAll ? Icons.select_all : Icons.done_all, color: const Color(0xFFF94C66)),
            onPressed: _toggleSelectAll,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Search box
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: TextField(
                  onChanged: _applySearch,
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: lang.searchContacts,
                    hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFF94C66)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ),

            // Contact List
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFF94C66)))
                  : filteredContacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(lang.noContactsFound, style: const TextStyle(color: Colors.black38, fontSize: 15)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredContacts.length,
                          itemBuilder: (context, index) {
                            final c = filteredContacts[index];
                            final isSelected = selectedIds.contains(c.id);
                            final phone = c.phones.first.number;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.01),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFDE8EC),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : "?",
                                      style: const TextStyle(
                                        color: Color(0xFFF94C66),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                                ),
                                subtitle: Text(
                                  phone,
                                  style: const TextStyle(fontSize: 12, color: Colors.black38),
                                ),
                                trailing: Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFFF94C66),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                                    if (isSelected) {
                                      selectedIds.remove(c.id);
                                    } else {
                                      selectedIds.add(c.id);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
            ),

            // Import button
            if (!isLoading && filteredContacts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _importSelected,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0xFFF94C66).withOpacity(0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: Text(
                    "Import Selected (${selectedIds.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
