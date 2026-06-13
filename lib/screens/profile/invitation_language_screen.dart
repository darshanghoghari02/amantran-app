import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_data_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/designs_provider.dart';
import '../editor/editor_screen.dart';
import '../../services/interaction_service.dart';
import '../../services/language_registry.dart';
import '../../models/user_design.dart';
import '../../models/template_model.dart';

class InvitationLanguageScreen extends StatefulWidget {
  final List<String> selectedLanguages;
  final TemplateModel? template;
  final bool isSingleSelect; // True for customize flow, false for profile settings flow!

  const InvitationLanguageScreen({
    super.key,
    required this.selectedLanguages,
    this.template,
    this.isSingleSelect = false,
  });

  @override
  State<InvitationLanguageScreen> createState() => _InvitationLanguageScreenState();
}

class _InvitationLanguageScreenState extends State<InvitationLanguageScreen> {
  // Mode specific selections
  late String _singleSelected;
  late List<String> _multiSelected;

  List<LanguagePickerItem> _availableLanguages(BuildContext context) {
    final appData = context.watch<AppDataProvider>();
    if (appData.languages.isNotEmpty) {
      LanguageRegistry.instance.updateFromBackend(appData.languages);
    }

    if (widget.template != null) {
      return LanguageRegistry.instance.filterLanguages(
        supportedLanguageRefs: widget.template!.supportedLanguages,
      );
    }

    if (widget.isSingleSelect) {
      return LanguageRegistry.instance.filterLanguages(
        allowedNames: widget.selectedLanguages.toSet(),
      );
    }

    return LanguageRegistry.instance.filterLanguages();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<AppDataProvider>().refreshDataSilently();
      }
    });
    if (widget.isSingleSelect) {
      final activeLang = Provider.of<LanguageProvider>(context, listen: false).activeInvitationLanguage;
      if (activeLang.isNotEmpty) {
        _singleSelected = activeLang;
      } else if (widget.selectedLanguages.isNotEmpty) {
        _singleSelected = widget.selectedLanguages.first;
      } else {
        _singleSelected = 'English';
      }
    } else {
      _multiSelected = List<String>.from(widget.selectedLanguages);
      if (_multiSelected.isEmpty) {
        _multiSelected.add('English');
      }
    }
  }

  void _toggleMultiLanguage(String langName) {
    setState(() {
      if (_multiSelected.contains(langName)) {
        if (_multiSelected.length > 1) {
          _multiSelected.remove(langName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one language.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _multiSelected.add(langName);
      }
    });
  }

  void _applyCardTranslation(BuildContext context, String targetLanguage) {
    final lang = context.read<LanguageProvider>();
    final inv = context.read<InvitationProvider>();
    if (inv.elements.isEmpty) return;
    inv.applyLanguageInstant(lang, invitationLanguage: targetLanguage);
  }

  void _syncLocalSelections(List<LanguagePickerItem> languages) {
    if (languages.isEmpty) return;
    final names = languages.map((l) => l.name).toSet();
    if (widget.isSingleSelect) {
      if (!names.contains(_singleSelected)) {
        _singleSelected = languages.first.name;
      }
    } else {
      _multiSelected.removeWhere((name) => !names.contains(name));
      if (_multiSelected.isEmpty) {
        _multiSelected.add(languages.first.name);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final languages = _availableLanguages(context);
    _syncLocalSelections(languages);
    final isLoading =
        context.watch<AppDataProvider>().isLoading && languages.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.black87,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.selectInvitationLanguages,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isSingleSelect
                            ? "Choose exactly one language for the editor"
                            : "Select one or more languages for your templates",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Top Selected Animated Chips Area (Only visible in MULTI-selection mode)
            if (!widget.isSingleSelect)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: _multiSelected.isNotEmpty ? 10 : 0,
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _multiSelected.map((langName) {
                      return Material(
                        color: Colors.transparent,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.only(left: 14, right: 8, top: 6, bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFF94C66).withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                langName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF94C66),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _toggleMultiLanguage(langName),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF94C66),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Body Area: Dynamic rendering based on select mode
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF94C66)),
                    )
                  : languages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No invitation languages available.\nPlease try again later.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : widget.isSingleSelect
                          ? _buildSingleSelectRadioList(languages)
                          : _buildMultiSelectGrid(languages),
            ),

            // Fixed Premium Bottom Continue Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.isSingleSelect) {
                      // Make sure the single selected language is part of the invitation languages
                      final currentLangs = Set<String>.from(lang.invitationLanguages);
                      currentLangs.add(_singleSelected);
                      lang.setInvitationLanguages(currentLangs);
                      
                      lang.setActiveInvitationLanguage(_singleSelected);
                      _applyCardTranslation(context, _singleSelected);
                      InteractionService.logInteraction(
                        type: 'change_invitation_language',
                        description: 'Changed active invitation language to $_singleSelected',
                        details: {'language': _singleSelected},
                      );

                      // If a template is provided, open card editor screen
                      final template = widget.template;
                      if (template != null) {
                        final designsProvider = context.read<DesignsProvider>();
                        UserDesign? existingDraft;
                        for (var d in designsProvider.drafts) {
                          if (d.template.id == template.id) {
                            existingDraft = d;
                            break;
                          }
                        }

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditorScreen(
                              template: template,
                              designId: existingDraft?.id,
                              initialElements: existingDraft?.elements,
                              initialLanguage: _singleSelected,
                            ),
                          ),
                        );
                      } else {
                        Navigator.pop(context, [_singleSelected]);
                      }
                    } else {
                      lang.setInvitationLanguages(_multiSelected.toSet());
                      if (!lang.invitationLanguages
                          .contains(lang.activeInvitationLanguage)) {
                        lang.setActiveInvitationLanguage(_multiSelected.first);
                      }
                      _applyCardTranslation(
                          context, lang.activeInvitationLanguage);
                      InteractionService.logInteraction(
                        type: 'change_invitation_languages',
                        description: 'Updated active invitation languages list to ${_multiSelected.join(', ')}',
                        details: {'languages': _multiSelected},
                      );
                      Navigator.pop(context, _multiSelected);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFFF94C66).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: Text(
                    widget.isSingleSelect ? "Continue" : "Apply",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Radio Button Selection (Single Select Customize Flow) ---
  Widget _buildSingleSelectRadioList(List<LanguagePickerItem> languages) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: languages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final langItem = languages[index];
        final langName = langItem.name;
        final script = langItem.script;
        final isSelected = _singleSelected == langName;

        return GestureDetector(
          onTap: () {
            setState(() {
              _singleSelected = langName;
            });
            if (widget.isSingleSelect) {
              context
                  .read<LanguageProvider>()
                  .setActiveInvitationLanguage(langName);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFFDFBFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF94C66)
                    : Colors.black87.withOpacity(0.06),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFF94C66).withOpacity(0.04)
                      : Colors.black.withOpacity(0.01),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Left: script preview tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF1F3)
                        : Colors.black87.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    script,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFFF94C66) : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Middle: Language name
                Expanded(
                  child: Text(
                    langName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
                // Right: Radio button indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF94C66)
                          : Colors.black87.withOpacity(0.18),
                      width: isSelected ? 6 : 2,
                    ),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Grid Item Selection (Multi Select Settings Flow) ---
  Widget _buildMultiSelectGrid(List<LanguagePickerItem> languages) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.25,
      ),
      itemCount: languages.length,
      itemBuilder: (context, index) {
        final l = languages[index];
        final langName = l.name;
        final script = l.script;
        final isSelected = _multiSelected.contains(langName);

        return GestureDetector(
          onTap: () => _toggleMultiLanguage(langName),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : const Color(0xFFFDFBFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFF94C66)
                    : Colors.black87.withOpacity(0.06),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFF94C66).withOpacity(0.06)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Tick Badge scaled nicely
                Positioned(
                  top: 12,
                  right: 12,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF94C66),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
                // Card content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        script,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? const Color(0xFFF94C66) : Colors.black54,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        langName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.black87 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
