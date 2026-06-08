import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../auth/login_screen.dart';

class OnboardingStepsScreen extends StatelessWidget {
  const OnboardingStepsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Progress Bar (Screen 4 style - Segments with rounded ends)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildProgressSegment(isActive: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProgressSegment(isActive: false)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildProgressSegment(isActive: false)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Premium Logo Container
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF94C66).withOpacity(0.12),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/invitation_logo.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 35),
            
            const Text(
              "Create Your Invitation\nin 3 Steps",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), height: 1.2, letterSpacing: -0.5),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Explore categories and create a perfect\ninvitation for your occasion",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black45, height: 1.5, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 40),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildStepCard(
                    icon: Icons.touch_app_rounded,
                    title: "Choose a Template",
                    subtitle: "Choose a design for your\noccasion",
                    color: const Color(0xFFF94C66),
                    bgColor: const Color(0xFFFFF1F2),
                  ),
                  const SizedBox(height: 18),
                  _buildStepCard(
                    icon: Icons.edit_document,
                    title: "Customize Your Card",
                    subtitle: "Edit text and add your details",
                    color: const Color(0xFFFFA726),
                    bgColor: const Color(0xFFFFF8E1),
                  ),
                  const SizedBox(height: 18),
                  _buildStepCard(
                    icon: Icons.share_rounded,
                    title: "Download & Share",
                    subtitle: "Download and share your\ninvitation easily",
                    color: const Color(0xFF26A69A),
                    bgColor: const Color(0xFFE0F2F1),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                height: 60,
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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: const Text("Next", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
            const SizedBox(height: 10),
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

  Widget _buildStepCard({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.black45, height: 1.4, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
