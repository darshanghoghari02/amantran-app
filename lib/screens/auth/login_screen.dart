import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import '../../widgets/top_notification.dart';
import '../../services/auth_service.dart';
import 'otp_verification_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/email_auth_service.dart';

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

      AuthService.sendOtp(
        phone: formattedPhone,
        onCodeSent: (verificationId) {
          Navigator.pop(context); // Remove loading
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                phone: formattedPhone,
                verificationId: verificationId,
              ),
            ),
          );
          TopNotification.show(context,
              message: "OTP sent to $formattedPhone",
              type: NotificationType.success);
        },
        onFailed: (error) {
          Navigator.pop(context); // Remove loading
          TopNotification.show(context,
              message: error, type: NotificationType.error);
        },
      );
    } else {
      TopNotification.show(context,
          message: 'Please enter a valid 10-digit number',
          type: NotificationType.error);
    }
  }

  /// Generates a cryptographically secure random nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-_';
    final random = Random.secure();
    return List.generate(length, (index) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex format
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handleGoogleSignIn() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF94C66)),
      ),
    );

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) Navigator.pop(context); // Pop loading spinner
        return; // User canceled the picker
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userProvider = context.read<UserProvider>();
      // Mark as not OTP verified BEFORE logging in
      userProvider.setSocialOtpVerified(false);

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final name = firebaseUser.displayName ?? 'Google User';
        final email = firebaseUser.email ?? '';

        // Sync user doc
        await userProvider.saveOrUpdateUserInCloud(
          uid: firebaseUser.uid,
          name: name,
          email: email,
          profilePhoto: firebaseUser.photoURL,
          provider: 'google',
        );

        // Generate and send OTP
        final otp = EmailAuthService.generateOtp();
        await EmailAuthService.sendOtp(email, otp);

        if (mounted) {
          Navigator.pop(context); // Pop loading spinner

          TopNotification.show(
            context,
            message: "OTP sent to $email. [Test Code: $otp]",
            type: NotificationType.success,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: email,
                emailOtp: otp,
                name: name,
              ),
            ),
          );
        }
      } else {
        userProvider.setSocialOtpVerified(true);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      final userProvider = context.read<UserProvider>();
      userProvider.setSocialOtpVerified(true);
      if (mounted) {
        Navigator.pop(context); // Pop loading spinner
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF94C66)),
      ),
    );

    try {
      final rawNonce = _generateNonce();
      final shaNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: shaNonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userProvider = context.read<UserProvider>();
      // Mark as not OTP verified BEFORE logging in
      userProvider.setSocialOtpVerified(false);

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        final name = [
          appleCredential.givenName,
          appleCredential.familyName
        ].where((e) => e != null && e.isNotEmpty).join(' ');
        final finalName = name.isNotEmpty ? name : (firebaseUser.displayName ?? 'Apple User');
        final email = firebaseUser.email ?? '';

        await userProvider.saveOrUpdateUserInCloud(
          uid: firebaseUser.uid,
          name: finalName,
          email: email,
          profilePhoto: firebaseUser.photoURL,
          provider: 'apple',
        );

        // Generate and send OTP
        final otp = EmailAuthService.generateOtp();
        await EmailAuthService.sendOtp(email, otp);

        if (mounted) {
          Navigator.pop(context); // Pop loading spinner

          TopNotification.show(
            context,
            message: "OTP sent to $email. [Test Code: $otp]",
            type: NotificationType.success,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtpVerificationScreen(
                email: email,
                emailOtp: otp,
                name: finalName,
              ),
            ),
          );
        }
      } else {
        userProvider.setSocialOtpVerified(true);
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      final userProvider = context.read<UserProvider>();
      userProvider.setSocialOtpVerified(true);
      if (mounted) {
        Navigator.pop(context); // Pop loading spinner
        TopNotification.show(
          context,
          message: "Apple Sign-In failed: $e",
          type: NotificationType.error,
        );
      }
    }
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
                isReturningUser ? "Welcome Back" : "Login or Signup",
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              const Text(
                "Sign in to continue creating beautiful\ninvitations",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black45,
                    height: 1.4,
                    fontWeight: FontWeight.w500),
              ),

              // 3.5 Choose your account (Recent Profiles - only visible if returning)
              if (isReturningUser) ...[
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Choose your account",
                    style: TextStyle(
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
                                  child: account.profileImagePath != null
                                      ? (account.profileImagePath!.startsWith('http')
                                          ? Image.network(
                                              account.profileImagePath!,
                                              fit: BoxFit.cover,
                                            )
                                          : (File(account.profileImagePath!).existsSync()
                                              ? Image.file(
                                                  File(account.profileImagePath!),
                                                  fit: BoxFit.cover,
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
                                        message: "Account removed",
                                        type: NotificationType.info);
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'remove',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 20),
                                        SizedBox(width: 8),
                                        Text('Remove Account'),
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
                      ? "Log in or Sign up"
                      : "Enter Your Phone Number",
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
                        decoration: const InputDecoration(
                          hintText: "Enter 10-digit number",
                          hintStyle: TextStyle(
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
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "We'll send a code to verify your account",
                  style: TextStyle(
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
                        children: const [
                          Text("Secure & Private",
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A))),
                          SizedBox(height: 6),
                          Text(
                              "Your phone number is encrypted and used only for verification.",
                              style: TextStyle(
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
                      ? const Text("Continue",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text("Send OTP",
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w800)),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward_rounded, size: 22),
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
                      "Or login with",
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
                      ? "By continuing, you agree to our\nTerm of service Privacy Policy content Policy"
                      : "By proceeding, you agree to receive SMS messages for verification. Standard rates may apply.",
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
