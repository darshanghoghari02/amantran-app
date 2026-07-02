import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:http/http.dart' as http;
import '../../providers/user_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/app_image.dart';
import '../../services/auth_service.dart';
import 'otp_verification_screen.dart';
import '../../config/api_config.dart';
import '../../services/whatsapp_otp_service.dart';
import '../../utils/image_resolver.dart';
import '../../utils/country_codes.dart';


class LoginScreen extends StatefulWidget {
  final bool showWelcomeBack;
  const LoginScreen({Key? key, this.showWelcomeBack = false}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  Country _selectedCountry = countries.firstWhere((c) => c.code == 'IN');
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _detectCountryCode();
  }

  void _detectCountryCode() {
    // 1. Try to get country from device system locale first (instant fallback)
    try {
      final countryCode = ui.PlatformDispatcher.instance.locale.countryCode;
      if (countryCode != null && countryCode.isNotEmpty) {
        setState(() {
          _selectedCountry = CountryParser.detectCountry(countryCode);
        });
      }
    } catch (e) {
      print("System locale detection failed: $e");
    }

    // 2. Fetch network-based IP country code asynchronously for precise detection
    http.get(Uri.parse('https://ipapi.co/json/')).then((response) {
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? netCountry = data['country_code']?.toString();
        if (netCountry != null && netCountry.isNotEmpty) {
          final matched = countries.firstWhere(
            (c) => c.code.toUpperCase() == netCountry.toUpperCase(),
            orElse: () => _selectedCountry,
          );
          if (mounted) {
            setState(() {
              _selectedCountry = matched;
            });
            print("Auto-detected IP country: ${matched.name} (${matched.dialCode})");
          }
        }
      }
    }).catchError((err) {
      print("Network-based country detection failed: $err. Using system locale.");
    });
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<Country> filteredList = countries.where((c) {
              final query = _searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.dialCode.contains(query) ||
                  c.code.toLowerCase().contains(query);
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Select Country",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                        ),
                        child: TextField(
                          onChanged: (val) {
                            setModalState(() {
                              _searchQuery = val;
                            });
                          },
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            hintText: "Search country or dial code...",
                            hintStyle: TextStyle(
                              color: Colors.black26,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            prefixIcon: Icon(Icons.search, color: Color(0xFFF94C66)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredList.isEmpty
                          ? const Center(
                              child: Text(
                                "No country found",
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: filteredList.length,
                              itemBuilder: (context, index) {
                                final country = filteredList[index];
                                final isSelected = country.code == _selectedCountry.code;
                                return ListTile(
                                  onTap: () {
                                    setState(() {
                                      _selectedCountry = country;
                                    });
                                    Navigator.pop(context);
                                  },
                                  leading: Text(
                                    country.flag,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(
                                    country.name,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? const Color(0xFFF94C66) : const Color(0xFF1A1A1A),
                                      fontSize: 15,
                                    ),
                                  ),
                                  trailing: Text(
                                    country.dialCode,
                                    style: TextStyle(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                                      color: isSelected ? const Color(0xFFF94C66) : Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      _searchQuery = "";
    });
  }

  void _onPhoneChanged(String val) {
    String text = val.trim();
    if (text.isEmpty) return;

    if (text.startsWith('00')) {
      text = '+' + text.substring(2);
    }

    if (text.startsWith('+')) {
      final country = CountryParser.parsePhone(text);
      final local = CountryParser.getLocalNumber(text);
      setState(() {
        _selectedCountry = country;
      });
      _phoneController.value = TextEditingValue(
        text: local,
        selection: TextSelection.collapsed(offset: local.length),
      );
      return;
    }

    if (text.length > 10) {
      final sorted = List<Country>.from(countries)
        ..sort((a, b) => b.dialCode.replaceAll(RegExp(r'\D'), '').length.compareTo(
            a.dialCode.replaceAll(RegExp(r'\D'), '').length));
      for (var country in sorted) {
        final dialDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
        if (dialDigits.isNotEmpty && text.startsWith(dialDigits)) {
          final local = text.substring(dialDigits.length);
          setState(() {
            _selectedCountry = country;
          });
          _phoneController.value = TextEditingValue(
            text: local,
            selection: TextSelection.collapsed(offset: local.length),
          );
          return;
        }
      }
    }
  }

  void _onContinue() {
    final phone = _phoneController.text.trim();
    final mismatchError = CountryParser.checkPhoneMismatch(_selectedCountry.dialCode, phone);
    if (mismatchError != null) {
      TopNotification.show(context,
          message: mismatchError,
          type: NotificationType.error);
      return;
    }

    if (RegExp(r'^\d{7,15}$').hasMatch(phone)) {
      final formattedPhone = '${_selectedCountry.dialCode}$phone';

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
          if (result['fallback'] == true) {
            // Show OTP in dialog when WhatsApp fails
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('OTP Code'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('WhatsApp is unavailable. Your OTP is:'),
                    const SizedBox(height: 16),
                    Text(
                      result['otp'],
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtpVerificationScreen(
                            phone: formattedPhone,
                            isWhatsappOtp: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Continue'),
                  ),
                ],
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  phone: formattedPhone,
                  isWhatsappOtp: true,
                ),
              ),
            );
          }
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
          message: 'Please enter a valid phone number',
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
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        },
        body: jsonEncode({
          'idToken': idToken,
        }),
      ).timeout(const Duration(seconds: 10));

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
        String serverError = response.body.trim();
        if (serverError.length > 150) {
          serverError = '${serverError.substring(0, 150)}...';
        }
        throw Exception("Status ${response.statusCode}: $serverError");
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF94C66)),
      ),
    );

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final String uid = credential.userIdentifier ?? '';
      if (uid.isEmpty) {
        throw Exception('Failed to obtain Apple User Identifier');
      }

      final String? email = credential.email;
      final String name = [
        credential.givenName,
        credential.familyName
      ].where((e) => e != null && e.isNotEmpty).join(' ');

      // Send credential to backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/apple-login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
        },
        body: jsonEncode({
          'uid': uid,
          'email': email,
          'name': name.isNotEmpty ? name : null,
        }),
      ).timeout(const Duration(seconds: 10));

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
              message: "Apple Sign-In successful",
              type: NotificationType.success,
            );

            if (mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          }
        } else {
          throw Exception(data['error'] ?? 'Apple login failed');
        }
      } else {
        String serverError = response.body.trim();
        if (serverError.length > 150) {
          serverError = '${serverError.substring(0, 150)}...';
        }
        throw Exception("Status ${response.statusCode}: $serverError");
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (mounted) {
        Navigator.pop(context);
        if (e.code == AuthorizationErrorCode.canceled) return;
        TopNotification.show(
          context,
          message: "Apple Sign-In cancelled: ${e.message}",
          type: NotificationType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
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
    final country = CountryParser.parsePhone(phone);
    final localNumber = CountryParser.getLocalNumber(phone);
    if (localNumber.length >= 4) {
      final last2 = localNumber.substring(localNumber.length - 2);
      return '${country.dialCode} XXXXX XXX$last2';
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
                          final parsedCountry = CountryParser.parsePhone(account.phone);
                          final localPhone = CountryParser.getLocalNumber(account.phone);

                          setState(() {
                            _selectedCountry = parsedCountry;
                            _phoneController.text = localPhone;
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
                                  child: AppImage(
                                    src: account.profileImagePath ?? '',
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
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
                  GestureDetector(
                    onTap: _showCountryPicker,
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedCountry.flag,
                            style: const TextStyle(fontSize: 18),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedCountry.dialCode,
                            style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.black54,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _phoneController,
                        onChanged: _onPhoneChanged,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                          LengthLimitingTextInputFormatter(15),
                        ],
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: lang.enterPhoneNumber,
                          hintStyle: const TextStyle(
                              color: Colors.black26,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
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
                  if (!kIsWeb && Platform.isIOS) ...[
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
