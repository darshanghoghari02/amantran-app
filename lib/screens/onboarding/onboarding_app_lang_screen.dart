import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'onboarding_invitation_lang_screen.dart';

class OnboardingAppLangScreen extends StatefulWidget {
  const OnboardingAppLangScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingAppLangScreen> createState() => _OnboardingAppLangScreenState();
}

class _OnboardingAppLangScreenState extends State<OnboardingAppLangScreen> {
  String _selectedLang = 'English';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'native': 'English'},
    {'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'name': 'Hindi', 'native': 'हिन्दी'},
    {'name': 'Marathi', 'native': 'मराठी'},
    {'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'name': 'Urdu', 'native': 'اردو'},
  ];

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<LanguageProvider>();
    final size = MediaQuery.of(context).size;
    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: isSmallScreen ? 6 : 10),
            Center(
              child: Container(
                width: isSmallScreen ? 50 : 60,
                height: isSmallScreen ? 50 : 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF94C66).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
                  child: Image.asset('assets/images/invitation_logo.jpg', fit: BoxFit.cover),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              langProvider.chooseAppLanguage,
              style: TextStyle(fontSize: isSmallScreen ? 18 : 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              langProvider.selectPreferredLanguage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmallScreen ? 13 : 14, color: Colors.black54),
            ),
            SizedBox(height: isSmallScreen ? 20 : 40),
            
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _languages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selectedLang == lang['name'];
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedLang = lang['name']!);
                      // 🔥 Optional: Apply instantly on tap
                      context.read<LanguageProvider>().setLanguage(_selectedLang);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? const Color(0xFFF94C66) : Colors.transparent),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            lang['native']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFFF94C66) : Colors.black87,
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFF94C66) : Colors.black26,
                                width: isSelected ? 6 : 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ElevatedButton(
                onPressed: () {
                  context.read<LanguageProvider>().setLanguage(_selectedLang);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingInvitationLangScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF94C66),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                child: Text(langProvider.nextLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
