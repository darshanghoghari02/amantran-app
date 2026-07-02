import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:async';
import '../../services/auth_service.dart';
import '../../widgets/top_notification.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';

import '../../services/email_auth_service.dart';
import '../../services/whatsapp_otp_service.dart';
import '../../providers/language_provider.dart';
import '../onboarding/onboarding_app_lang_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String? phone;
  final String? verificationId;
  final String? email;
  final String? emailOtp;
  final String? name;
  final bool isWhatsappOtp;

  const OtpVerificationScreen({
    Key? key,
    this.phone,
    this.verificationId,
    this.email,
    this.emailOtp,
    this.name,
    this.isWhatsappOtp = false,
  }) : super(key: key);

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer(30); 
  }

  void _startResendTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _secondsRemaining = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) { c.dispose(); }
    for (var f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length == 6) {
      setState(() => _isLoading = true);
      
      bool success = false;
      String? token;
      if (widget.email != null) {
        success = (otp == widget.emailOtp);
      } else if (widget.isWhatsappOtp) {
        // Verify OTP via backend API for WhatsApp
        final result = await WhatsappOtpService.verifyOtp(widget.phone!, otp);
        success = result['success'] ?? false;
        token = result['token'];
      } else {
        // Firebase SMS OTP verification (legacy)
        success = await AuthService.verifyOtp(
          verificationId: widget.verificationId!,
          smsCode: otp,
        );
      }

      setState(() => _isLoading = false);

      if (success) {
        final userProvider = context.read<UserProvider>();
        
        // Store JWT token if provided by backend
        if (token != null && token.isNotEmpty) {
          await userProvider.setAuthToken(token);
          print("✅ [OTP Screen] Token stored: ${token.substring(0, 20)}...");
        } else {
          print("⚠️ [OTP Screen] No token received from verification");
        }
        
        // Persist phone number so login survives app close / hot restart
        if (widget.phone != null && widget.phone!.isNotEmpty) {
          await userProvider.storeUserPhone(widget.phone!);
          print("✅ [OTP Screen] Phone stored: ${widget.phone}");
        }
        
        // Fetch profile from cloud
        await userProvider.fetchProfileFromCloud(phone: widget.phone);
        print("✅ [OTP Screen] Profile fetched from cloud");
        
        // Only update profile if it's incomplete
        if (!userProvider.isProfileComplete) {
          if (widget.email != null) {
            final existingPhone = userProvider.phone;
            final existingName = userProvider.name;
            await userProvider.updateProfile(
              name: existingName.isNotEmpty ? existingName : (widget.name ?? "User"),
              phone: (existingPhone.isNotEmpty && existingPhone != "+91 00000 00000" && existingPhone != "+910000000000")
                  ? existingPhone
                  : (widget.phone ?? ""),
              email: widget.email!,
            );
            print("✅ [OTP Screen] Profile updated");
          }
        }
        
        userProvider.setSocialOtpVerified(true);
        
        if (mounted) {
          // Check profile completion again after potential updates
          await userProvider.fetchProfileFromCloud(phone: widget.phone);
          
          if (mounted) {
            // For phone-only users (WhatsApp OTP), if they have a valid phone, go to home
            // For email users, require full profile completion
            final isPhoneOnlyUser = widget.isWhatsappOtp && widget.email == null;
            final hasValidPhone = userProvider.phone.isNotEmpty && 
                                   !userProvider.phone.contains('00000 00000') &&
                                   !userProvider.phone.contains('0000000000');
            
            print("🔍 [OTP Screen] Profile check - Complete: ${userProvider.isProfileComplete}, PhoneOnly: $isPhoneOnlyUser, ValidPhone: $hasValidPhone");
            
            if (userProvider.isProfileComplete || (isPhoneOnlyUser && hasValidPhone)) {
              Navigator.popUntil(context, (route) => route.isFirst);
              TopNotification.show(context, message: "Welcome!", type: NotificationType.success);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingAppLangScreen()),
                (route) => route.isFirst,
              );
            }
          }
        }
      } else {
        TopNotification.show(context, message: 'Invalid OTP. Please try again.', type: NotificationType.error);
        for (var c in _controllers) { c.clear(); }
        _focusNodes[0].requestFocus();
      }
    } else {
      TopNotification.show(context, message: 'Please enter all 6 digits', type: NotificationType.error);
    }
  }

  void _handleResend() async {
    if (_secondsRemaining > 0 || _isResending) return;

    setState(() => _isResending = true);

    if (widget.email != null) {
      final success = await EmailAuthService.sendOtp(widget.email!, widget.emailOtp!);
      if (success) {
        TopNotification.show(context, message: "OTP re-sent successfully", type: NotificationType.success);
        _startResendTimer(60); 
      } else {
        TopNotification.show(context, message: "Failed to resend OTP", type: NotificationType.error);
      }
    } else if (widget.isWhatsappOtp) {
      final result = await WhatsappOtpService.sendOtpToWhatsapp(widget.phone!);
      if (result['success']) {
        TopNotification.show(context, message: "OTP re-sent to WhatsApp successfully", type: NotificationType.success);
        _startResendTimer(60); 
      } else {
        TopNotification.show(context, message: result['error'] ?? "Failed to resend OTP", type: NotificationType.error);
      }
    } else {
      await AuthService.sendOtp(
        phone: widget.phone!,
        onCodeSent: (newVerificationId) {
          TopNotification.show(context, message: "OTP re-sent successfully", type: NotificationType.success);
          _startResendTimer(60); 
        },
        onFailed: (error) {
          TopNotification.show(context, message: error, type: NotificationType.error);
        },
      );
    }

    setState(() => _isResending = false);
  }

  String _formatTimer(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFF94C66), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFF94C66), borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: const Color(0xFFF94C66).withOpacity(0.2), borderRadius: BorderRadius.circular(2)))),
                ],
              ),
              const SizedBox(height: 30),
              
              Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFF94C66).withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('assets/images/invitation_logo.jpg', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              Text(
                widget.email != null 
                    ? lang.weSentAnEmail 
                    : (widget.isWhatsappOtp ? lang.weSentAWhatsappMessage : lang.weSentAnSms),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                widget.email != null
                    ? lang.enterCodeSentTo(widget.email!)
                    : lang.enterCodeSentTo(widget.phone!.replaceRange(4, 10, '*** *** ')),
                style: const TextStyle(fontSize: 14, color: Colors.black45, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              
              Text(
                lang.verificationCode,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ...List.generate(3, (index) => _buildOtpBox(index)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text("-", style: TextStyle(fontSize: 24, color: Colors.black12, fontWeight: FontWeight.w900)),
                  ),
                  ...List.generate(3, (index) => _buildOtpBox(index + 3)),
                ],
              ),
              const SizedBox(height: 20),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _secondsRemaining > 0 ? lang.resendIn(_formatTimer(_secondsRemaining)) : lang.readyToResend, 
                    style: const TextStyle(fontSize: 12, color: Colors.black38, fontWeight: FontWeight.w500)
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(lang.alreadyHaveAccountLogin, 
                      style: const TextStyle(fontSize: 12, color: Color(0xFF00A3FF), fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              Center(
                child: TextButton(
                  onPressed: _secondsRemaining > 0 ? null : _handleResend,
                  child: Text(
                    lang.didntReceiveCode, 
                    style: TextStyle(
                      color: _secondsRemaining > 0 ? Colors.black26 : const Color(0xFF1A1A1A), 
                      fontWeight: FontWeight.w800, 
                      fontSize: 14
                    )
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF94C66).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF94C66),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(lang.verifyAndContinue, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_forward_rounded, size: 22),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 48,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          decoration: const InputDecoration(border: InputBorder.none, counterText: ""),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }
}
