import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/guest_model.dart';
import '../../providers/guest_provider.dart';
import '../../widgets/top_notification.dart';
import '../../services/interaction_service.dart';

class AddGuestForm extends StatefulWidget {
  const AddGuestForm({super.key});
  @override
  State<AddGuestForm> createState() => _AddGuestFormState();
}

class _AddGuestFormState extends State<AddGuestForm> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  RsvpStatus _rsvpStatus = RsvpStatus.pending;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      TopNotification.show(context, message: "Please enter name and phone number", type: NotificationType.error);
      return;
    }
    final guestId = DateTime.now().millisecondsSinceEpoch.toString();
    context.read<GuestProvider>().addGuest(GuestModel(
      id: guestId,
      name: name,
      phone: phone,
      note: _noteCtrl.text.trim(),
      rsvpStatus: _rsvpStatus,
    ));
    InteractionService.logInteraction(
      type: 'add_guest',
      description: 'Manually added a new guest: $name',
      details: {
        'guestId': guestId,
        'guestName': name,
        'guestPhone': phone,
        'rsvpStatus': _rsvpStatus.name,
      },
    );
    Navigator.pop(context);
    TopNotification.show(context, message: "Guest added successfully");
  }

  @override
  Widget build(BuildContext context) {
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
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.arrow_back, size: 20, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text("Add Guest", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF94C66), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), elevation: 0,
                    ),
                    child: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Guest Name", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration("Enter name"),
                    ),
                    const SizedBox(height: 20),
                    const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                      decoration: _inputDecoration("Enter name phone number"),
                    ),
                    const SizedBox(height: 20),
                    const Text("Note(Optional)", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration("Add any note"),
                    ),
                    const SizedBox(height: 20),
                    const Text("RSVP status", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<RsvpStatus>(
                          isExpanded: true,
                          value: _rsvpStatus,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
                          items: RsvpStatus.values.map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name[0].toUpperCase() + s.name.substring(1), style: const TextStyle(fontSize: 14)),
                          )).toList(),
                          onChanged: (v) { if (v != null) setState(() => _rsvpStatus = v); },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true, fillColor: Colors.white,
      border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFF94C66))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    );
  }
}
