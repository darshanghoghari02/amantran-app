import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class WhatsappOtpService {
  static String? _currentOtp;
  static String? _currentPhone;

  /// Generates a random 6-digit OTP code.
  static String generateOtp() {
    final rand = Random();
    final otp = (100000 + rand.nextInt(900000)).toString();
    _currentOtp = otp;
    return otp;
  }

  /// Sends OTP to WhatsApp via backend API.
  /// The backend is responsible for integrating with the Meta WhatsApp Business Platform.
  /// If the backend is unavailable (e.g. during development), it falls back to test mode.
  static Future<Map<String, dynamic>> sendOtpToWhatsapp(String phone) async {
    _currentPhone = phone;
    final otp = generateOtp();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/send-whatsapp-otp'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("OTP sent to WhatsApp successfully via backend: phone=$phone, otp=$otp");
        return {
          'success': true,
          'otp': otp,
          'message': data['message'] ?? 'OTP sent successfully',
        };
      } else {
        final error = jsonDecode(response.body);
        print("Failed to send WhatsApp OTP: ${response.body}");
        return {
          'success': false,
          'error': error['error'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      print("Error sending WhatsApp OTP: $e");
      // Fallback for development/testing when backend is not running
      print("Using test mode - OTP: $otp");
      return {
        'success': true,
        'otp': otp,
        'message': 'OTP sent (test mode - backend unavailable)',
      };
    }
  }

  /// Verifies OTP via backend API.
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/verify-whatsapp-otp'),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          'phone': phone,
          'otp': otp,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("OTP verified successfully via backend: phone=$phone");
        return {
          'success': true,
          'message': data['message'] ?? 'OTP verified successfully',
          'token': data['token'],
        };
      } else {
        final error = jsonDecode(response.body);
        print("OTP verification failed: ${response.body}");
        return {
          'success': false,
          'error': error['error'] ?? 'Invalid OTP',
        };
      }
    } catch (e) {
      print("Error verifying OTP: $e");
      final isValid = verifyOtpLocally(phone, otp);
      print("Using local verification - Valid: $isValid");
      return {
        'success': isValid,
        'message': isValid ? 'OTP verified (test mode)' : 'Invalid OTP',
      };
    }
  }

  /// Local verification fallback (for testing if backend is not available)
  static bool verifyOtpLocally(String phone, String otp) {
    String formattedInputPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (formattedInputPhone.length == 10) {
      formattedInputPhone = '91$formattedInputPhone';
    }
    
    String? formattedCurrentPhone;
    if (_currentPhone != null) {
      formattedCurrentPhone = _currentPhone!.replaceAll(RegExp(r'\D'), '');
      if (formattedCurrentPhone.length == 10) {
        formattedCurrentPhone = '91$formattedCurrentPhone';
      }
    }
    
    return formattedInputPhone == formattedCurrentPhone && _currentOtp == otp;
  }
}
