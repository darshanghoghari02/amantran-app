import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String? _resolvedUid;
  String? get resolvedUid => _resolvedUid;

  final StreamController<String?> _uidStreamController = StreamController<String?>.broadcast();
  Stream<String?> get resolvedUidStream => _uidStreamController.stream;

  void setResolvedUid(String? uid) {
    if (_resolvedUid != uid) {
      _resolvedUid = uid;
      _uidStreamController.add(uid);
    }
  }

  void clearResolvedUid() {
    _resolvedUid = null;
    _uidStreamController.add(null);
  }

  /// Retrieves the current authenticated user's UID.
  /// Throws an exception if the user is not logged in.
  String get currentUid {
    if (_resolvedUid != null) {
      return _resolvedUid!;
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("No authenticated user found. Ensure user is logged in before database operations.");
    }
    return user.uid;
  }

  /// Get reference to user's isolated subcollection
  CollectionReference<Map<String, dynamic>> getUserSubcollection(String collectionPath) {
    return _db.collection('app_users').doc(currentUid).collection(collectionPath);
  }

  /// Get reference to a specific document under a user's isolated subcollection
  DocumentReference<Map<String, dynamic>> getUserDoc(String collectionPath, String docId) {
    return getUserSubcollection(collectionPath).doc(docId);
  }

  /// Enable offline persistence configuration if required
  Future<void> enableOfflinePersistence() async {
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Settings must be set before any database operations, otherwise it logs a warning
      print("Offline persistence setting failed/already configured: $e");
    }
  }
}
