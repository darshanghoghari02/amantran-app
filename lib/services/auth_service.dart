import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'interaction_service.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      print("Firebase initialization error: $e");
    }
  }

  /// Sends OTP using Firebase. 
  /// callbacks: onCodeSent(verificationId), onFailed(error)
  static Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onFailed,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolution (not common on most phones, but handles it)
        await _auth.signInWithCredential(credential);
        InteractionService.logInteraction(
          type: 'login_success',
          description: 'User logged in successfully via Phone Auth auto-resolution',
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        print("Firebase sendOtp Verification Failed: [${e.code}] ${e.message}");
        onFailed(e.message ?? "Verification failed");
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
        InteractionService.logInteraction(
          type: 'otp_sent',
          description: 'OTP successfully sent to phone: $phone',
          details: {'phone': phone},
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  /// Verifies the OTP code with the verification ID
  static Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      InteractionService.logInteraction(
        type: 'login_success',
        description: 'User logged in successfully via OTP verification',
      );
      return true;
    } catch (e) {
      print("OTP Verification Error: $e");
      return false;
    }
  }

  static Future<void> signOut() async {
    // Log before sign out while user is still authenticated
    await InteractionService.logInteraction(
      type: 'sign_out',
      description: 'User signed out of the application',
    );
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
