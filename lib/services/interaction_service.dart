import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';

class InteractionService {
  static final FirestoreService _firestoreService = FirestoreService();

  /// Logs a structured user interaction to the user's isolated subcollection `users/{uid}/interactions`
  static Future<void> logInteraction({
    required String type,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // Fail silently if user is not authenticated yet

      final docId = '${DateTime.now().millisecondsSinceEpoch}_$type';
      final docRef = _firestoreService.getUserDoc('interactions', docId);

      await docRef.set({
        'id': docId,
        'type': type,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        if (details != null) 'details': details,
      });
    } catch (e) {
      // Avoid printing in production if possible, but keep standard debug logging
      // so it is visible in the console
      print("Failed to log interaction to Firestore: $e");
    }
  }
}
