import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class GuestRepository {
  final FirestoreService _firestoreService = FirestoreService();
  static const String _guestsSubcollection = 'guests';

  /// Stream of all guests for the logged-in user from `users/{uid}/guests`
  Stream<List<Map<String, dynamic>>> watchGuests() {
    try {
      return _firestoreService
          .getUserSubcollection(_guestsSubcollection)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print("Error watching guests: $e");
      return Stream.value([]);
    }
  }

  /// Adds or updates a guest in `users/{uid}/guests/{guestId}`
  Future<void> saveGuest(String id, Map<String, dynamic> guestJson) async {
    try {
      await _firestoreService.getUserDoc(_guestsSubcollection, id).set({
        ...guestJson,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("Failed to save guest: $e");
    }
  }

  /// Deletes a guest from `users/{uid}/guests/{guestId}`
  Future<void> deleteGuest(String id) async {
    try {
      await _firestoreService.getUserDoc(_guestsSubcollection, id).delete();
    } catch (e) {
      print("Failed to delete guest: $e");
    }
  }

  /// Clears all guests for the current user
  Future<void> clearAllGuests() async {
    try {
      final snapshot = await _firestoreService.getUserSubcollection(_guestsSubcollection).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print("Failed to clear all guests: $e");
    }
  }
}
