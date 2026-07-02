import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../auth/login_screen.dart';

class OnboardingIntroScreen extends StatelessWidget {
  const OnboardingIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final size = MediaQuery.of(context).size;
    final EdgeInsets systemPadding = MediaQuery.of(context).padding;
    final double bottomInset = systemPadding.bottom; // height of system nav bar / gesture indicator
    final bool isSmallScreen = size.height < 700;
    // Add bottom inset so the sheet covers the nav bar visually but content sits above it
    final double sheetHeight = (isSmallScreen ? size.height * 0.68 : size.height * 0.62) + bottomInset;
    final double logoSize = isSmallScreen ? 85.0 : 95.0;
    final double logoOffset = logoSize / 2;

    // Sizing helper variables for features row and typography:
    final double featureTitleSize;
    final double featureSubtitleSize;
    final double featureIconContainerSize;
    final double featureIconSize;
    final double featureSpacing;
    final double dividerHeight;

    if (size.height < 700) {
      featureTitleSize = 11.5;
      featureSubtitleSize = 8.5;
      featureIconContainerSize = 48.0;
      featureIconSize = 22.0;
      featureSpacing = 10.0;
      dividerHeight = 36.0;
    } else if (size.height < 820) {
      featureTitleSize = 13.0;
      featureSubtitleSize = 10.0;
      featureIconContainerSize = 56.0;
      featureIconSize = 26.0;
      featureSpacing = 14.0;
      dividerHeight = 44.0;
    } else {
      featureTitleSize = 14.5;
      featureSubtitleSize = 11.0;
      featureIconContainerSize = 60.0;
      featureIconSize = 28.0;
      featureSpacing = 16.0;
      dividerHeight = 52.0;
    }

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
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(60), // Larger radius for smoother curve
                  topRight: Radius.circular(60),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: sheetHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: logoOffset + 15), // Dynamic space for logo
                          Text(
                            lang.appTitle,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 24 : (size.height > 820 ? 32 : 28),
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF1A1A1A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              lang.subtitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : (size.height > 820 ? 15 : 14),
                                color: Colors.black45,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          const Spacer(),
                          // Feature Row with Dividers
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                _buildFeature(
                                  icon: Icons.grid_view_rounded,
                                  title: lang.hundredPlusTemplates,
                                  subtitle: lang.forEveryOccasion,
                                  bgColor: const Color(0xFFFFF0F1),
                                  iconColor: const Color(0xFFF94C66),
                                  titleSize: featureTitleSize,
                                  subtitleSize: featureSubtitleSize,
                                  containerSize: featureIconContainerSize,
                                  iconSize: featureIconSize,
                                  spacing: featureSpacing,
                                ),
                                _buildDivider(dividerHeight),
                                _buildFeature(
                                  icon: Icons.auto_fix_high_rounded,
                                  title: lang.easyCustomize,
                                  subtitle: lang.editInFewTaps,
                                  bgColor: const Color(0xFFF5F0FF),
                                  iconColor: const Color(0xFF9B51E0),
                                  titleSize: featureTitleSize,
                                  subtitleSize: featureSubtitleSize,
                                  containerSize: featureIconContainerSize,
                                  iconSize: featureIconSize,
                                  spacing: featureSpacing,
                                ),
                                _buildDivider(dividerHeight),
                                _buildFeature(
                                  icon: Icons.near_me_rounded,
                                  title: lang.shareInstantly,
                                  subtitle: lang.withLovedOnes,
                                  bgColor: const Color(0xFFF0FFF4),
                                  iconColor: const Color(0xFF27AE60),
                                  titleSize: featureTitleSize,
                                  subtitleSize: featureSubtitleSize,
                                  containerSize: featureIconContainerSize,
                                  iconSize: featureIconSize,
                                  spacing: featureSpacing,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 20),
                          
                          // Get Started Button
                          Container(
                            width: double.infinity,
                            height: isSmallScreen ? 52 : 60,
                            // bottomInset ensures button sits above system nav bar / gesture indicator
                            margin: EdgeInsets.only(
                              bottom: (isSmallScreen ? 24.0 : 40.0) + bottomInset,
                            ),
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
                                lang.getStartedLabel,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : (size.height > 820 ? 20 : 18),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Logo Positioned Exactly
          Positioned(
            bottom: sheetHeight - logoOffset,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 24),
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
                    borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
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

  Widget _buildDivider(double height) {
    return Container(
      width: 1,
      height: height,
      color: Colors.black.withOpacity(0.05),
    );
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color bgColor,
    required Color iconColor,
    required double titleSize,
    required double subtitleSize,
    required double containerSize,
    required double iconSize,
    required double spacing,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: containerSize,
            height: containerSize,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: iconSize),
          ),
          SizedBox(height: spacing),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: subtitleSize,
              color: Colors.black38,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
