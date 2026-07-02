import 'dart:convert';
import 'api_client.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

class InteractionService {
  /// Logs a structured user interaction to the backend audit logs
  static Future<void> logInteraction({
    required String type,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final data = {
        'userId': userId,
        'type': type,
        'description': description,
        if (details != null) 'details': details,
      };

      await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/audit-logs'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );
    } catch (e) {
      print("Failed to log interaction to backend: $e");
    }
  }
}
