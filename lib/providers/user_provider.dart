import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../repositories/user_repository.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class AccountModel {
  final String name;
  final String phone;
  final String email;
  final String? profileImagePath;

  AccountModel({
    required this.name,
    required this.phone,
    required this.email,
    this.profileImagePath,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'email': email,
    'profileImagePath': profileImagePath,
  };

  factory AccountModel.fromMap(Map<dynamic, dynamic> map) => AccountModel(
    name: map['name'] ?? '',
    phone: map['phone'] ?? '',
    email: map['email'] ?? '',
    profileImagePath: map['profileImagePath'],
  );
}

class UserProvider extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _name = '';
  String _phone = '';
  String _email = '';
  String? _profileImagePath;
  String _role = 'user';
  String _accountStatus = 'active';
  bool _isLoading = false;
  bool _isSocialOtpVerified = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  final List<AccountModel> _recentAccounts = []; // Empty or memory-only list to satisfy layout interfaces

  UserProvider() {
    _init();
  }

  String get name => _name;
  String get phone => _phone;
  String get email => _email;
  String? get profileImagePath => _profileImagePath;
  String get role => _role;
  String get accountStatus => _accountStatus;
  bool get isAdmin => _role == 'admin';
  bool get isSuspended => _accountStatus == 'suspended';
  bool get isLoading => _isLoading;
  bool get isSocialOtpVerified => _isSocialOtpVerified;
  List<AccountModel> get recentAccounts => _recentAccounts;

  bool get isProfileComplete {
    final hasName = _name.trim().isNotEmpty && 
        _name.toLowerCase() != 'new user' && 
        _name.toLowerCase() != 'user';
        
    final normalizedEmail = _normalizeEmail(_email);
    final hasEmail = normalizedEmail.isNotEmpty && 
        normalizedEmail != 'user@example.com' &&
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(normalizedEmail);
        
    final cleanedPhone = _phone.replaceAll(RegExp(r'\D'), '');
    final hasPhone = _phone.isNotEmpty && 
        _phone != '+91 00000 00000' && 
        _phone != '+910000000000' &&
        cleanedPhone.length >= 10;
        
    return hasName && hasEmail && hasPhone;
  }

  String _normalizePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length == 10 && !cleaned.startsWith('+')) {
      cleaned = '+91$cleaned';
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  void setSocialOtpVerified(bool val) {
    _isSocialOtpVerified = val;
    notifyListeners();
  }

  QueryDocumentSnapshot<Map<String, dynamic>> _selectBestDocument(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.length == 1) return docs.first;

    QueryDocumentSnapshot<Map<String, dynamic>> bestDoc = docs.first;
    int bestScore = -1;

    for (final doc in docs) {
      final data = doc.data();
      int score = 0;

      final provider = data['provider'] as String? ?? '';
      if (provider == 'google' || provider == 'google.com' || provider == 'apple' || provider == 'apple.com') {
        score += 10;
      }

      final email = data['email'] as String? ?? '';
      final normalizedEmail = _normalizeEmail(email);
      final hasRealEmail = normalizedEmail.isNotEmpty && 
          normalizedEmail != 'user@example.com' &&
          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(normalizedEmail);
      if (hasRealEmail) {
        score += 5;
      }

      final name = data['name'] as String? ?? '';
      final hasRealName = name.trim().isNotEmpty && 
          name.toLowerCase() != 'new user' && 
          name.toLowerCase() != 'user';
      if (hasRealName) {
        score += 5;
      }

      final phone = data['phone'] as String? ?? '';
      final cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
      final hasRealPhone = phone.isNotEmpty && 
          phone != '+91 00000 00000' && 
          phone != '+910000000000' &&
          cleanedPhone.length >= 10;
      if (hasRealPhone) {
        score += 2;
      }

      if (score > bestScore) {
        bestScore = score;
        bestDoc = doc;
      }
    }

    return bestDoc;
  }

  Future<String> _resolveUid(User user) async {
    try {
      print("[_resolveUid] Resolving user: UID=${user.uid}, email=${user.email}, phone=${user.phoneNumber}");
      
      if (user.email != null && user.email!.isNotEmpty) {
        final email = _normalizeEmail(user.email!);
        print("[_resolveUid] Querying by email: $email");
        final emailQuery = await FirebaseFirestore.instance
            .collection('app_users')
            .where('email', isEqualTo: email)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          final bestDoc = _selectBestDocument(emailQuery.docs);
          print("[_resolveUid] Resolved by email match to: ${bestDoc.id}");
          return bestDoc.id;
        }
      }

      final rawPhone = user.phoneNumber;
      if (rawPhone != null && rawPhone.isNotEmpty) {
        final phone = _normalizePhone(rawPhone);
        print("[_resolveUid] Querying by phone: $phone");
        final phoneQuery = await FirebaseFirestore.instance
            .collection('app_users')
            .where('phone', isEqualTo: phone)
            .get();
        if (phoneQuery.docs.isNotEmpty) {
          final bestDoc = _selectBestDocument(phoneQuery.docs);
          print("[_resolveUid] Resolved by phone match to: ${bestDoc.id}");
          return bestDoc.id;
        }
      }
    } catch (e) {
      print("Error resolving UID: $e");
    }
    print("[_resolveUid] Falling back to default UID: ${user.uid}");
    return user.uid;
  }

  Future<void> _mergeUserData(String sourceUid, String targetUid) async {
    if (sourceUid == targetUid) return;

    final firestore = FirebaseFirestore.instance;
    print("Merging user data from $sourceUid to $targetUid...");

    try {
      final collections = ['drafts', 'cards', 'guests', 'templates'];
      for (final col in collections) {
        final srcCol = firestore.collection('app_users').doc(sourceUid).collection(col);
        final destCol = firestore.collection('app_users').doc(targetUid).collection(col);

        final snapshot = await srcCol.get();
        final batch = firestore.batch();

        for (final doc in snapshot.docs) {
          batch.set(destCol.doc(doc.id), doc.data(), SetOptions(merge: true));
          batch.delete(doc.reference);
        }
        await batch.commit();
      }

      // Merge subscription if target does not have one, or keep the active one
      final srcSubDoc = firestore.collection('user_subscriptions').doc(sourceUid);
      final destSubDoc = firestore.collection('user_subscriptions').doc(targetUid);

      final srcSub = await srcSubDoc.get();
      final destSub = await destSubDoc.get();

      if (srcSub.exists) {
        final srcData = srcSub.data()!;
        final destData = destSub.exists ? destSub.data() : null;

        bool shouldCopy = false;
        if (destData == null) {
          shouldCopy = true;
        } else {
          final srcActive = srcData['isActive'] == true;
          final destActive = destData['isActive'] == true;
          if (srcActive && !destActive) {
            shouldCopy = true;
          }
        }

        if (shouldCopy) {
          await destSubDoc.set(srcData, SetOptions(merge: true));
        }
        await srcSubDoc.delete();
      }

      // Finally delete the source user document
      await firestore.collection('app_users').doc(sourceUid).delete();
      print("User data merge complete.");
    } catch (e) {
      print("Error merging user data: $e");
    }
  }

  Future<void> _init() async {
    await _loadRecentAccounts();

    // Listen to Firebase Auth state changes
    _auth.authStateChanges().listen((user) async {
      _userSub?.cancel();
      if (user != null) {
        _isLoading = true;
        notifyListeners();

        // Resolve UID based on email/phone matching
        final resolvedUid = await _resolveUid(user);
        FirestoreService().setResolvedUid(resolvedUid);

        // Setup real-time listener to user's doc
        _userSub = FirebaseFirestore.instance.collection('app_users').doc(resolvedUid).snapshots().listen((docSnap) async {
          _isLoading = false;
          if (docSnap.exists) {
            final data = docSnap.data();
            if (data != null) {
              _name = data['name'] ?? '';
              _email = data['email'] ?? '';
              _profileImagePath = data['profilePhoto'];
              _role = data['role'] ?? 'user';
              final rawStatus = data['accountStatus'] ?? data['status'];
              if (rawStatus != null) {
                _accountStatus = rawStatus.toString().toLowerCase() == 'suspended' ? 'suspended' : 'active';
              } else if (data['isBlocked'] == true) {
                _accountStatus = 'suspended';
              } else {
                _accountStatus = 'active';
              }
              _phone = data['phone'] ?? user.phoneNumber ?? '';

              if (_name.isNotEmpty) {
                _addToRecentAccounts(AccountModel(
                  name: _name,
                  phone: _phone,
                  email: _email,
                  profileImagePath: _profileImagePath,
                ));
              }
              notifyListeners();
            }
          } else {
            // Document doesn't exist, create it initially
            _name = user.displayName ?? '';
            _email = user.email ?? '';
            _profileImagePath = user.photoURL;
            _role = 'user';
            _accountStatus = 'active';
            _phone = user.phoneNumber ?? '';

            // Create user document
            await _userRepository.saveUserDocument(
              uid: resolvedUid,
              name: _name.isEmpty ? 'New User' : _name,
              email: _email.isEmpty ? 'user@example.com' : _email,
              phone: _normalizePhone(_phone),
              profilePhoto: _profileImagePath,
              provider: user.providerData.isNotEmpty ? user.providerData.first.providerId : 'google',
            );
          }
        }, onError: (e) {
          print("Error listening to user document: $e");
          _isLoading = false;
          notifyListeners();
        });
      } else {
        _clearInMemoryState();
      }
    });
  }

  /// Fetches the user profile from Cloud Firestore
  Future<void> fetchProfileFromCloud() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Proactively resolve the UID to avoid race conditions during login/OTP verification
    final resolvedUid = await _resolveUid(user);
    FirestoreService().setResolvedUid(resolvedUid);

    final userDoc = await _userRepository.fetchUserDocument(resolvedUid);
    if (userDoc != null) {
      _name = userDoc['name'] ?? '';
      _email = userDoc['email'] ?? '';
      _profileImagePath = userDoc['profilePhoto'];
      _role = userDoc['role'] ?? 'user';
      final rawStatus = userDoc['accountStatus'] ?? userDoc['status'];
      if (rawStatus != null) {
        _accountStatus = rawStatus.toString().toLowerCase() == 'suspended' ? 'suspended' : 'active';
      } else if (userDoc['isBlocked'] == true) {
        _accountStatus = 'suspended';
      } else {
        _accountStatus = 'active';
      }
      _phone = userDoc['phone'] ?? user.phoneNumber ?? '';

      if (_name.isNotEmpty) {
        _addToRecentAccounts(AccountModel(
          name: _name,
          phone: _phone,
          email: _email,
          profileImagePath: _profileImagePath,
        ));
      }
      notifyListeners();
    } else {
      final profile = await _userRepository.fetchProfile();
      if (profile != null) {
        _name = profile['name'] ?? '';
        _phone = profile['phone'] ?? user.phoneNumber ?? '';
        _email = profile['email'] ?? '';
        _profileImagePath = profile['profileImagePath'];
        _role = 'user';
        _accountStatus = 'active';

        await _userRepository.saveUserDocument(
          uid: resolvedUid,
          name: _name,
          email: _email,
          phone: _normalizePhone(_phone),
          profilePhoto: _profileImagePath,
          provider: user.providerData.isNotEmpty ? user.providerData.first.providerId : 'phone',
        );
        notifyListeners();
      } else {
        _phone = user.phoneNumber ?? '';
        _role = 'user';
        _accountStatus = 'active';
        notifyListeners();
      }
    }
  }

  Future<void> saveOrUpdateUserInCloud({
    required String uid,
    required String name,
    required String? email,
    String? phone,
    String? profilePhoto,
    required String provider,
  }) async {
    await _userRepository.saveUserDocument(
      uid: uid,
      name: name,
      email: email ?? 'user@example.com',
      phone: phone != null ? _normalizePhone(phone) : null,
      profilePhoto: profilePhoto,
      provider: provider,
    );
  }

  /// Updates profile in Cloud Firestore, uploading the local profile image to Firebase Storage first if needed
  void updateProfile({
    required String name,
    required String phone,
    required String email,
    String? profileImagePath,
  }) {
    _name = name;
    _phone = phone;
    _email = email;
    if (profileImagePath != null) {
      _profileImagePath = profileImagePath;
    }

    _addToRecentAccounts(AccountModel(
      name: _name,
      phone: _phone,
      email: _email,
      profileImagePath: _profileImagePath,
    ));

    notifyListeners();

    // Trigger background upload and Firestore sync asynchronously
    _syncProfileToCloudInBackground(
      name: name,
      phone: phone,
      email: email,
      localImagePath: profileImagePath,
    );
  }

  Future<void> _syncProfileToCloudInBackground({
    required String name,
    required String phone,
    required String email,
    String? localImagePath,
  }) async {
    String? finalImageUrl = localImagePath;

    try {
      // 1. Upload file if it's a local file
      if (localImagePath != null && !localImagePath.startsWith('http') && File(localImagePath).existsSync()) {
        finalImageUrl = await _storageService.uploadFile(
          file: File(localImagePath),
          folder: 'uploads',
          customFileName: 'profile_picture_${DateTime.now().millisecondsSinceEpoch}',
        );

        // Update the in-memory path to the remote URL now that it is uploaded successfully
        _profileImagePath = finalImageUrl;
        notifyListeners();

        // Also update the local cached account with the remote URL
        _addToRecentAccounts(AccountModel(
          name: _name,
          phone: _phone,
          email: _email,
          profileImagePath: _profileImagePath,
        ));
      }

      final currentResolvedUid = FirestoreService().currentUid;
      final normalizedEmail = _normalizeEmail(email);
      final normalizedPhone = _normalizePhone(phone);

      // Check if another user document exists with this phone or email
      String? duplicateUid;
      if (normalizedEmail.isNotEmpty) {
        final emailQuery = await FirebaseFirestore.instance
            .collection('app_users')
            .where('email', isEqualTo: normalizedEmail)
            .get();
        for (final doc in emailQuery.docs) {
          if (doc.id != currentResolvedUid) {
            duplicateUid = doc.id;
            break;
          }
        }
      }

      if (duplicateUid == null && normalizedPhone.isNotEmpty) {
        final phoneQuery = await FirebaseFirestore.instance
            .collection('app_users')
            .where('phone', isEqualTo: normalizedPhone)
            .get();
        for (final doc in phoneQuery.docs) {
          if (doc.id != currentResolvedUid) {
            duplicateUid = doc.id;
            break;
          }
        }
      }

      String targetUid = currentResolvedUid;
      if (duplicateUid != null) {
        // We have a duplicate! Let's choose the primary UID
        // Prefer the Google/Apple one as targetUid, or currentResolvedUid if no preference
        final dupDoc = await FirebaseFirestore.instance.collection('app_users').doc(duplicateUid).get();
        final dupProvider = dupDoc.data()?['provider'] ?? '';
        final isDupSocial = dupProvider == 'google' || dupProvider == 'google.com' || dupProvider == 'apple' || dupProvider == 'apple.com';

        String sourceUid;
        if (isDupSocial) {
          targetUid = duplicateUid;
          sourceUid = currentResolvedUid;
        } else {
          targetUid = currentResolvedUid;
          sourceUid = duplicateUid;
        }

        // Merge sourceUid data into targetUid
        await _mergeUserData(sourceUid, targetUid);

        // If current resolved UID changed to targetUid, update it in FirestoreService
        if (targetUid != currentResolvedUid) {
          FirestoreService().setResolvedUid(targetUid);
          // Re-subscribe UserProvider's listener to the new targetUid!
          _userSub?.cancel();
          _userSub = FirebaseFirestore.instance.collection('app_users').doc(targetUid).snapshots().listen((docSnap) async {
            if (docSnap.exists) {
              final data = docSnap.data();
              if (data != null) {
                _name = data['name'] ?? '';
                _email = data['email'] ?? '';
                _profileImagePath = data['profilePhoto'];
                _role = data['role'] ?? 'user';
                _accountStatus = data['accountStatus'] ?? 'active';
                _phone = data['phone'] ?? _phone;
                notifyListeners();
              }
            }
          });
        }
      }

      // 2. Save profile details to Cloud Firestore
      await _userRepository.saveUserDocument(
        uid: targetUid,
        name: name,
        email: email,
        phone: normalizedPhone,
        profilePhoto: finalImageUrl,
        provider: _auth.currentUser?.providerData.isNotEmpty == true 
            ? _auth.currentUser!.providerData.first.providerId 
            : 'google',
      );

      print("Profile successfully synced to cloud.");
    } catch (e) {
      print("Error syncing profile to cloud: $e");
    }
  }

  Future<void> loginWithAccount(AccountModel account) async {
    _name = account.name;
    _phone = account.phone;
    _email = account.email;
    _profileImagePath = account.profileImagePath;
    notifyListeners();
  }

  Future<void> removeAccount(AccountModel account) async {
    _recentAccounts.removeWhere((a) => a.phone == account.phone);
    await _saveRecentAccounts();
    notifyListeners();
  }

  void _clearInMemoryState() {
    _name = '';
    _phone = '';
    _email = '';
    _profileImagePath = null;
    _role = 'user';
    _accountStatus = 'active';
    _isLoading = false;
    _isSocialOtpVerified = true;
    _userSub?.cancel();
    FirestoreService().clearResolvedUid();
    notifyListeners();
  }

  Future<void> logout() async {
    _clearInMemoryState();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> clearAll() async {
    await logout();
    _recentAccounts.clear();
    try {
      final box = await Hive.openBox(_recentAccountsBoxName);
      await box.delete('accounts');
    } catch (e) {
      print("Failed to delete recent accounts: $e");
    }
    notifyListeners();
  }

  // --- HIVE RECENT ACCOUNTS CACHE ---
  static const String _recentAccountsBoxName = 'recent_accounts_box';

  Future<void> _loadRecentAccounts() async {
    try {
      final box = await Hive.openBox(_recentAccountsBoxName);
      final list = box.get('accounts');
      if (list is List) {
        _recentAccounts.clear();
        final Set<String> seenNames = {};
        final Set<String> seenPhones = {};
        final Set<String> seenEmails = {};
        
        for (var item in list) {
          if (item is Map) {
            final account = AccountModel.fromMap(item);
            if (account.name.isEmpty) continue;
            
            final hasSeen = seenNames.contains(account.name) ||
                (account.phone.isNotEmpty && seenPhones.contains(account.phone)) ||
                (account.email.isNotEmpty && seenEmails.contains(account.email));
                
            if (!hasSeen) {
              _recentAccounts.add(account);
              seenNames.add(account.name);
              if (account.phone.isNotEmpty) seenPhones.add(account.phone);
              if (account.email.isNotEmpty) seenEmails.add(account.email);
            }
          }
        }
      }
    } catch (e) {
      print("Failed to load recent accounts: $e");
    }
  }

  Future<void> _saveRecentAccounts() async {
    try {
      final box = await Hive.openBox(_recentAccountsBoxName);
      final maps = _recentAccounts.map((a) => a.toMap()).toList();
      await box.put('accounts', maps);
    } catch (e) {
      print("Failed to save recent accounts: $e");
    }
  }

  void _addToRecentAccounts(AccountModel account) {
    if (account.name.isEmpty) return;
    
    // Remove duplicate entry if it exists with the same phone, email, or name
    _recentAccounts.removeWhere((a) => 
      (account.phone.isNotEmpty && a.phone == account.phone) ||
      (account.email.isNotEmpty && a.email == account.email) ||
      (account.name == a.name)
    );
    
    // Add the new/updated account at the beginning of the list
    _recentAccounts.insert(0, account);
    
    _saveRecentAccounts();
  }
}
