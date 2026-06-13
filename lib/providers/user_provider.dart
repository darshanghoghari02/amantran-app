import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  Timer? _statusTimer;

  final List<AccountModel> _recentAccounts = []; // Empty or memory-only list to satisfy layout interfaces

  UserProvider() {
    _init();
    // Periodically verify account status from backend to instantly enforce suspensions
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkUserStatusSilently();
    });
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
    
    // Profile is complete if user has name and email
    // Phone is optional for social login (Google/Apple)
    // Phone is required for phone login
    return hasName && hasEmail;
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


  Future<String> _resolveUid(User user) async {
    try {
      print("[_resolveUid] Resolving user: UID=${user.uid}, email=${user.email}, phone=${user.phoneNumber}");
      
      if (user.email != null && user.email!.isNotEmpty) {
        final email = _normalizeEmail(user.email!);
        print("[_resolveUid] Querying by email: $email");
        final matchedUser = await _userRepository.resolveUserDocument(email: email);
        if (matchedUser != null) {
          final resolvedId = matchedUser['uid'] ?? matchedUser['id'];
          if (resolvedId != null) {
            print("[_resolveUid] Resolved by email match to: $resolvedId");
            return resolvedId.toString();
          }
        }
      }

      final rawPhone = user.phoneNumber;
      if (rawPhone != null && rawPhone.isNotEmpty) {
        final phone = _normalizePhone(rawPhone);
        print("[_resolveUid] Querying by phone: $phone");
        final matchedUser = await _userRepository.resolveUserDocument(phone: phone);
        if (matchedUser != null) {
          final resolvedId = matchedUser['uid'] ?? matchedUser['id'];
          if (resolvedId != null) {
            print("[_resolveUid] Resolved by phone match to: $resolvedId");
            return resolvedId.toString();
          }
        }
      }
    } catch (e) {
      print("Error resolving UID: $e");
    }
    print("[_resolveUid] Falling back to default UID: ${user.uid}");
    return user.uid;
  }

  Future<void> _init() async {
    await _loadRecentAccounts();

    // Listen to Firebase Auth state changes
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        _isLoading = true;
        notifyListeners();

        try {
          // Resolve UID based on email/phone matching
          final resolvedUid = await _resolveUid(user);
          FirestoreService().setResolvedUid(resolvedUid);

          // Fetch user document from MySQL backend
          final userDoc = await _userRepository.fetchUserDocument(resolvedUid);
          _isLoading = false;

          if (userDoc != null) {
            _name = userDoc['name'] ?? '';
            _email = userDoc['email'] ?? '';
            _profileImagePath = userDoc['profilePhoto'];
            print("Initial profile image path loaded: $_profileImagePath");
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
          } else {
            // Document doesn't exist, create it initially
            _name = user.displayName ?? '';
            _email = user.email ?? '';
            _profileImagePath = user.photoURL;
            _role = 'user';
            _accountStatus = 'active';
            _phone = user.phoneNumber ?? '';

            // Create user document in MySQL backend
            await _userRepository.saveUserDocument(
              uid: resolvedUid,
              name: _name.isEmpty ? 'New User' : _name,
              email: _email.isEmpty ? 'user@example.com' : _email,
              phone: _normalizePhone(_phone),
              profilePhoto: _profileImagePath,
              provider: user.providerData.isNotEmpty ? user.providerData.first.providerId : 'google',
            );
          }
        } catch (e) {
          print("Error initializing user: $e");
          _isLoading = false;
        }
        notifyListeners();
      } else {
        _clearInMemoryState();
      }
    });
  }

  /// Fetches the user profile from Cloud / MySQL backend
  Future<void> fetchProfileFromCloud({String? phone}) async {
    final user = _auth.currentUser;
    
    String? resolvedUid = FirestoreService().resolvedUid;
    
    if (resolvedUid == null) {
      if (user != null) {
        resolvedUid = await _resolveUid(user);
      } else if (phone != null) {
        final normalized = _normalizePhone(phone);
        print("[fetchProfileFromCloud] Resolving UID by phone: $normalized");
        final matchedUser = await _userRepository.resolveUserDocument(phone: normalized);
        if (matchedUser != null) {
          resolvedUid = (matchedUser['uid'] ?? matchedUser['id'])?.toString();
          print("[fetchProfileFromCloud] Resolved UID by phone match: $resolvedUid");
        } else {
          final phoneDigits = normalized.replaceAll(RegExp(r'\D'), '');
          resolvedUid = 'whatsapp_$phoneDigits';
          print("[fetchProfileFromCloud] New WhatsApp user, using generated UID: $resolvedUid");
        }
      } else if (_phone.isNotEmpty) {
        final normalized = _normalizePhone(_phone);
        final matchedUser = await _userRepository.resolveUserDocument(phone: normalized);
        if (matchedUser != null) {
          resolvedUid = (matchedUser['uid'] ?? matchedUser['id'])?.toString();
        } else {
          final phoneDigits = normalized.replaceAll(RegExp(r'\D'), '');
          resolvedUid = 'whatsapp_$phoneDigits';
        }
      }
    }

    if (resolvedUid == null) {
      print("[fetchProfileFromCloud] resolvedUid is null, cannot fetch profile.");
      return;
    }

    FirestoreService().setResolvedUid(resolvedUid);

    final userDoc = await _userRepository.fetchUserDocument(resolvedUid);
    if (userDoc != null) {
      _name = userDoc['name'] ?? '';
      _email = userDoc['email'] ?? '';
      _profileImagePath = userDoc['profilePhoto'];
      print("Fetched profile image path: $_profileImagePath");
      _role = userDoc['role'] ?? 'user';
      final rawStatus = userDoc['accountStatus'] ?? userDoc['status'];
      if (rawStatus != null) {
        _accountStatus = rawStatus.toString().toLowerCase() == 'suspended' ? 'suspended' : 'active';
      } else if (userDoc['isBlocked'] == true) {
        _accountStatus = 'suspended';
      } else {
        _accountStatus = 'active';
      }
      _phone = userDoc['phone'] ?? phone ?? (user != null ? user.phoneNumber ?? '' : '');

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
      // Document doesn't exist on backend.
      if (user != null) {
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
      } else if (phone != null) {
        _name = '';
        _email = '';
        _phone = _normalizePhone(phone);
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
    String resolvedUid = uid;
    String? existingProfilePhoto;
    
    // Resolve UID first to avoid duplicate email/phone constraints on database
    if (email != null && email.isNotEmpty) {
      final normalizedEmail = _normalizeEmail(email);
      final matchedUser = await _userRepository.resolveUserDocument(email: normalizedEmail);
      if (matchedUser != null) {
        final resolvedId = matchedUser['uid'] ?? matchedUser['id'];
        if (resolvedId != null) {
          resolvedUid = resolvedId.toString();
          existingProfilePhoto = matchedUser['profilePhoto'];
          print("[saveOrUpdateUserInCloud] Resolved UID by email: $resolvedUid, existingPhoto: $existingProfilePhoto");
        }
      }
    } else if (phone != null && phone.isNotEmpty) {
      final normalizedPhone = _normalizePhone(phone);
      final matchedUser = await _userRepository.resolveUserDocument(phone: normalizedPhone);
      if (matchedUser != null) {
        final resolvedId = matchedUser['uid'] ?? matchedUser['id'];
        if (resolvedId != null) {
          resolvedUid = resolvedId.toString();
          existingProfilePhoto = matchedUser['profilePhoto'];
          print("[saveOrUpdateUserInCloud] Resolved UID by phone: $resolvedUid, existingPhoto: $existingProfilePhoto");
        }
      }
    }

    FirestoreService().setResolvedUid(resolvedUid);

    // Preserve the existing database profile photo if one is already uploaded/set
    final photoToSave = (existingProfilePhoto != null && existingProfilePhoto.isNotEmpty)
        ? existingProfilePhoto
        : profilePhoto;

    await _userRepository.saveUserDocument(
      uid: resolvedUid,
      name: name,
      email: email ?? 'user@example.com',
      phone: phone != null ? _normalizePhone(phone) : null,
      profilePhoto: photoToSave,
      provider: provider,
    );
  }

  /// Updates profile in Cloud Firestore, uploading the local profile image to Firebase Storage first if needed
  Future<void> updateProfile({
    required String name,
    required String phone,
    required String email,
    String? profileImagePath,
  }) async {
    final currentUid = FirestoreService().currentUid;
    
    // Check if email already exists for a different user
    if (email.trim().isNotEmpty) {
      final normalizedEmail = _normalizeEmail(email);
      final existingUserByEmail = await _userRepository.resolveUserDocument(email: normalizedEmail);
      if (existingUserByEmail != null) {
        final existingUid = (existingUserByEmail['uid'] ?? existingUserByEmail['id'])?.toString();
        if (existingUid != null && existingUid != currentUid) {
          throw Exception("This email address is already registered with another account.");
        }
      }
    }

    // Check if phone number already exists for a different user
    if (phone.trim().isNotEmpty) {
      final normalizedPhone = _normalizePhone(phone);
      final existingUserByPhone = await _userRepository.resolveUserDocument(phone: normalizedPhone);
      if (existingUserByPhone != null) {
        final existingUid = (existingUserByPhone['uid'] ?? existingUserByPhone['id'])?.toString();
        if (existingUid != null && existingUid != currentUid) {
          throw Exception("This phone number is already registered with another account.");
        }
      }
    }

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

    // Trigger upload and Firestore sync
    await _syncProfileToCloudInBackground(
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
      // 1. Delete old profile image if it exists and is a remote URL
      if (_profileImagePath != null && _profileImagePath!.startsWith('http')) {
        print("Deleting old profile image: $_profileImagePath");
        try {
          await _storageService.deleteFile(_profileImagePath!);
          print("Old profile image deleted successfully");
        } catch (e) {
          print("Failed to delete old profile image: $e");
          // Continue with upload even if delete fails
        }
      }

      // 2. Upload file if it's a local file
      if (localImagePath != null && !localImagePath.startsWith('http') && File(localImagePath).existsSync()) {
        print("Uploading profile image from: $localImagePath");
        finalImageUrl = await _storageService.uploadFile(
          file: File(localImagePath),
          folder: 'uploads',
          customFileName: 'profile_picture_${DateTime.now().millisecondsSinceEpoch}',
        );
        print("Profile image uploaded to: $finalImageUrl");

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
      final normalizedPhone = _normalizePhone(phone);

      // Save profile details to MySQL backend
      await _userRepository.saveUserDocument(
        uid: currentResolvedUid,
        name: name,
        email: email,
        phone: normalizedPhone,
        profilePhoto: finalImageUrl,
        provider: _auth.currentUser?.providerData.isNotEmpty == true 
            ? _auth.currentUser!.providerData.first.providerId 
            : 'google',
      );

      print("Profile successfully synced to backend.");
    } catch (e) {
      print("Error syncing profile to backend: $e");
      rethrow;
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
    FirestoreService().clearResolvedUid();
    notifyListeners();
  }

  Future<void> logout() async {
    _clearInMemoryState();
    await _auth.signOut();
  }

  Future<void> checkUserStatusSilently() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final resolvedUid = FirestoreService().resolvedUid;
      if (resolvedUid == null) return;

      final userDoc = await _userRepository.fetchUserDocument(resolvedUid);
      if (userDoc != null) {
        final rawStatus = userDoc['accountStatus'] ?? userDoc['status'];
        String newStatus = 'active';
        if (rawStatus != null) {
          newStatus = rawStatus.toString().toLowerCase() == 'suspended' ? 'suspended' : 'active';
        } else if (userDoc['isBlocked'] == true) {
          newStatus = 'suspended';
        }

        if (newStatus != _accountStatus) {
          _accountStatus = newStatus;
          notifyListeners();
        }
      }
    } catch (e) {
      print("Error in silent user status check: $e");
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
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
