import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError("No authenticated user found. Ensure user is logged in before uploading files.");
    }
    return user.uid;
  }

  /// Uploads a file to Firebase Storage under the isolated path `users/{uid}/{folderName}/{unique_filename}`.
  /// Allowed folders: `uploads`, `templates`, `previews`.
  Future<String> uploadFile({
    required File file,
    required String folder, // e.g. 'uploads', 'templates', 'previews'
    String? customFileName,
  }) async {
    final uid = _uid;
    final fileExtension = p.extension(file.path);
    final fileName = customFileName ?? "${const Uuid().v4()}$fileExtension";

    // Ensure the folder matches requirements
    if (folder != 'uploads' && folder != 'templates' && folder != 'previews') {
      throw ArgumentError("Invalid storage folder '$folder'. Only 'uploads', 'templates', and 'previews' are allowed.");
    }

    final storageRef = _storage.ref().child('app_users').child(uid).child(folder).child(fileName);

    try {
      final uploadTask = await storageRef.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception("Failed to upload file to Firebase Storage: $e");
    }
  }

  /// Deletes a file from Firebase Storage using its download URL or reference path.
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      // Enforce security by checking that the path starts with the user's isolated location
      if (!ref.fullPath.startsWith("app_users/$_uid/")) {
        throw StateError("Permission denied: You can only delete your own files.");
      }
      await ref.delete();
    } catch (e) {
      print("Failed to delete file from Firebase Storage: $e");
    }
  }
}
