import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import 'onboarding_app_lang_screen.dart';

class OnboardingIntroScreen extends StatelessWidget {
  const OnboardingIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Background Grid of Cards (More vibrant and dense)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.6,
            child: Opacity(
              opacity: 0.25, // Increased from 0.15
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 15,
                itemBuilder: (context, index) {
                  final cardIndex = (index % 9) + 1;
                  String cardPath;
                  if (cardIndex <= 3) {
                    cardPath = 'assets/images/wedding/card$cardIndex.jpg';
                  } else if (cardIndex <= 6) {
                    cardPath = 'assets/images/engagement/card$cardIndex.jpg';
                  } else {
                    cardPath = 'assets/images/baby_shower/card$cardIndex.jpg';
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      cardPath,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Smoother Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.6,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.9),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.5, 0.9, 1.0],
                ),
              ),
            ),
          ),

          // 3. Main Content Container with Custom Curve
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: size.height * 0.62,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(60), // Larger radius for smoother curve
                  topRight: Radius.circular(60),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 70), // More space for logo
                    Text(
                      lang.appTitle,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Text(
                        lang.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black45,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 45),
                    
                    // Feature Row with Dividers
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          _buildFeature(
                            Icons.grid_view_rounded,
                            "100+ Template",
                            "for every occasion",
                            const Color(0xFFFFF0F1),
                            const Color(0xFFF94C66),
                          ),
                          _buildDivider(),
                          _buildFeature(
                            Icons.auto_fix_high_rounded,
                            "Easy customize",
                            "edit in just few tape",
                            const Color(0xFFF5F0FF),
                            const Color(0xFF9B51E0),
                          ),
                          _buildDivider(),
                          _buildFeature(
                            Icons.near_me_rounded,
                            "Share instantly",
                            "with your loved ones",
                            const Color(0xFFF0FFF4),
                            const Color(0xFF27AE60),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    
                    // Get Started Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      margin: const EdgeInsets.only(bottom: 40),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF94C66).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingAppLangScreen()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF94C66),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 0,
                        ),
                        child: Text(
                          lang.getStartedLabel,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Logo Positioned Exactly
          Positioned(
            bottom: size.height * 0.62 - 45,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/invitation_logo.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.black.withOpacity(0.05),
    );
  }

  Widget _buildFeature(IconData icon, String title, String subtitle, Color bgColor, Color iconColor) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: Colors.black38, height: 1.3, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
