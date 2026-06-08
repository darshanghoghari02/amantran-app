import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class EmailAuthService {
  static String? _currentOtp;
  static String? _currentEmail;

  /// Generates a random 6-digit OTP code.
  static String generateOtp() {
    final rand = Random();
    final otp = (100000 + rand.nextInt(900000)).toString();
    _currentOtp = otp;
    return otp;
  }

  /// Sends the OTP code to the recipient email address.
  static Future<bool> sendOtp(String email, String otp) async {
    _currentEmail = email;
    _currentOtp = otp;

    try {
      final response = await http.post(
        Uri.parse("https://formsubmit.co/ajax/$email"),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "_subject": "Wedding Card App - Email Verification Code",
          "AppName": "Wedding Card App",
          "Verification OTP": otp,
          "Instruction": "Enter this code on the verification screen to verify your email. Valid for 10 minutes.",
        }),
      );

      if (response.statusCode == 200) {
        print("OTP email successfully sent to $email: code=$otp");
        return true;
      } else {
        print("Failed to send OTP email via FormSubmit: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error sending OTP email: $e");
      return false;
    }
  }

  /// Verifies if the entered OTP is correct.
  static bool verifyOtp(String email, String otp) {
    return _currentEmail == email && _currentOtp == otp;
  }
}
