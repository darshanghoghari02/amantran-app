import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class DraftRepository {
  final FirestoreService _firestoreService = FirestoreService();

  static const String _draftsSubcollection = 'drafts';
  static const String _cardsSubcollection = 'cards';

  /// Stream of user drafts from `users/{uid}/drafts`
  Stream<List<Map<String, dynamic>>> watchDrafts() {
    try {
      return _firestoreService
          .getUserSubcollection(_draftsSubcollection)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print("Error watching drafts: $e");
      return Stream.value([]);
    }
  }

  /// Stream of completed user cards from `users/{uid}/cards`
  Stream<List<Map<String, dynamic>>> watchCards() {
    try {
      return _firestoreService
          .getUserSubcollection(_cardsSubcollection)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print("Error watching cards: $e");
      return Stream.value([]);
    }
  }

  /// Saves a draft to `users/{uid}/drafts/{id}`
  Future<void> saveDraft(String id, Map<String, dynamic> designJson) async {
    try {
      final docRef = _firestoreService.getUserDoc(_draftsSubcollection, id);
      await docRef.set({
        ...designJson,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to save draft to Firestore: $e");
    }
  }

  /// Saves a completed card to `users/{uid}/cards/{id}` and deletes it from drafts if it exists
  Future<void> saveCompleted(String id, Map<String, dynamic> designJson) async {
    try {
      final cardRef = _firestoreService.getUserDoc(_cardsSubcollection, id);
      await cardRef.set({
        ...designJson,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Remove from drafts if present
      await deleteDraft(id);
    } catch (e) {
      throw Exception("Failed to save completed card to Firestore: $e");
    }
  }

  /// Deletes a draft from `users/{uid}/drafts/{id}`
  Future<void> deleteDraft(String id) async {
    try {
      final docRef = _firestoreService.getUserDoc(_draftsSubcollection, id);
      await docRef.delete();
    } catch (e) {
      print("Failed to delete draft: $e");
    }
  }

  /// Deletes a completed card from `users/{uid}/cards/{id}`
  Future<void> deleteCard(String id) async {
    try {
      final docRef = _firestoreService.getUserDoc(_cardsSubcollection, id);
      await docRef.delete();
    } catch (e) {
      print("Failed to delete completed card: $e");
    }
  }
}
