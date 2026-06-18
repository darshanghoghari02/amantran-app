import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _token;
  bool _isProfileCompletePersisted = false;
  late final Future<void> initialization;

  final List<AccountModel> _recentAccounts = []; // Empty or memory-only list to satisfy layout interfaces

  UserProvider() {
    initialization = _init();
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
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  bool get isProfileComplete {
    if (_isProfileCompletePersisted) return true;
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
    
    // Profile is complete if user has name, email, and phone number
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


  Future<String> _resolveUid(User user) async {
    try {
      print("[_resolveUid] Resolving user: UID=${user.uid}, email=${user.email}, phone=${user.phoneNumber}");
      
      if (user.email != null && user.email!.isNotEmpty) {
        final email = _normalizeEmail(user.email!);
        print("[_resolveUid] Querying by email: $email");
        final matchedUser = await _userRepository.resolveUserDocument(email: email);
        if (matchedUser != null) {
          final resolvedId = matchedUser['id'] ?? matchedUser['uid'];
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
          final resolvedId = matchedUser['id'] ?? matchedUser['uid'];
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
    _isProfileCompletePersisted = await _getStoredProfileComplete();

    // If a token is saved, initialize in-memory state with the most recent account as a cache
    final token = await getAuthToken();
    _token = token;
    if (token != null && token.isNotEmpty && _recentAccounts.isNotEmpty) {
      final cachedAccount = _recentAccounts.first;
      _name = cachedAccount.name;
      _phone = cachedAccount.phone;
      _email = cachedAccount.email;
      _profileImagePath = cachedAccount.profileImagePath;
      print("💾 [UserProvider] Initialized from cached account: $_name, $_phone");
    }

    // Restore stored phone if currently empty (handles cold start before profile completion)
    if (_phone.isEmpty) {
      final storedPhone = await _getStoredPhone();
      if (storedPhone != null && storedPhone.isNotEmpty) {
        _phone = storedPhone;
        print("💾 [UserProvider] Pre-initialized phone from SharedPreferences: $_phone");
      }
    }
    notifyListeners();

    // Listen to Firebase Auth state changes
    User? previousUser;
    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        previousUser = user;
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
        final hadFirebaseUser = previousUser != null;
        previousUser = null;

        // Only clear in-memory state if we were previously logged in via Firebase and now logged out,
        // and we don't have a JWT token.
        if (hadFirebaseUser && (_token == null || _token!.isEmpty)) {
          _clearInMemoryState();
        }
      }
    });
  }

  /// Fetches the user profile from Cloud / MySQL backend
  Future<void> fetchProfileFromCloud({String? phone, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
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
            resolvedUid = (matchedUser['id'] ?? matchedUser['uid'])?.toString();
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
            resolvedUid = (matchedUser['id'] ?? matchedUser['uid'])?.toString();
          } else {
            final phoneDigits = normalized.replaceAll(RegExp(r'\D'), '');
            resolvedUid = 'whatsapp_$phoneDigits';
          }
        }
      }

      // Last-resort fallback: read persisted backend user ID from SharedPreferences
      // This handles hot-restart when Firebase Auth is null and resolvedUid is not in memory
      if (resolvedUid == null) {
        resolvedUid = await _getStoredUserId();
        if (resolvedUid != null) {
          print("[fetchProfileFromCloud] Recovered resolvedUid from SharedPreferences: $resolvedUid");
        }
      }

      // Ultimate fallback: try resolving by stored phone number
      if (resolvedUid == null) {
        final storedPhone = await _getStoredPhone();
        if (storedPhone != null && storedPhone.isNotEmpty) {
          print("[fetchProfileFromCloud] Trying to resolve UID by stored phone: $storedPhone");
          final matchedUser = await _userRepository.resolveUserDocument(phone: storedPhone);
          if (matchedUser != null) {
            resolvedUid = (matchedUser['id'] ?? matchedUser['uid'])?.toString();
            print("[fetchProfileFromCloud] Resolved UID by stored phone: $resolvedUid");
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

        // Store resolved UID in SharedPreferences persistently so we don't have to resolve it again
        await _storeUserId(resolvedUid);

        // Store profile complete status in SharedPreferences
        if (isProfileComplete) {
          _isProfileCompletePersisted = true;
          await _storeProfileComplete(true);
        }

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
        // Document doesn't exist on backend (404 Not Found).
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
            
            // Resolve newly created user integer ID!
            final matchedUser = await _userRepository.resolveUserDocument(email: _normalizeEmail(_email));
            if (matchedUser != null && matchedUser['id'] != null) {
              final newId = matchedUser['id'].toString();
              FirestoreService().setResolvedUid(newId);
              await _storeUserId(newId);
            } else {
              await _storeUserId(resolvedUid);
            }
            
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
        } else {
          // NO Firebase user, NO phone, and NO backend document found -> Stale JWT session!
          print("❌ [UserProvider] Stale JWT session detected (404 not found on backend). Logging out.");
          await logout();
        }
      }
    } catch (e) {
      print("⚠️ [UserProvider] Network or server error fetching profile: $e. Using local cached details.");
      // Do not log out! The session is still valid but the network is offline or server is down.
    } finally {
      if (!silent) {
        _isLoading = false;
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

    if (phone.isNotEmpty) {
      await storeUserPhone(phone);
    }

    if (isProfileComplete) {
      _isProfileCompletePersisted = true;
      await _storeProfileComplete(true);
    }

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

      // Now query the backend to resolve the newly created/updated user record and get their integer ID!
      final matchedUser = await _userRepository.resolveUserDocument(phone: normalizedPhone);
      if (matchedUser != null && matchedUser['id'] != null) {
        final newId = matchedUser['id'].toString();
        print("[_syncProfileToCloudInBackground] Resolved newly saved user integer ID: $newId");
        FirestoreService().setResolvedUid(newId);
        await _storeUserId(newId);
      } else {
        await _storeUserId(currentResolvedUid);
      }

      if (isProfileComplete) {
        _isProfileCompletePersisted = true;
        await _storeProfileComplete(true);
      }

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
    _isProfileCompletePersisted = false;
    FirestoreService().clearResolvedUid();
    notifyListeners();
  }


  Future<void> checkUserStatusSilently() async {
    final user = _auth.currentUser;
    final hasJwt = isAuthenticated;
    if (user == null && !hasJwt) return;

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

  // --- JWT TOKEN MANAGEMENT ---
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'backend_user_id';
  static const String _userPhoneKey = 'backend_user_phone';
  static const String _isProfileCompleteKey = 'is_profile_complete';

  Future<void> _storeProfileComplete(bool complete) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isProfileCompleteKey, complete);
    } catch (e) {
      print("Error storing profile completion state: $e");
    }
  }

  Future<bool> _getStoredProfileComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isProfileCompleteKey) ?? false;
    } catch (e) {
      print("Error getting stored profile completion state: $e");
      return false;
    }
  }

  Future<bool> getStoredProfileCompleteState() => _getStoredProfileComplete();

  /// Store backend user ID persistently
  Future<void> _storeUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
    } catch (e) {
      print("❌ [UserProvider] Error storing user ID: $e");
    }
  }

  /// Get stored backend user ID
  Future<String?> _getStoredUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      print("❌ [UserProvider] Error getting stored user ID: $e");
      return null;
    }
  }

  /// Store phone number persistently so login survives app restart
  Future<void> storeUserPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPhoneKey, phone);
      print("✅ [UserProvider] Phone stored: $phone");
    } catch (e) {
      print("❌ [UserProvider] Error storing phone: $e");
    }
  }

  /// Get stored phone number
  Future<String?> _getStoredPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userPhoneKey);
    } catch (e) {
      print("❌ [UserProvider] Error getting stored phone: $e");
      return null;
    }
  }

  /// Store JWT token from backend
  Future<void> setAuthToken(String token) async {
    try {
      _token = token;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authTokenKey, token);
      print("✅ [UserProvider] JWT token stored successfully: ${token.substring(0, 20)}...");
    } catch (e) {
      print("❌ [UserProvider] Error storing JWT token: $e");
    }
  }

  /// Get stored JWT token
  Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_authTokenKey);
      print("🔍 [UserProvider] Retrieved JWT token: ${token != null ? 'Found (${token.substring(0, 20)}...)' : 'Not found'}");
      return token;
    } catch (e) {
      print("❌ [UserProvider] Error getting JWT token: $e");
      return null;
    }
  }

  /// Clear JWT token, stored user ID and phone
  Future<void> clearAuthToken() async {
    try {
      _token = null;
      _isProfileCompletePersisted = false;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_userPhoneKey);
      await prefs.remove(_isProfileCompleteKey);
      print("✅ [UserProvider] JWT token, user ID, phone & profile complete flag cleared successfully");
    } catch (e) {
      print("❌ [UserProvider] Error clearing JWT token: $e");
    }
  }

  /// Update user data from backend response
  Future<void> updateUserFromBackend(Map<String, dynamic> userData) async {
    try {
      _name = userData['name'] ?? userData['displayName'] ?? '';
      _email = userData['email'] ?? '';
      _profileImagePath = userData['profilePhoto'] ?? userData['profile_image'];
      _phone = userData['phone'] ?? '';
      _role = userData['role'] ?? 'user';
      
      final rawStatus = userData['accountStatus'] ?? userData['status'];
      if (rawStatus != null) {
        _accountStatus = rawStatus.toString().toLowerCase() == 'suspended' ? 'suspended' : 'active';
      } else if (userData['isBlocked'] == true) {
        _accountStatus = 'suspended';
      } else {
        _accountStatus = 'active';
      }

      // Store resolved UID if provided — also persist to SharedPreferences for hot-restart recovery
      final resolvedId = userData['id'] ?? userData['uid'];
      if (resolvedId != null) {
        final uid = resolvedId.toString();
        FirestoreService().setResolvedUid(uid);
        await _storeUserId(uid);
      }

      // Persist phone number for app-restart recovery
      if (_phone.isNotEmpty) {
        await storeUserPhone(_phone);
      }

      // Store profile complete status in SharedPreferences
      if (isProfileComplete) {
        _isProfileCompletePersisted = true;
        await _storeProfileComplete(true);
      }

      // Add to recent accounts
      if (_name.isNotEmpty) {
        _addToRecentAccounts(AccountModel(
          name: _name,
          phone: _phone,
          email: _email,
          profileImagePath: _profileImagePath,
        ));
      }

      notifyListeners();
      print("User data updated from backend successfully");
    } catch (e) {
      print("Error updating user data from backend: $e");
    }
  }

  Future<void> logout() async {
    await clearAuthToken();
    _clearInMemoryState();
    await _auth.signOut();
  }
}
