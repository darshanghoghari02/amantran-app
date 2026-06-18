import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_data_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/language_registry.dart';
import 'onboarding_steps_screen.dart';

class OnboardingInvitationLangScreen extends StatefulWidget {
  const OnboardingInvitationLangScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingInvitationLangScreen> createState() => _OnboardingInvitationLangScreenState();
}

class _OnboardingInvitationLangScreenState extends State<OnboardingInvitationLangScreen> {
  final List<String> _selected = ['English'];


  void _toggleLanguage(String langName) {
    setState(() {
      if (_selected.contains(langName)) {
        if (_selected.length > 1) {
          _selected.remove(langName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one language.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _selected.add(langName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final appData = context.watch<AppDataProvider>();
    if (appData.languages.isNotEmpty) {
      LanguageRegistry.instance.updateFromBackend(appData.languages);
    }
    final languages = LanguageRegistry.instance.activeLanguages;
    if (languages.isNotEmpty) {
      final names = languages.map((l) => l.name).toSet();
      _selected.removeWhere((name) => !names.contains(name));
      if (_selected.isEmpty) {
        _selected.add(languages.first.name);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFCF8F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Progress Bar (Screen 5 style - Segments with rounded ends)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildProgressSegment(isActive: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProgressSegment(isActive: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProgressSegment(isActive: false)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Onboarding Logo Image
            Center(
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF94C66).withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/invitation_logo.jpg', fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              lang.customizeInvitationLanguages,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lang.chooseInvitationLanguagesDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black45,
              ),
            ),
            const SizedBox(height: 14),

            // Top Selected Animated Chips Area
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: _selected.isNotEmpty ? 10 : 0,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selected.map((langName) {
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
                              onTap: () => _toggleLanguage(langName),
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

            const SizedBox(height: 6),

            // Selectable Grid
            Expanded(
              child: appData.isLoading && languages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF94C66)),
                    )
                  : GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                  final isSelected = _selected.contains(langName);

                  return GestureDetector(
                    onTap: () => _toggleLanguage(langName),
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
              ),
            ),

            // Next button fixed at bottom
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<LanguageProvider>().setInvitationLanguages(_selected.toSet());
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingStepsScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFFF94C66).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    lang.nextLabel,
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

  Widget _buildProgressSegment({required bool isActive}) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFF94C66) : const Color(0xFFE9ECEF),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
