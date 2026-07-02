import 'dart:async';
import 'dart:convert';
import '../services/api_client.dart';
import '../config/api_config.dart';
import '../services/firestore_service.dart';

class DraftRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// Stream of user drafts from backend `/api/app/drafts/:userId`
  Stream<List<Map<String, dynamic>>> watchDrafts() {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) return Stream.value([]);

    return Stream.fromFuture(fetchDrafts(uid));
  }

  Future<List<Map<String, dynamic>>> fetchDrafts(String userId) async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/drafts/$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print("Error fetching drafts: $e");
    }
    return [];
  }

  /// Stream of completed user cards from backend `/api/app/cards/:userId`
  Stream<List<Map<String, dynamic>>> watchCards() {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) return Stream.value([]);

    return Stream.fromFuture(fetchCards(uid));
  }

  Future<List<Map<String, dynamic>>> fetchCards(String userId) async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/cards/$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print("Error fetching cards: $e");
    }
    return [];
  }

  /// Saves a draft to backend
  Future<void> saveDraft(String id, Map<String, dynamic> designJson) async {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) throw Exception("User not authenticated.");

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/drafts'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'userId': uid,
          ...designJson,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save draft to backend: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to save draft to backend: $e");
    }
  }

  /// Saves a completed card to backend and deletes it from drafts if it exists
  Future<void> saveCompleted(String id, Map<String, dynamic> designJson) async {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) throw Exception("User not authenticated.");

    try {
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/cards'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'userId': uid,
          ...designJson,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save completed card to backend: Status ${response.statusCode}");
      }

      // Remove from drafts if present
      await deleteDraft(id);
    } catch (e) {
      throw Exception("Failed to save completed card to backend: $e");
    }
  }

  /// Deletes a draft from backend
  Future<void> deleteDraft(String id) async {
    try {
      final response = await ApiClient.delete(Uri.parse('${ApiConfig.baseUrl}/api/app/drafts/$id'));
      if (response.statusCode != 200) {
        print("Failed to delete draft from backend: Status ${response.statusCode}");
      }
    } catch (e) {
      print("Failed to delete draft: $e");
    }
  }

  /// Deletes a completed card from backend
  Future<void> deleteCard(String id) async {
    try {
      final response = await ApiClient.delete(Uri.parse('${ApiConfig.baseUrl}/api/app/cards/$id'));
      if (response.statusCode != 200) {
        print("Failed to delete completed card from backend: Status ${response.statusCode}");
      }
    } catch (e) {
      print("Failed to delete completed card: $e");
    }
  }
}
