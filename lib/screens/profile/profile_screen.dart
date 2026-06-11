import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_language_screen.dart';
import 'invitation_language_screen.dart';
import '../../providers/language_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/rating_dialog.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/subscription_bottom_sheet.dart';
import '../auth/login_screen.dart';
import 'user_management_screen.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/subscription_plan.dart';
import '../subscription/subscription_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
            children: [
              // ── Back Arrow (top-left) ──
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF94C66),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Avatar with dashed circle border ──
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _DashedCirclePainter(
                    color: const Color(0xFFF94C66).withOpacity(0.5),
                    strokeWidth: 1.5,
                    dashCount: 40,
                  ),
                  child: Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: context.watch<UserProvider>().profileImagePath !=
                                null
                            ? (context.watch<UserProvider>().profileImagePath!.startsWith('http')
                                ? Image.network(
                                    context.watch<UserProvider>().profileImagePath!,
                                    fit: BoxFit.cover)
                                : Image.file(
                                    File(context
                                        .watch<UserProvider>()
                                        .profileImagePath!),
                                    fit: BoxFit.cover))
                            : Image.asset(
                                'assets/images/banner_image.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Name ──
              Text(
                context.watch<UserProvider>().name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),

              // ── Email ──
              Text(
                context.watch<UserProvider>().email,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),

              const SizedBox(height: 24),
              _buildSubscriptionCard(context),
              const SizedBox(height: 24),

              // ── Menu Items — fills remaining space, scrolls if needed ──
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (userProvider.isAdmin) ...[
                      _buildMenuItem(
                        icon: Icons.admin_panel_settings_outlined,
                        title: "User Management",
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UserManagementScreen(),
                            ),
                          );
                        },
                      ),
                      _divider(),
                    ],
                    // App Language
                    _buildMenuItem(
                      icon: Icons.language,
                      title: lang.appLanguage,
                      trailing: Text(
                        lang.nativeLanguageName,
                        style: const TextStyle(
                          color: Color(0xFFF94C66),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AppLanguageScreen()),
                        );
                      },
                    ),
                    _divider(),

                    // Invitation Language
                    _buildMenuItem(
                      icon: Icons.translate,
                      title: lang.invitationLanguage,
                      trailing: Text(
                        "${lang.invitationLanguages.length} ${lang.selected}",
                        style: const TextStyle(
                          color: Color(0xFFF94C66),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InvitationLanguageScreen(
                              selectedLanguages:
                                  lang.invitationLanguages.toList(),
                            ),
                          ),
                        );
                        if (result != null && result is List<String>) {
                          lang.setInvitationLanguages(result.toSet());
                        }
                      },
                    ),
                    _divider(),

                    // Rate Us
                    _buildMenuItem(
                      icon: Icons.star_border_rounded,
                      title: lang.rateUs,
                      onTap: () async {
                        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                        if (uid.isEmpty) return;

                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFF94C66),
                            ),
                          ),
                        );

                        bool alreadyHasRating = false;
                        try {
                          final doc = await FirebaseFirestore.instance
                              .collection('app_users')
                              .doc(uid)
                              .collection('ratings')
                              .doc('user_rating')
                              .get();
                          if (doc.exists && doc.data() != null) {
                            alreadyHasRating = true;
                          }
                        } catch (e) {
                          debugPrint("Error checking rating: $e");
                        }

                        if (context.mounted) {
                          Navigator.pop(context); // Close loading indicator
                        }

                        if (alreadyHasRating) {
                          if (context.mounted) {
                            TopNotification.show(
                              context,
                              message: lang.alreadyRated,
                              type: NotificationType.info,
                            );
                          }
                          return;
                        }

                        if (!context.mounted) return;

                        final rating = await showDialog<int>(
                          context: context,
                          builder: (ctx) => const RatingDialog(),
                        );
                        if (rating != null && context.mounted) {
                          // Save rating inside the user's document subcollection
                          try {
                            final userProvider = context.read<UserProvider>();
                            
                            await FirebaseFirestore.instance
                                .collection('app_users')
                                .doc(uid)
                                .collection('ratings')
                                .doc('user_rating')
                                .set({
                              'rating': rating,
                              'userId': uid,
                              'userName': userProvider.name,
                              'userEmail': userProvider.email,
                              'userPhone': userProvider.phone,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          } catch (e) {
                            debugPrint("Error saving rating to Firestore: $e");
                          }

                          if (context.mounted) {
                            TopNotification.show(context,
                                message: lang.thankYouRating);
                          }
                        }
                      },
                    ),
                    _divider(),

                    // Share App
                    _buildMenuItem(
                      icon: Icons.share_outlined,
                      title: lang.shareApp,
                      onTap: () async {
                        if (Platform.isAndroid) {
                          try {
                            const channel = MethodChannel('com.olivepatel.nimantran/apk_share');
                            final String? apkPath = await channel.invokeMethod<String>('getApkPath');
                            if (apkPath != null && apkPath.isNotEmpty) {
                              final file = File(apkPath);
                              if (await file.exists()) {
                                final tempDir = await getTemporaryDirectory();
                                final tempApk = File('${tempDir.path}/Nimantran.apk');
                                if (!await tempApk.exists()) {
                                  await file.copy(tempApk.path);
                                }
                                await Share.shareXFiles(
                                  [XFile(tempApk.path)],
                                  text: lang.shareAppText,
                                );
                                return;
                              }
                            }
                          } catch (e) {
                            debugPrint("Error sharing APK: $e");
                          }
                        }
                        await Share.share(lang.shareAppText);
                      },
                    ),
                    _divider(),

                    // Terms Conditions
                    _buildMenuItem(
                      icon: Icons.description_outlined,
                      title: lang.termsConditions,
                      onTap: () {
                        TopNotification.show(context,
                            message: lang.comingSoon,
                            type: NotificationType.info);
                      },
                    ),
                    _divider(),

                    // Privacy Policy
                    _buildMenuItem(
                      icon: Icons.privacy_tip_outlined,
                      title: lang.privacyPolicy,
                      onTap: () {
                        TopNotification.show(context,
                            message: lang.comingSoon,
                            type: NotificationType.info);
                      },
                    ),
                    _divider(),

                    // Sign Out
                    _buildMenuItem(
                      icon: Icons.logout,
                      title: lang.signOut,
                      isDestructive: true,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    lang.logoutConfirmation,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    lang.logoutMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.black87,
                                            side: const BorderSide(
                                                color: Colors.black26),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                          ),
                                          child: Text(lang.cancel,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            context.read<UserProvider>().logout();
                                            Navigator.pop(ctx);
                                            Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LoginScreen(showWelcomeBack: true)),
                                              (route) => false,
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFF94C66),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            elevation: 4,
                                            shadowColor: const Color(0xFFF94C66)
                                                .withOpacity(0.4),
                                          ),
                                          child: Text(lang.confirm,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),       // Padding
                ),     // SingleChildScrollView
              ),       // Expanded

            ],
          ),           // Column (outer)
        ),             // SafeArea
      );               // Scaffold


  }

  Widget _buildSubscriptionCard(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final isSubscribed = subProvider.isSubscribed;
    final sub = subProvider.subscription;

    String formatDate(DateTime date) {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${months[date.month - 1]} ${date.day}, ${date.year}";
    }

    if (isSubscribed) {
      final isYearly = sub.planType == 'yearly';
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFFFD700).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      color: Color(0xFFFFD700),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.planType == 'trial'
                              ? "Premium Free Trial"
                              : subProvider.plans
                                  .firstWhere(
                                    (p) => p.id == sub.planType,
                                    orElse: () => SubscriptionPlanModel(
                                      id: sub.planType,
                                      name: sub.planType == 'yearly'
                                          ? "Premium Yearly Plan"
                                          : sub.planType == 'monthly'
                                              ? "Premium Monthly Plan"
                                              : "${sub.planType.toUpperCase()} Plan",
                                      price: 0.0,
                                      description: '',
                                      isActive: true,
                                      includedCategories: [],
                                      includedTemplateIds: [],
                                    ),
                                  )
                                  .name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              "Active",
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white10, height: 1, thickness: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Valid Until",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    formatDate(sub.expiryDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF94C66).withOpacity(0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF94C66).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: Color(0xFFF94C66),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Upgrade to Premium",
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Unlock all templates & high-quality downloads",
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionManagementScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Subscribe Now",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _divider() {
    return Divider(color: Colors.grey.shade100, height: 1, thickness: 1);
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDestructive ? const Color(0xFFF94C66) : Colors.black45,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color:
                      isDestructive ? const Color(0xFFF94C66) : Colors.black87,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 🎨 DASHED CIRCLE PAINTER (for avatar border)
// ─────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedCirclePainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashCount = 40,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth;
    const fullAngle = 2 * pi;
    final dashAngle = fullAngle / dashCount;
    final gapAngle = dashAngle * 0.4;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle - gapAngle;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
