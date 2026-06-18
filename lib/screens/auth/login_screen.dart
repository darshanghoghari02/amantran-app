import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/top_notification.dart';
import '../../services/auth_service.dart';
import 'otp_verification_screen.dart';
import '../../config/api_config.dart';
import '../../services/whatsapp_otp_service.dart';
import '../../utils/image_resolver.dart';


class LoginScreen extends StatefulWidget {
  final bool showWelcomeBack;
  const LoginScreen({Key? key, this.showWelcomeBack = false}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  void _onContinue() {
    final phone = _phoneController.text.trim();
    if (RegExp(r'^\d{10}$').hasMatch(phone)) {
      final formattedPhone = '+91$phone';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFF94C66))),
      );

      // Try WhatsApp OTP first, fall back to Firebase SMS if backend is not available
      WhatsappOtpService.sendOtpToWhatsapp(formattedPhone).then((result) {
        Navigator.pop(context); // Remove loading
        
        if (result['success']) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phone: formattedPhone,
                isWhatsappOtp: true,
              ),
            ),
          );
        } else {
          // Fall back to Firebase SMS if WhatsApp OTP fails
          AuthService.sendOtp(
            phone: formattedPhone,
            onCodeSent: (verificationId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtpVerificationScreen(
                    phone: formattedPhone,
                    verificationId: verificationId,
                    isWhatsappOtp: false,
                  ),
                ),
              );
              TopNotification.show(context,
                  message: "OTP sent to $formattedPhone",
                  type: NotificationType.success);
            },
            onFailed: (error) {
              TopNotification.show(context,
                  message: error, type: NotificationType.error);
            },
          );
        }
      });
    } else {
      TopNotification.show(context,
          message: 'Please enter a valid 10-digit number',
          type: NotificationType.error);
    }
  }

  /// Generates a cryptographically secure random nonce



  Future<void> _handleGoogleSignIn() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF94C66)),
      ),
    );

    try {
      // Initialize GoogleSignIn natively
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: ApiConfig.googleClientId,
        scopes: ['email', 'profile'],
      );

      // Sign out first to force Google to show the account chooser popup every time
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Ignore if no account was signed in
      }

      // Trigger native account chooser popup
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the login flow
        if (mounted) Navigator.pop(context);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to obtain Google ID Token');
      }

      // Send ID token to backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['token'] != null) {
          final userProvider = context.read<UserProvider>();

          // Store JWT token from backend
          await userProvider.setAuthToken(data['token']);

          // Update user data from backend response
          if (data['user'] != null) {
            await userProvider.updateUserFromBackend(data['user']);
          }

          userProvider.setSocialOtpVerified(true);

          if (mounted) {
            Navigator.pop(context); // Pop loading spinner

            TopNotification.show(
              context,
              message: "Google Sign-In successful",
              type: NotificationType.success,
            );

            if (mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          }
        } else {
          throw Exception(data['error'] ?? 'Google login failed');
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Backend error: ${response.statusCode}');
      }
    } on PlatformException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        // User cancelled — don't show error
        final msg = e.message ?? '';
        if (msg.contains('cancel') || msg.contains('user_cancelled') || msg.contains('User cancelled')) return;
        TopNotification.show(
          context,
          message: "Google Sign-In cancelled: ${e.message}",
          type: NotificationType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        TopNotification.show(
          context,
          message: "Google Sign-In failed: $e",
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (Platform.isAndroid) {
      TopNotification.show(
        context,
        message: "Apple Sign-In is only available on iOS devices.",
        type: NotificationType.error,
      );
      return;
    }

    // Apple Sign-In not implemented for pure Google Sign-In setup
    TopNotification.show(
      context,
      message: "Apple Sign-In is not available. Please use Google Sign-In.",
      type: NotificationType.error,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _maskPhoneNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final last2 = digits.substring(digits.length - 2);
      return '+91 XXXXX XXX$last2';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final lang = context.watch<LanguageProvider>();
    final recentAccounts = user.recentAccounts;
    final isReturningUser = widget.showWelcomeBack && recentAccounts.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              // Progress Bar (Screen 5 style)
              Row(
                children: [
                  Expanded(
                      child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                              color: const Color(0xFFF94C66),
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(2)))),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Back Button (White circle)
              if (!isReturningUser) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Color(0xFFF94C66), size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 30),

              // 2. Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFF94C66).withOpacity(0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset('assets/images/invitation_logo.jpg',
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 3. Title & Subtitle
              Text(
                isReturningUser ? lang.welcomeBack : lang.loginOrSignup,
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                lang.signInToContinue,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                    height: 1.4,
                    fontWeight: FontWeight.w500),
              ),

              // 3.5 Choose your account (Recent Profiles - only visible if returning)
              if (isReturningUser) ...[
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    lang.chooseYourAccount,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A)),
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: recentAccounts.map((account) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          // Clean the phone number (remove +91 prefix and any non-digits)
                          String cleanPhone = account.phone;
                          if (cleanPhone.startsWith('+91')) {
                            cleanPhone = cleanPhone.substring(3);
                          }
                          cleanPhone = cleanPhone.replaceAll(RegExp(r'\D'), '');

                          setState(() {
                            _phoneController.text = cleanPhone;
                          });

                          // Automatically trigger sending OTP to this number
                          _onContinue();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.black.withOpacity(0.06)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: account.profileImagePath != null &&
                                          account.profileImagePath!.isNotEmpty
                                      ? (account.profileImagePath!.startsWith('http')
                                          ? Image.network(
                                              resolveImageUrl(account.profileImagePath!),
                                              fit: BoxFit.cover,
                                              key: ValueKey(account.profileImagePath!),
                                            )
                                          : (File(account.profileImagePath!).existsSync()
                                              ? Image.file(
                                                  File(account.profileImagePath!),
                                                  fit: BoxFit.cover,
                                                  key: ValueKey(account.profileImagePath!),
                                                )
                                              : Container(
                                                  color: const Color(0xFFF94C66).withOpacity(0.1),
                                                  child: Center(
                                                    child: Text(
                                                      account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
                                                      style: const TextStyle(
                                                        color: Color(0xFFF94C66),
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                )))
                                      : Container(
                                          color: const Color(0xFFF94C66)
                                              .withOpacity(0.1),
                                          child: Center(
                                            child: Text(
                                              account.name.isNotEmpty
                                                  ? account.name[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Color(0xFFF94C66),
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Name and masked phone
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _maskPhoneNumber(account.phone),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Three-dot options menu
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.black54),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onSelected: (value) {
                                  if (value == 'remove') {
                                    context
                                        .read<UserProvider>()
                                        .removeAccount(account);
                                    TopNotification.show(context,
                                        message: lang.accountRemoved,
                                        type: NotificationType.info);
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 20),
                                        const SizedBox(width: 8),
                                        Text(lang.removeAccount),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 32),

              // 4. Phone Input Section Title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isReturningUser
                      ? lang.logInOrSignUp
                      : lang.enterPhoneNumber,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: const Text("+91",
                        style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: lang.enter10DigitNumber,
                          hintStyle: const TextStyle(
                              color: Colors.black26,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lang.weWillSendVerificationCode,
                  style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 30),

              // 5. Secure & Private Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: const Color(0xFFF94C66).withOpacity(0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.security_rounded,
                        color: Color(0xFFF94C66), size: 22),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lang.secureAndPrivate,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 6),
                          Text(
                              lang.phoneEncryptionDisclaimer,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // 6. Continue / Send OTP Button
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFF94C66).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _onContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(29)),
                    elevation: 0,
                  ),
                  child: isReturningUser
                      ? Text(lang.continueButton,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(lang.sendOtp,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded, size: 22),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      lang.orLoginWith,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google Button
                  GestureDetector(
                    onTap: _handleGoogleSignIn,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/images/google_logo.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.g_mobiledata_rounded,
                            color: Colors.red,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Apple Button
                  GestureDetector(
                    onTap: _handleAppleSignIn,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // 7. Disclaimer Footer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  isReturningUser
                      ? lang.returningUserDisclaimer
                      : lang.newUserDisclaimer,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.black38,
                      fontSize: 11,
                      height: 1.6,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
