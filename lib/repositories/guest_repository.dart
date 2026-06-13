import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/firestore_service.dart';

class GuestRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// Stream of all guests for the logged-in user from backend `/api/app/guests/:userId`
  Stream<List<Map<String, dynamic>>> watchGuests() {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) return Stream.value([]);

    return Stream.fromFuture(fetchGuests(uid));
  }

  Future<List<Map<String, dynamic>>> fetchGuests(String userId) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/app/guests/$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      print("Error fetching guests: $e");
    }
    return [];
  }

  /// Adds or updates a guest in backend
  Future<void> saveGuest(String id, Map<String, dynamic> guestJson) async {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) throw Exception("User not authenticated.");

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/guests'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': id,
          'userId': uid,
          ...guestJson,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save guest: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to save guest: $e");
    }
  }

  /// Deletes a guest in backend
  Future<void> deleteGuest(String id) async {
    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/app/guests/$id'));
      if (response.statusCode != 200) {
        print("Failed to delete guest: Status ${response.statusCode}");
      }
    } catch (e) {
      print("Failed to delete guest: $e");
    }
  }

  /// Clears all guests for the current user
  Future<void> clearAllGuests() async {
    final uid = _firestoreService.resolvedUid;
    if (uid == null) return;

    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/api/app/guests/clear/$uid'));
      if (response.statusCode != 200) {
        print("Failed to clear guests: Status ${response.statusCode}");
      }
    } catch (e) {
      print("Failed to clear all guests: $e");
    }
  }
}
