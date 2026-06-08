import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/invitation_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/template_model.dart';
import '../../models/kankotri_data.dart';
import '../preview/preview_screen.dart';
import '../editor/widgets/transliteration_field.dart';
import '../../providers/language_provider.dart';

class FormScreen extends StatefulWidget {
  final TemplateModel template;
  
  final bool returnMode;

  const FormScreen({
    super.key,
    required this.template,
    
    this.returnMode = false,
  });

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  int currentStep = 0;

  // 🔹 DATA STORAGE (Bilingual)
                                                                                            
  final contactController = TextEditingController();
  final contact2Controller = TextEditingController();
  final dateController = TextEditingController();
  late List<EventModel> events;
  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<InvitationProvider>();
      contactController.text = provider.contact;
      contact2Controller.text = provider.contact2;
      dateController.text = provider.weddingDate;
    });
  }

  // 📅 Date Picker
  Future<void> pickDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      final dateStr = "${picked.day}/${picked.month}/${picked.year}";
      setState(() {
        controller.text = dateStr;
      });
      // Mark weddingDate as user-modified so it gets synced to elements
      if (mounted) {
        final provider = context.read<InvitationProvider>();
        provider.updateField(() {
          provider.weddingDate = dateStr;
        }, fieldName: 'weddingDate');
      }
    }
  }

  Future<void> pickTime(Function(String) onPicked) async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      if (mounted) {
        onPicked(picked.format(context));
      }
    }
  }

  @override
  void dispose() {
    contactController.dispose();
    contact2Controller.dispose();
    dateController.dispose();
    super.dispose();
  }

  void generateGujaratiText() {
    final provider = context.read<InvitationProvider>();
    final groom = provider.groomNameGu.isEmpty ? "વરનું નામ" : provider.groomNameGu;
    final bride = provider.brideNameGu.isEmpty ? "વધૂનું નામ" : provider.brideNameGu;
    final date = dateController.text.isEmpty ? "તારીખ" : dateController.text;

    setState(() {
      provider.invitationTextGu =
          "સ્નેહી શ્રી,\n\nસપ્રેમ નમસ્કાર, અમારા આંગણે રૂડા અવસરના વધામણાં છે. "
          "ચિ. $groom અને ચિ. $bride ના શુભ લગ્ન પ્રસંગે આપ સહપરિવાર પધારી "
          "નવદંપતીને આશીર્વાદ આપવા ભાવભર્યું નિમંત્રણ છે.\n\n"
          "લગ્ન તારીખ: $date";
      provider.invitationTextEn = 
          "We joyfully invite you to share in our happiness as we celebrate the wedding of "
          "$provider.groomNameEn & $provider.brideNameEn. Please grace us with your presence and blessings.\n\n"
          "Wedding Date: ${dateController.text}";
    });
  }

  Widget _buildHelpText(String text, {IconData icon = Icons.info_outline}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.blueGrey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.redAccent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvitationProvider>();
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(lang.weddingDetailsLabel),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        actions: [
          if (lang.invitationLanguages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: DropdownButton<String>(
                value: lang.invitationLanguages.contains(lang.activeInvitationLanguage)
                    ? lang.activeInvitationLanguage
                    : lang.invitationLanguages.first,
                dropdownColor: Colors.white,
                icon: const Icon(Icons.language, color: Colors.white),
                underline: const SizedBox(),
                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    lang.setActiveInvitationLanguage(newValue);
                  }
                },
                items: lang.invitationLanguages.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                selectedItemBuilder: (BuildContext context) {
                  return lang.invitationLanguages.map<Widget>((String item) {
                    return Center(
                      child: Text(
                        item,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList();
                },
              ),
            ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.redAccent),
        ),
        child: Stepper(
          type: StepperType.vertical,
          physics: const ClampingScrollPhysics(),
          currentStep: currentStep,
          onStepTapped: (step) => setState(() => currentStep = step),
          onStepContinue: () {
            if (currentStep < 6) {
              setState(() => currentStep++);
            } else {
              submit();
            }
          },
          onStepCancel: () {
            if (currentStep > 0) {
              setState(() => currentStep--);
            }
          },
          controlsBuilder: (BuildContext context, ControlsDetails details) {
            final isLastStep = currentStep == 6;
            return Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: details.onStepContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(isLastStep ? lang.previewLabel : lang.nextLabel),
                    ),
                  ),
                  if (currentStep > 0) const SizedBox(width: 12),
                  if (currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(lang.back),
                      ),
                    ),
                ],
              ),
            );
          },
          steps: [
            // 🔴 STEP 1: Page 1 (Cover Page)
            Step(
              state: currentStep > 0 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 0,
              title: const Text("Page 1: Cover Page (Shubh Vivah)", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Logo (img)"),
                  DefaultTabController(
                    length: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TabBar(
                          labelColor: Colors.redAccent,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Colors.redAccent,
                          tabs: [Tab(text: "Preset"), Tab(text: "Upload SVG")],
                        ),
                        SizedBox(
                          height: 120,
                          child: TabBarView(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  ganeshCard("assets/images/ganesh1.png"),
                                  ganeshCard("assets/images/ganesh2.png"),
                                  ganeshCard("assets/images/ganesh3.png"),
                                ],
                              ),
                              Center(child: Text("SVG upload available in app")),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionHeader("Bride & Groom"),
                  TransliterationField(
                    initialText: provider.brideNameEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: lang.brideName,
                    onChanged: (en, gu) { provider.updateField(() { provider.brideNameEn = en; provider.brideNameGu = gu; }, fieldName: 'brideName'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.groomNameEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: lang.groomName,
                    onChanged: (en, gu) { provider.updateField(() { provider.groomNameEn = en; provider.groomNameGu = gu; }, fieldName: 'groomName'); },
                  ),
                  const SizedBox(height: 16),

                  _buildSectionHeader("Date & Day"),
                  TextField(
                    controller: dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: lang.weddingDateLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: const Icon(Icons.calendar_month, color: Colors.redAccent),
                    ),
                    onTap: () => pickDate(dateController),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionHeader("Inviter (Organizer)"),
                  TransliterationField(
                    initialText: provider.fatherNameEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Father's Name (કમલેશકુમાર)",
                    onChanged: (en, gu) { provider.updateField(() { provider.fatherNameEn = en; provider.fatherNameGu = gu; }, fieldName: 'fatherName'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.motherNameEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Mother's Name (વીણાબેન)",
                    onChanged: (en, gu) { provider.updateField(() { provider.motherNameEn = en; provider.motherNameGu = gu; }, fieldName: 'motherName'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.addressEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Address (૧૨, વિશ્વરૂપા...)",
                    maxLines: 3,
                    onChanged: (en, gu) { provider.updateField(() { provider.addressEn = en; provider.addressGu = gu; }, fieldName: 'address'); },
                  ),
                ],
              ),
            ),

            // 🔴 STEP 2: Page 2 (Sangeet Sandhya)
            Step(
              state: currentStep > 1 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 1,
              title: const Text("Page 2: Sangeet Sandhya", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHelpText("Bride, Groom, and Date entered on Page 1 are automatically synced to Page 2. You can directly edit the Venue and Quotes on the Canvas."),
                ],
              ),
            ),

            // 🔴 STEP 3: Page 3 (Mangalik Prasango / Events)
            Step(
              state: currentStep > 2 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 2,
              title: const Text("Page 3: Mangalik Prasango (Events)", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHelpText("Add the events like Mandap Muhurat, Garba, etc."),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _quickAddEventChip("Mandap Muhurat", "મંડપ મુહૂર્ત"),
                        const SizedBox(width: 8),
                        _quickAddEventChip("Ras Garba", "રાસ ગરબા"),
                        const SizedBox(width: 8),
                        _quickAddEventChip("Hast Melap", "હસ્ત મેળાપ"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: List.generate(provider.events.length, (index) {
                      return eventCard(index);
                    }),
                  ),
                  if (provider.events.length < 5)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          provider.events.add(EventModel(title: "", titleGu: ""));
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: Text(lang.addEventLabel),
                    ),
                ],
              ),
            ),

            // 🔴 STEP 4: Page 4 (Lagnotsav)
            Step(
              state: currentStep > 3 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 3,
              title: const Text("Page 4: Lagnotsav", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHelpText("Bride and Groom details are synced from Page 1."),
                  TransliterationField(
                    initialText: provider.invitationTextEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Invitation Text / Welcome Quote",
                    maxLines: 4,
                    onChanged: (en, gu) { provider.updateField(() { provider.invitationTextEn = en; provider.invitationTextGu = gu; }, fieldName: 'invitationText'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.parentsNameFullEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Parents Details (e.g. જોષીપુરા નિવાસી...)",
                    maxLines: 3,
                    onChanged: (en, gu) { provider.updateField(() { provider.parentsNameFullEn = en; provider.parentsNameFullGu = gu; }, fieldName: 'parentsNameFull'); },
                  ),
                ],
              ),
            ),

            // 🔴 STEP 5: Page 5 (Parinay Utsav)
            Step(
              state: currentStep > 4 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 4,
              title: const Text("Page 5: Parinay Utsav", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHelpText("Events like Jaan Aagman, Hast Melap are synced from the events you added on Page 3. You can edit their coordinates directly on the Canvas."),
                ],
              ),
            ),

            // 🔴 STEP 6: Page 6 (Contact & Thanks)
            Step(
              state: currentStep > 5 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 5,
              title: const Text("Page 6: Contact & Thanks", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TransliterationField(
                    initialText: provider.nimantrakListEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Nimantrak List (Names)",
                    maxLines: 4,
                    onChanged: (en, gu) { provider.updateField(() { provider.nimantrakListEn = en; provider.nimantrakListGu = gu; }, fieldName: 'nimantrakList'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.noGiftsTextEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "No Gifts Text (ચાંદલો અસ્વીકાર્ય છે)",
                    onChanged: (en, gu) { provider.updateField(() { provider.noGiftsTextEn = en; provider.noGiftsTextGu = gu; }, fieldName: 'noGiftsText'); },
                  ),
                ],
              ),
            ),

            // 🔴 STEP 7: Page 7 (Traditional Lists)
            Step(
              state: currentStep > 6 ? StepState.complete : StepState.indexed,
              isActive: currentStep >= 6,
              title: const Text("Page 7: Traditional Lists", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TransliterationField(
                    initialText: provider.snehdhinEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Snehdhin List",
                    maxLines: 5,
                    onChanged: (en, gu) { provider.updateField(() { provider.snehdhinEn = en; provider.snehdhinGu = gu; }, fieldName: 'snehdhin'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.darshanabhilashiEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Darshanabhilashi List",
                    maxLines: 5,
                    onChanged: (en, gu) { provider.updateField(() { provider.darshanabhilashiEn = en; provider.darshanabhilashiGu = gu; }, fieldName: 'darshanabhilashi'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.mameruMosalEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Mameru / Mosal List",
                    maxLines: 3,
                    onChanged: (en, gu) { provider.updateField(() { provider.mameruMosalEn = en; provider.mameruMosalGu = gu; }, fieldName: 'mameruMosal'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.masiFoiLadlaEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Masi / Foi na Ladla",
                    maxLines: 3,
                    onChanged: (en, gu) { provider.updateField(() { provider.masiFoiLadlaEn = en; provider.masiFoiLadlaGu = gu; }, fieldName: 'masiFoiLadla'); },
                  ),
                  const SizedBox(height: 16),
                  TransliterationField(
                    initialText: provider.tahukoEn,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
                    label: "Tahuko (Poem)",
                    maxLines: 4,
                    onChanged: (en, gu) { provider.updateField(() { provider.tahukoEn = en; provider.tahukoGu = gu; }, fieldName: 'tahuko'); },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 GANESH CARD
  Widget ganeshCard(String path) {
    final provider = context.watch<InvitationProvider>();
    final isSelected = provider.logo.presetAsset == path;

    return GestureDetector(
      onTap: () {
        final newLogo = LogoModel(
          type: LogoType.preset,
          presetAsset: path,
        );
        provider.updateLogo(newLogo);
      },
      child: Container(
        width: 80,
        height: 90,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.redAccent : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected 
              ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 8)] 
              : null,
        ),
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }

  // 🔹 QUICK ADD CHIP
  Widget _quickAddEventChip(String enName, String guName) {
    return ActionChip(
      label: Text(enName, style: const TextStyle(fontSize: 12)),
      avatar: const Icon(Icons.add, size: 16),
      backgroundColor: Colors.red.shade50,
      side: BorderSide(color: Colors.red.shade200),
      onPressed: () {
        setState(() {
          final provider = context.read<InvitationProvider>();
          provider.events.add(EventModel(title: enName, titleGu: guName));
        });
      },
    );
  }

  // 🔥 EVENT CARD
  Widget eventCard(int index) {
    final provider = context.read<InvitationProvider>();
    final lang = context.watch<LanguageProvider>();
    final event = provider.events[index];
    final dateCtrl = TextEditingController(text: event.date);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Event ${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                if (provider.events.length > 1)
                  InkWell(
                    onTap: () => setState(() => provider.events.removeAt(index)),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TransliterationField(
              initialText: event.title,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
              label: lang.eventNameLabel,
              onChanged: (en, gu) { provider.updateField(() { 
                event.title = en;
                event.titleGu = gu;
               }, fieldName: 'events'); },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: lang.dateLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onTap: () => pickDate(dateCtrl).then((_) {
                      event.date = dateCtrl.text;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: event.time),
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: lang.timeLabel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    onTap: () => pickTime((time) {
                      setState(() {
                        event.time = time;
                      });
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TransliterationField(
              initialText: event.place,
                    isTransliterationOn: lang.activeInvitationLanguage != 'English',
                    language: lang.activeInvitationLanguage,
              label: lang.venuePlaceLabel,
              onChanged: (en, gu) { provider.updateField(() { 
                event.place = en;
                event.placeGu = gu;
               }, fieldName: 'events'); },
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 SUBMIT
  void submit() {
    final provider = context.read<InvitationProvider>();
    if (widget.returnMode) {
      Navigator.pop(context, provider.data);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            data: provider.data,
            template: widget.template,
            designId: DateTime.now().millisecondsSinceEpoch.toString(),
          ),
        ),
      );
    }
  }
}
