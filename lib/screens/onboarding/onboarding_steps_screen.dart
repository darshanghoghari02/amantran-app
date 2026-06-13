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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double viewportHeight = constraints.maxHeight;
            final bool isSmallScreen = viewportHeight < 700;
            
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportHeight,
                ),
                child: IntrinsicHeight(
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
                      SizedBox(height: isSmallScreen ? 20 : 30),
                      
                      // Premium Logo Container
                      Center(
                        child: Container(
                          width: isSmallScreen ? 70 : 90,
                          height: isSmallScreen ? 70 : 90,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 24),
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
                              borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 20),
                              child: Image.asset('assets/images/invitation_logo.jpg', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 35),
                      
                      Text(
                        lang.createInvitationIn3Steps,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 22 : 26,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1A1A1A),
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          lang.exploreCategoriesSubtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                            color: Colors.black45,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 25 : 40),
                      
                      // Step Cards
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            _buildStepCard(
                              icon: Icons.touch_app_rounded,
                              title: lang.chooseTemplate,
                              subtitle: lang.chooseTemplateSubtitle,
                              color: const Color(0xFFF94C66),
                              bgColor: const Color(0xFFFFF1F2),
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 18),
                            _buildStepCard(
                              icon: Icons.edit_document,
                              title: lang.customizeCard,
                              subtitle: lang.customizeCardSubtitle,
                              color: const Color(0xFFFFA726),
                              bgColor: const Color(0xFFFFF8E1),
                              isSmallScreen: isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 18),
                            _buildStepCard(
                              icon: Icons.share_rounded,
                              title: lang.downloadShare,
                              subtitle: lang.downloadShareSubtitle,
                              color: const Color(0xFF26A69A),
                              bgColor: const Color(0xFFE0F2F1),
                              isSmallScreen: isSmallScreen,
                            ),
                          ],
                        ),
                      ),
                      
                      const Spacer(),
                      const SizedBox(height: 24),
                      
                      // Next Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          height: isSmallScreen ? 52 : 60,
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
                            child: Text(
                              lang.next,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 20 : 30),
                    ],
                  ),
                ),
              ),
            );
          },
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
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 48 : 58,
            height: isSmallScreen ? 48 : 58,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 22 : 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: isSmallScreen ? 15 : 17, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 13, color: Colors.black45, height: 1.3, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
