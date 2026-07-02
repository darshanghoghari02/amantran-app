import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/guest_model.dart';
import '../../providers/guest_provider.dart';
import 'add_guest_form.dart';
import 'phone_contact_picker_screen.dart';
import '../../widgets/top_notification.dart';
import '../../providers/language_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../../services/guest_export_service.dart';
import '../../services/interaction_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});
  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  String _search = '';
  RsvpStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GuestProvider>();
    final lang = context.watch<LanguageProvider>();
    final all = gp.guests;
    List<GuestModel> filtered = _filter == null ? all : gp.filterByStatus(_filter!);
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((g) => g.name.toLowerCase().contains(q) || g.phone.contains(q)).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F9),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(lang.guestsCount(all.length), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showExportOptions(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.ios_share_rounded, size: 20, color: Color(0xFFF94C66)),
                    ),
                  ),
                ],
              ),
            ),

            // Empty state or list
            if (all.isEmpty)
              Expanded(child: _buildEmptyState(lang))
            else
              Expanded(child: _buildGuestList(filtered, gp, lang)),
          ],
        ),
      ),
      floatingActionButton: all.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFF94C66),
              onPressed: () => _showAddGuestSheet(lang),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 100, color: Colors.grey.shade200),
          const SizedBox(height: 24),
          Text(lang.noGuestsYet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(lang.addGuestsHint,
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.black45)),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showAddGuestSheet(lang),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF94C66), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), elevation: 4,
              shadowColor: const Color(0xFFF94C66).withValues(alpha: 0.4),
            ),
            child: Text(lang.addGuest, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestList(List<GuestModel> filtered, GuestProvider gp, LanguageProvider lang) {
    return Column(
      children: [
        // 🔥 SEARCH BAR - Premium Style
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                ),
              ],
            ),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: lang.searchGuests,
                hintStyle: const TextStyle(color: Colors.black26, fontSize: 14),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 15, right: 10),
                  child: Icon(Icons.search, color: Color(0xFFF94C66), size: 24),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 🔥 FILTER TABS - Premium Style
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip("${lang.all}(${gp.totalCount})", null),
              _filterChip("${lang.sent}(${gp.sentCount})", RsvpStatus.sent),
              _filterChip("${lang.pending}(${gp.pendingCount})", RsvpStatus.pending),
              _filterChip("${lang.viewed}(${gp.viewedCount})", RsvpStatus.viewed),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 🔥 GUEST LIST
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(lang.noGuestsMatch, style: const TextStyle(color: Colors.black38)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _buildGuestTile(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, RsvpStatus? status) {
    final isActive = _filter == status;
    return GestureDetector(
      onTap: () => setState(() => _filter = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF94C66) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFFF94C66) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: const Color(0xFFF94C66).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestTile(GuestModel guest) {
    Color badgeColor;
    Color badgeBg;
    switch (guest.rsvpStatus) {
      case RsvpStatus.pending:
        badgeColor = const Color(0xFFFF9800);
        badgeBg = const Color(0xFFFFF3E0);
        break;
      case RsvpStatus.sent:
        badgeColor = const Color(0xFF2196F3);
        badgeBg = const Color(0xFFE3F2FD);
        break;
      case RsvpStatus.viewed:
        badgeColor = const Color(0xFF4CAF50);
        badgeBg = const Color(0xFFE8F5E9);
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8EC),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                guest.initial,
                style: const TextStyle(
                  color: Color(0xFFF94C66),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  guest.phone,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              context.read<LanguageProvider>().rsvpStatusLabel(guest.rsvpStatus),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // WhatsApp icon — Official SVG Logo
          GestureDetector(
            onTap: () => _openWhatsApp(guest),
            child: SvgPicture.string(
              '''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><path fill="#25D366" d="M12.004 2c-5.523 0-10 4.477-10 10c0 1.767.459 3.427 1.263 4.873L2 22l5.247-1.377A9.947 9.947 0 0 0 12.004 22c5.523 0 10-4.477 10-10s-4.477-10-10-10zm.004 18.231c-1.63 0-3.167-.423-4.512-1.164l-.323-.178l-3.102.813l.827-3.023l-.196-.312c-.812-1.294-1.264-2.821-1.264-4.43c0-4.542 3.695-8.237 8.237-8.237s8.237 3.695 8.237 8.237s-3.696 8.237-8.237 8.237zm4.515-6.185c-.247-.124-1.464-.722-1.692-.804s-.392-.124-.556.124c-.165.247-.638.804-.784.969c-.144.165-.29.185-.536.062c-.247-.124-1.043-.385-1.986-1.227c-.733-.654-1.228-1.462-1.372-1.71c-.144-.247-.015-.381.109-.504c.112-.111.247-.289.37-.433c.124-.144.165-.247.247-.412c.082-.165.042-.31-.02-.433c-.062-.124-.556-1.341-.763-1.835c-.201-.486-.403-.42-.556-.427c-.144-.007-.31-.008-.474-.008c-.165 0-.433.062-.659.31c-.227.247-.866.845-.866 2.062c0 1.217.886 2.392 1.01 2.557c.124.165 1.743 2.661 4.221 3.732c.59.255 1.05.407 1.41.521c.594.188 1.135.161 1.562.097c.477-.071 1.464-.598 1.67-.1.206-.577.206-1.072.144-1.175c-.062-.103-.227-.165-.474-.289z"/></svg>''',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 8),

          // Edit icon — Dark/Black
          GestureDetector(
            onTap: () => _showEditDialog(guest),
            child: const Icon(
              Icons.edit_outlined,
              color: Colors.black87,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(GuestModel guest) async {
    final phone = guest.phone;
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.isEmpty) {
        if (mounted) {
          TopNotification.show(context, message: "Invalid phone number", type: NotificationType.error);
        }
        return;
      }
      // If exactly 10 digits (common Indian format), prepend 91
      final formattedPhone = cleanPhone.length == 10 ? '91$cleanPhone' : cleanPhone;
      final whatsappUrl = 'https://wa.me/$formattedPhone';
      final uri = Uri.parse(whatsappUrl);

      // Directly try to launch standard external application (WhatsApp) which is much more reliable
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: try launching without external application mode
        final fallbackLaunched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched && mounted) {
          TopNotification.show(context, message: "Could not open WhatsApp application", type: NotificationType.error);
          return;
        }
      }

      // Automatically update the guest's RSVP status to Sent if it was Pending
      if (guest.rsvpStatus == RsvpStatus.pending) {
        await context.read<GuestProvider>().updateGuest(guest.id, rsvpStatus: RsvpStatus.sent);
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, message: "Failed to open WhatsApp: $e", type: NotificationType.error);
      }
    }
  }

  void _showAddGuestSheet(LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(lang.addGuest, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 24),
            _addOption(Icons.person_add_outlined, lang.addManually, lang.enterGuestDetail, () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGuestForm()));
            }),
            const SizedBox(height: 12),
            _addOption(Icons.contacts_outlined, lang.importContacts, lang.importFromContacts, () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PhoneContactPickerScreen()),
              );
            }),
            const SizedBox(height: 12),
            _addOption(Icons.description_outlined, lang.importCsvVcf, lang.importFromFile, () {
              Navigator.pop(ctx);
              _importCsvVcfFile();
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _addOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFFCF9F9), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFDE8EC), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFFF94C66), size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _importContacts() async {
    // Simulated contact import
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFF94C66))),
    );
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context);

    final gp = context.read<GuestProvider>();
    final sampleContacts = [
      GuestModel(id: DateTime.now().millisecondsSinceEpoch.toString(), name: "F Tejash", phone: "9499512127"),
      GuestModel(id: '${DateTime.now().millisecondsSinceEpoch + 1}', name: "F Nikul", phone: "9499512127", rsvpStatus: RsvpStatus.sent),
      GuestModel(id: '${DateTime.now().millisecondsSinceEpoch + 2}', name: "F Guru", phone: "9499512127", rsvpStatus: RsvpStatus.viewed),
      GuestModel(id: '${DateTime.now().millisecondsSinceEpoch + 3}', name: "F Pathak", phone: "9499512127"),
      GuestModel(id: '${DateTime.now().millisecondsSinceEpoch + 4}', name: "Mohanbhai dharmshi bhai", phone: "9499512127"),
    ];
    gp.addGuests(sampleContacts);
  }

  Future<void> _importCsvVcfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'vcf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final path = result.files.single.path!;
      final file = File(path);
      final content = await file.readAsString(encoding: utf8);

      final List<GuestModel> parsedGuests = [];
      final isCsv = path.toLowerCase().endsWith('.csv');

      if (isCsv) {
        final rows = const CsvToListConverter().convert(content, eol: '\n');
        if (rows.isEmpty) {
          if (mounted) TopNotification.show(context, message: "CSV file is empty", type: NotificationType.error);
          return;
        }

        // Determine if first row is a header
        int startRow = 0;
        if (rows.isNotEmpty) {
          final firstRowCol1 = rows[0][0]?.toString().toLowerCase() ?? "";
          if (firstRowCol1.contains("name") || firstRowCol1.contains("title")) {
            startRow = 1; // Skip header
          }
        }

        final uuid = const Uuid();
        for (int i = startRow; i < rows.length; i++) {
          final row = rows[i];
          if (row.length < 2) continue;

          final name = row[0]?.toString().trim() ?? "";
          final rawPhone = row[1]?.toString().trim() ?? "";
          final phone = _normalizePhone(rawPhone);

          if (name.isNotEmpty && phone.length >= 10) {
            parsedGuests.add(GuestModel(
              id: uuid.v4(),
              name: name,
              phone: phone,
              note: row.length > 2 ? row[2]?.toString().trim() ?? "" : "",
              rsvpStatus: RsvpStatus.pending,
            ));
          }
        }
      } else {
        // Parse VCF/vCard
        final entries = content.split(RegExp(r'END:VCARD', caseSensitive: false));
        final uuid = const Uuid();

        for (var raw in entries) {
          final entry = raw.trim();
          if (entry.isEmpty) continue;

          final name = _extractVcfName(entry);
          final rawPhone = _extractVcfPhone(entry);
          final phone = _normalizePhone(rawPhone);

          if (name.isNotEmpty && phone.length >= 10) {
            parsedGuests.add(GuestModel(
              id: uuid.v4(),
              name: name,
              phone: phone,
              note: '',
              rsvpStatus: RsvpStatus.pending,
            ));
          }
        }
      }

      if (parsedGuests.isEmpty) {
        if (mounted) {
          TopNotification.show(context, message: "No valid guests found in the selected file", type: NotificationType.error);
        }
        return;
      }

      final gp = context.read<GuestProvider>();
      gp.addGuests(parsedGuests);
      InteractionService.logInteraction(
        type: 'import_contacts',
        description: 'Successfully imported ${parsedGuests.length} guests from ${isCsv ? 'CSV' : 'VCF'} file',
        details: {'guestCount': parsedGuests.length, 'fileType': isCsv ? 'CSV' : 'VCF'},
      );

      if (mounted) {
        TopNotification.show(context, message: "Successfully imported ${parsedGuests.length} guests from ${isCsv ? 'CSV' : 'VCF'} file");
      }
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, message: "Failed to import file: $e", type: NotificationType.error);
      }
    }
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

  String _extractVcfName(String vcard) {
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

  String _extractVcfPhone(String vcard) {
    final match = RegExp(r'TEL[^:]*:(.+)', caseSensitive: false).firstMatch(vcard);
    if (match == null) return "";
    return match.group(1) ?? "";
  }

  void _showEditDialog(GuestModel guest) {
    final lang = context.read<LanguageProvider>();
    final nameCtrl = TextEditingController(text: guest.name);
    final phoneCtrl = TextEditingController(text: guest.phone);
    RsvpStatus selectedStatus = guest.rsvpStatus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text(lang.editGuest, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),
                Text(lang.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: nameCtrl, decoration: InputDecoration(
                  hintText: lang.enterName, filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                )),
                const SizedBox(height: 14),
                Text(lang.phoneNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  decoration: InputDecoration(
                    hintText: lang.enterPhone, filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  )),
                const SizedBox(height: 14),
                Text(lang.rsvp, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<RsvpStatus>(
                      isExpanded: true, value: selectedStatus,
                      items: RsvpStatus.values.map((s) => DropdownMenuItem(value: s,
                        child: Text(lang.rsvpStatusLabel(s)))).toList(),
                      onChanged: (v) { if (v != null) setS(() => selectedStatus = v); },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showDeleteConfirm(guest);
                        },
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF94C66),
                          side: const BorderSide(color: Color(0xFFF94C66)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(lang.deleteGuest, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          context.read<GuestProvider>().updateGuest(guest.id,
                            name: nameCtrl.text.trim(), phone: phoneCtrl.text.trim(), rsvpStatus: selectedStatus);
                          InteractionService.logInteraction(
                            type: 'update_guest',
                            description: 'Updated details for guest: ${nameCtrl.text.trim()}',
                            details: {
                              'guestId': guest.id,
                              'guestName': nameCtrl.text.trim(),
                              'guestPhone': phoneCtrl.text.trim(),
                              'rsvpStatus': selectedStatus.name,
                            },
                          );
                          Navigator.pop(ctx);
                          TopNotification.show(context, message: lang.guestUpdated);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF94C66), foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(lang.saveChanges, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(GuestModel guest) {
    final lang = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Delete Guest?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              Text(lang.deleteGuestConfirm(guest.name), style: const TextStyle(fontSize: 15, color: Colors.black54)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(lang.cancel, style: const TextStyle(fontWeight: FontWeight.w600)))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () {
                    context.read<GuestProvider>().deleteGuest(guest.id);
                    InteractionService.logInteraction(
                      type: 'delete_guest',
                      description: 'Deleted guest: ${guest.name}',
                      details: {'guestId': guest.id, 'guestName': guest.name},
                    );
                    Navigator.pop(ctx);
                    TopNotification.show(context, message: lang.guestRemoved, type: NotificationType.info);
                  }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF94C66), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(lang.delete, style: const TextStyle(fontWeight: FontWeight.bold)))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportOptions() {
    final lang = context.read<LanguageProvider>();
    final guests = context.read<GuestProvider>().guests;
    if (guests.isEmpty) {
      TopNotification.show(context, message: lang.noGuestsToExport, type: NotificationType.error);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lang.exportGuestList, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(lang.chooseExportFormat, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            const SizedBox(height: 24),
            _buildExportTile(
              icon: Icons.table_chart_rounded,
              title: lang.csvFile,
              subtitle: lang.csvSubtitle,
              onTap: () => _handleExport(() => GuestExportService.exportToCsv(guests), "CSV"),
            ),
            _buildExportTile(
              icon: Icons.contacts_rounded,
              title: lang.vcfContacts,
              subtitle: lang.vcfSubtitle,
              onTap: () => _handleExport(() => GuestExportService.exportToVcf(guests), "VCF"),
            ),
            _buildExportTile(
              icon: Icons.picture_as_pdf_rounded,
              title: lang.pdfDocument,
              subtitle: lang.pdfSubtitle,
              onTap: () => _handleExport(() => GuestExportService.exportToPdf(guests), "PDF", isOpenOnly: true),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildExportTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFF94C66).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFFF94C66), size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.black26),
    );
  }

  Future<void> _handleExport(Future<File> Function() exportTask, String format, {bool isOpenOnly = false}) async {
    try {
      final file = await exportTask();
      InteractionService.logInteraction(
        type: 'export_guests_list',
        description: 'Exported guest list as $format',
        details: {'format': format, 'isOpenOnly': isOpenOnly},
      );
      if (isOpenOnly) {
        await OpenFile.open(file.path);
      } else {
        await Share.shareXFiles([XFile(file.path)], text: "Exported Guest List ($format)");
      }
    } catch (e) {
      if (mounted) TopNotification.show(context, message: "Export failed: $e", type: NotificationType.error);
    }
  }
}
