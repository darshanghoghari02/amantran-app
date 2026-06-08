import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService = FirestoreService();

  static const String _profileCollection = 'profile';
  static const String _profileDocId = 'details';
  static const String _settingsCollection = 'settings';
  static const String _settingsDocId = 'preferences';

  /// Fetches the user profile from `users/{uid}/profile/details`
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final docSnap = await _firestoreService.getUserDoc(_profileCollection, _profileDocId).get();
      if (docSnap.exists) {
        return docSnap.data();
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  /// Saves or updates the user profile in `users/{uid}/profile/details`
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
    String? profileImagePath,
  }) async {
    final data = {
      'name': name,
      'phone': phone,
      'email': email,
      if (profileImagePath != null) 'profileImagePath': profileImagePath,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestoreService.getUserDoc(_profileCollection, _profileDocId).set(
        data,
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception("Failed to save profile: $e");
    }
  }

  /// Fetches the user settings from `users/{uid}/settings/preferences`
  Future<Map<String, dynamic>?> fetchSettings() async {
    try {
      final docSnap = await _firestoreService.getUserDoc(_settingsCollection, _settingsDocId).get();
      if (docSnap.exists) {
        return docSnap.data();
      }
    } catch (e) {
      print("Error fetching user settings: $e");
    }
    return null;
  }

  /// Saves or updates the user settings in `users/{uid}/settings/preferences`
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    try {
      await _firestoreService.getUserDoc(_settingsCollection, _settingsDocId).set(
        {
          ...settings,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw Exception("Failed to save settings: $e");
    }
  }

  /// Fetch primary user document from `app_users/{uid}`
  Future<Map<String, dynamic>?> fetchUserDocument(String uid) async {
    try {
      final docSnap = await FirebaseFirestore.instance.collection('app_users').doc(uid).get();
      if (docSnap.exists) {
        return docSnap.data();
      }
    } catch (e) {
      print("Error fetching user document from app_users/$uid: $e");
    }
    return null;
  }

  /// Create or update user document in `app_users/{uid}`
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
    final docRef = FirebaseFirestore.instance.collection('app_users').doc(uid);
    
    try {
      final docSnap = await docRef.get();
      
      final Map<String, dynamic> data = {
        'name': name,
        'email': email,
        if (phone != null) 'phone': phone,
        if (profilePhoto != null) 'profilePhoto': profilePhoto,
        'provider': provider,
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      if (!docSnap.exists) {
        data['role'] = role ?? 'user';
        data['accountStatus'] = accountStatus ?? 'active';
        data['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(data);
      } else {
        if (role != null) data['role'] = role;
        if (accountStatus != null) data['accountStatus'] = accountStatus;
        await docRef.update(data);
      }
    } catch (e) {
      throw Exception("Failed to save user document: $e");
    }
  }
}
