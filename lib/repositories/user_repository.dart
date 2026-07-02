import 'dart:convert';
import '../services/api_client.dart';
import '../config/api_config.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// Fetches the user profile from `/api/app/users/{uid}/profile`
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final uid = _firestoreService.currentUid;
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/users/$uid/profile'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  /// Saves or updates the user profile in `/api/app/users/{uid}/profile`
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
    String? profileImagePath,
  }) async {
    try {
      final uid = _firestoreService.currentUid;
      final data = {
        'name': name,
        'phone': phone,
        'email': email,
        if (profileImagePath != null) 'profileImagePath': profileImagePath,
        'updatedAt': DateTime.now().toIso8601String()
      };

      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/users/$uid/profile'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save profile: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to save profile: $e");
    }
  }

  /// Fetches the user settings from `/api/app/users/{uid}/settings`
  Future<Map<String, dynamic>?> fetchSettings() async {
    try {
      final uid = _firestoreService.currentUid;
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/users/$uid/settings'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching user settings: $e");
    }
    return null;
  }

  /// Saves or updates the user settings in `/api/app/users/{uid}/settings`
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      final uid = _firestoreService.currentUid;
      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/users/$uid/settings'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(settings),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save settings: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to save settings: $e");
    }
  }

  /// Fetch primary user document from `/api/app/users/{uid}`
  Future<Map<String, dynamic>?> fetchUserDocument(String uid) async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/users/$uid'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 404) {
        return null;
      }
      throw Exception("Server returned status ${response.statusCode}");
    } catch (e) {
      print("Error fetching user document from backend: $e");
      rethrow;
    }
  }

  /// Create or update user document in `/api/app/users`
  Future<void> saveUserDocument({
    required String uid,
    required String name,
    required String email,
    String? phone,
    String? profilePhoto,
    required String provider,
    String? role,
    String? accountStatus,
  }) async {
    try {
      final data = {
        'uid': uid,
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        if (profilePhoto != null) 'profilePhoto': profilePhoto,
        'provider': provider,
        if (role != null) 'role': role,
        if (accountStatus != null) 'accountStatus': accountStatus,
      };

      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/users'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        String serverError = response.body.trim();
        if (serverError.length > 150) {
          serverError = '${serverError.substring(0, 150)}...';
        }
        throw Exception("Failed to save user document: Status ${response.statusCode}\nBody: $serverError");
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Resolves user document from database by email or phone
  Future<Map<String, dynamic>?> resolveUserDocument({String? email, String? phone}) async {
    try {
      final queryParams = <String, String>{};
      if (email != null) queryParams['email'] = email;
      if (phone != null) queryParams['phone'] = phone;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/app/users/resolve/find').replace(queryParameters: queryParams);
      final response = await ApiClient.get(uri);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error resolving user document from API: $e");
    }
    return null;
  }

  /// Fetches rating for user from `/api/app/ratings/{userId}`
  Future<Map<String, dynamic>?> fetchRating(String userId) async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/ratings/$userId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Error fetching user rating: $e");
    }
    return null;
  }

  /// Saves or updates the rating in `/api/app/ratings`
  Future<void> saveRating({
    required String userId,
    required int rating,
    String? userName,
    String? userEmail,
    String? userPhone,
  }) async {
    try {
      final data = {
        'userId': userId,
        'rating': rating,
        if (userName != null) 'userName': userName,
        if (userEmail != null) 'userEmail': userEmail,
        if (userPhone != null) 'userPhone': userPhone,
      };

      final response = await ApiClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/app/ratings'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception("Failed to save rating: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to save rating: $e");
    }
  }

  /// Fetches all users from backend `/api/app/users`
  Future<List<Map<String, dynamic>>?> fetchAllUsers() async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/users'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e) {
      print("Error fetching all users: $e");
    }
    return null;
  }

  /// Updates user role and status in backend `/api/app/users/{uid}`
  Future<void> updateAppUser({
    required String uid,
    required String role,
    required String accountStatus,
  }) async {
    try {
      final data = {
        'role': role,
        'accountStatus': accountStatus,
      };

      final response = await ApiClient.put(
        Uri.parse('${ApiConfig.baseUrl}/api/app/users/$uid'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to update user: Status ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to update user: $e");
    }
  }

  /// Fetches transactions for user from `/api/app/transactions/{userId}`
  Future<List<Map<String, dynamic>>?> fetchTransactions(String userId) async {
    try {
      final response = await ApiClient.get(Uri.parse('${ApiConfig.baseUrl}/api/app/transactions/$userId'));
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((item) => item as Map<String, dynamic>).toList();
      }
    } catch (e) {
      print("Error fetching user transactions: $e");
    }
    return null;
  }
}
