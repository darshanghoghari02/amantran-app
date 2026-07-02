import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/language_model.dart';
import '../repositories/user_repository.dart';
import '../services/interaction_service.dart';
import '../services/firestore_service.dart';
import '../services/language_registry.dart';
import '../models/guest_model.dart';

/// Holds all translated UI strings for the app.
/// When the language changes, all widgets listening to this provider rebuild instantly.
class LanguageProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _keyAppLang = 'app_language';
  static const String _keyInvLang = 'invitation_language';
  static const String _keyInvLangsList = 'invitation_languages_list';

  final UserRepository _userRepository = UserRepository();
  StreamSubscription? _authSubscription;
  bool _hiveLoaded = false;

  String _currentLanguage = 'English';
  String get currentLanguage => _currentLanguage;

  String get nativeLanguageName {
    switch (_currentLanguage) {
      case 'Gujarati':
        return 'ગુજરાતી';
      case 'Hindi':
        return 'हिन्दी';
      case 'Marathi':
        return 'मराठी';
      case 'Punjabi':
        return 'ਪੰਜਾਬੀ';
      case 'Urdu':
        return 'اردو';
      default:
        return 'English';
    }
  }

  Set<String> _invitationLanguages = {
    'Gujarati',
    'Hindi',
    'Marathi',
    'Punjabi',
    'Urdu',
    'English'
  };
  Set<String> get invitationLanguages => _invitationLanguages;

  String _activeInvitationLanguage = 'Gujarati';
  String get activeInvitationLanguage => _activeInvitationLanguage;
  bool _invitationLangUserSet = false;

  LanguageProvider() {
    _loadFromHive();
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = FirestoreService().resolvedUidStream.listen((uid) async {
      if (uid != null) {
        await _loadFromFirestore();
      }
    });

    final initialUid = FirestoreService().resolvedUid;
    if (initialUid != null) {
      _loadFromFirestore();
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      final settings = await _userRepository.fetchSettings();
      if (settings != null) {
        _currentLanguage = settings[_keyAppLang] ?? _currentLanguage;
        if (!_invitationLangUserSet) {
          _activeInvitationLanguage =
              settings[_keyInvLang] ?? _activeInvitationLanguage;
        }
        final List<dynamic>? savedLangs = settings[_keyInvLangsList];
        if (savedLangs != null && savedLangs.isNotEmpty) {
          _invitationLanguages = Set<String>.from(savedLangs.cast<String>());
        }
        
        // Keep Hive locally in sync with loaded cloud settings
        await _saveToHive(_keyAppLang, _currentLanguage);
        await _saveToHive(_keyInvLang, _activeInvitationLanguage);
        await _saveToHive(_keyInvLangsList, _invitationLanguages.toList());
        
        notifyListeners();
      }
    } catch (e) {
      print("Failed to load settings from Firestore: $e");
    }
  }

  Future<void> _saveSettingsToCloud() async {
    if (!_hiveLoaded) return; // Block saving default values if Hive has not loaded yet
    if (FirestoreService().resolvedUid != null) {
      try {
        await _userRepository.saveSettings({
          _keyAppLang: _currentLanguage,
          _keyInvLang: _activeInvitationLanguage,
          _keyInvLangsList: _invitationLanguages.toList(),
        });
      } catch (e) {
        print("Failed to save settings to Firestore: $e");
      }
    }
  }

  Future<void> _loadFromHive() async {
    final box = await Hive.openBox(_boxName);
    _currentLanguage = box.get(_keyAppLang, defaultValue: 'English');
    if (!_invitationLangUserSet) {
      _activeInvitationLanguage =
          box.get(_keyInvLang, defaultValue: 'Gujarati');
    }
    final List<dynamic>? savedLangs = box.get(_keyInvLangsList);
    if (savedLangs != null && savedLangs.isNotEmpty) {
      _invitationLanguages = Set<String>.from(savedLangs.cast<String>());
    }
    _hiveLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToHive(String key, dynamic value) async {
    try {
      final box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      await box.put(key, value);
    } catch (e) {
      print("Error saving to Hive box $_boxName: $e");
    }
  }

  void setLanguage(String lang) {
    if (_currentLanguage == lang) return;
    _currentLanguage = lang;
    _saveToHive(_keyAppLang, lang);
    _saveSettingsToCloud();
    InteractionService.logInteraction(
      type: 'change_app_language',
      description: 'Changed application UI language to $lang',
      details: {'language': lang},
    );
    notifyListeners();
  }

  void reconcileWithBackend(List<LanguageModel> backendLanguages) {
    LanguageRegistry.instance.updateFromBackend(backendLanguages);
    final available = LanguageRegistry.instance.languageNames;
    if (available.isEmpty) return;

    final filtered =
        _invitationLanguages.where((l) => available.contains(l)).toSet();
    final newInvLangs = filtered.isNotEmpty ? filtered : available;

    bool changed = false;

    // Check if invitation languages list changed
    if (_invitationLanguages.length != newInvLangs.length ||
        !_invitationLanguages.every(newInvLangs.contains)) {
      _invitationLanguages = newInvLangs;
      changed = true;
    }

    // Check if active invitation language needs correction
    if (!_invitationLanguages.contains(_activeInvitationLanguage)) {
      _activeInvitationLanguage = _invitationLanguages.contains('Gujarati')
          ? 'Gujarati'
          : _invitationLanguages.first;
      _saveToHive(_keyInvLang, _activeInvitationLanguage);
      changed = true;
    }

    if (changed) {
      _saveToHive(_keyInvLangsList, _invitationLanguages.toList());
      _saveSettingsToCloud();
      notifyListeners();
    }
  }

  void setInvitationLanguages(Set<String> langs) {
    final available = LanguageRegistry.instance.languageNames;
    final targetLangs = available.isEmpty
        ? langs
        : langs.where((l) => available.contains(l)).toSet();
    final newInvLangs = targetLangs.isEmpty && available.isNotEmpty
        ? available
        : targetLangs;

    // Check if invitation languages list changed
    if (_invitationLanguages.length == newInvLangs.length &&
        _invitationLanguages.every(newInvLangs.contains)) {
      return; // No change!
    }

    _invitationLanguages = newInvLangs;
    _saveToHive(_keyInvLangsList, _invitationLanguages.toList());
    _saveSettingsToCloud();
    notifyListeners();
  }

  void setActiveInvitationLanguage(String lang) {
    if (_activeInvitationLanguage == lang && _invitationLangUserSet) return;
    _invitationLangUserSet = true;
    _activeInvitationLanguage = lang;
    _saveToHive(_keyInvLang, lang);
    _saveSettingsToCloud();
    notifyListeners();
  }

  // Helper setter for activeInvitationLanguage
  set activeInvitationLanguage(String lang) {
    setActiveInvitationLanguage(lang);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // 🌐 TRANSLATED STRINGS
  // ─────────────────────────────────────────────────────────────

  String _t(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations['English'] ?? '';
  }

  String _tFor(Map<String, String> translations, String lang) {
    return translations[lang] ?? translations['English'] ?? '';
  }

  String getCategoryTranslation(String rawName) {
    final lower = rawName.toLowerCase().trim();
    if (lower == 'wedding') {
      return _t({
        'English': 'Wedding',
        'Gujarati': 'લગ્ન',
        'Hindi': 'शादी',
        'Marathi': 'लग्न',
        'Punjabi': 'ਵਿਆਹ',
        'Urdu': 'شادی',
      });
    } else if (lower == 'engagement') {
      return _t({
        'English': 'Engagement',
        'Gujarati': 'સગાઈ',
        'Hindi': 'सगाई',
        'Marathi': 'साखरपुडा',
        'Punjabi': 'ਮੰਗਣੀ',
        'Urdu': 'منگنی',
      });
    } else if (lower == 'baby shower' || lower.contains('baby')) {
      return _t({
        'English': 'Baby Shower',
        'Gujarati': 'બેબી શાવર',
        'Hindi': 'बेबी शावर',
        'Marathi': 'बेबी शॉवर',
        'Punjabi': 'ਬੇਬੀ ਸ਼ਾਵਰ',
        'Urdu': 'بیبی شاور',
      });
    }
    return rawName;
  }

  String get appTitle => _t({
        'English': 'Invitation Card Maker',
        'Gujarati': 'આમંત્રણ કાર્ડ મેકર',
        'Hindi': 'निमंत्रण कार्ड मेकर',
        'Marathi': 'निमंत्रण कार्ड मेकर',
        'Punjabi': 'ਸੱਦਾ ਕਾਰਡ ਮੇਕਰ',
        'Urdu': 'دعوت نامہ کارڈ میکر',
      });

  String hello(String name) => _t({
        'English': 'Hello, $name! 👋',
        'Gujarati': 'નમસ્તે, $name! 👋',
        'Hindi': 'नमस्ते, $name! 👋',
        'Marathi': 'नमस्कार, $name! 👋',
        'Punjabi': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ, $name! 👋',
        'Urdu': '!👋 السلام علیکم، $name',
      });

 String get subtitle => _t({
        'English': 'Get your perfect template.',
        'Gujarati': 'તમારું પરફેક્ટ ટેમ્પલેટ મેળવો.',
        'Hindi': 'अपना परफेक्ट टेम्पलेट प्राप्त करें।',
        'Marathi': 'तुमचे परफेक्ट टेम्पलेट मिळवा.',
        'Punjabi': 'ਆਪਣਾ ਪਰਫੈਕਟ ਟੈਂਪਲੇਟ ਪ੍ਰਾਪਤ ਕਰੋ।',
        'Urdu': 'اپنا پرفیکٹ ٹیمپلیٹ حاصل کریں۔',
      });

  String get searchHint => _t({
        'English': 'Search templates....',
        'Gujarati': 'ટેમ્પ્લેટ શોધો....',
        'Hindi': 'टेम्पलेट खोजें....',
        'Marathi': 'टेम्पलेट शोधा....',
        'Punjabi': 'ਟੈਂਪਲੇਟ ਲੱਭੋ....',
        'Urdu': '....ٹیمپلیٹ تلاش کریں',
      });

  String get weddingInvitation => _t({
        'English': 'Wedding Invitation',
        'Gujarati': 'લગ્ન આમંત્રણ',
        'Hindi': 'शादी का निमंत्रण',
        'Marathi': 'लग्न निमंत्रण',
        'Punjabi': 'ਵਿਆਹ ਦਾ ਸੱਦਾ',
        'Urdu': 'شادی کا دعوت نامہ',
      });

  String get engagementInvitation => _t({
        'English': 'Engagement Invitation',
        'Gujarati': 'સગાઈ આમંત્રણ',
        'Hindi': 'सगाई का निमंत्रण',
        'Marathi': 'साखरपुडा निमंत्रण',
        'Punjabi': 'ਮੰਗਣੀ ਦਾ ਸੱਦਾ',
        'Urdu': 'منگنی کا دعوت نامہ',
      });

  String get babyShower => _t({
        'English': 'Baby Shower',
        'Gujarati': 'બેબી શાવર',
        'Hindi': 'बेबी शावर',
        'Marathi': 'बेबी शॉवर',
        'Punjabi': 'ਬੇਬੀ ਸ਼ਾਵਰ',
        'Urdu': 'بیبی شاور',
      });

  String get seeAll => _t({
        'English': 'See All',
        'Gujarati': 'બધા જુઓ',
        'Hindi': 'सभी देखें',
        'Marathi': 'सर्व पहा',
        'Punjabi': 'ਸਭ ਵੇਖੋ',
        'Urdu': 'سب دیکھیں',
      });

  String get home => _t({
        'English': 'Home',
        'Gujarati': 'હોમ',
        'Hindi': 'होम',
        'Marathi': 'होम',
        'Punjabi': 'ਹੋਮ',
        'Urdu': 'Û ÙˆÙ…',
      });

  String get yourDesign => _t({
        'English': 'Your Design',
        'Gujarati': 'તમારી ડિઝાઇન',
        'Hindi': 'आपकी डिझाइन',
        'Marathi': 'तुमची डिझाइन',
        'Punjabi': 'ਤੁਹਾਡੀ ਡਿਜ਼ਾਈਨ',
        'Urdu': 'آپ کا ڈیزائن',
      });

  String get favorites => _t({
        'English': 'Favorites',
        'Gujarati': 'પસંદગીનું',
        'Hindi': 'पसंदीदा',
        'Marathi': 'आवडते',
        'Punjabi': 'ਮਨਪਸੰਦ',
        'Urdu': 'پسندیدہ',
      });

  String get guests => _t({
        'English': 'Guests',
        'Gujarati': 'મહેમાનો',
        'Hindi': 'अतिथि',
        'Marathi': 'पाहुणे',
        'Punjabi': 'ਮਹਿਮਾਨ',
        'Urdu': 'مہمان',
      });

  String get drafts => _t({
        'English': 'Drafts',
        'Gujarati': 'ડ્રાફ્ટ',
        'Hindi': 'ड्राफ्ट',
        'Marathi': 'मसुदा',
        'Punjabi': 'ਡਰਾਫਟ',
        'Urdu': 'ڈرافٹ',
      });

  String get yourDesigns => _t({
        'English': 'Your Designs',
        'Gujarati': 'તમારી ડિઝાઇન',
        'Hindi': 'आपकी डिझाइन',
        'Marathi': 'तुमची डिझाइन',
        'Punjabi': 'ਤੁਹਾਡੀ ਡਿਜ਼ਾਈਨ',
        'Urdu': 'آپ کے ڈیزائن',
      });

  String get appLanguage => _t({
        'English': 'App Language',
        'Gujarati': 'એપ ભાષા',
        'Hindi': 'ऐप भाषा',
        'Marathi': 'ऐप भाषा',
        'Punjabi': 'ਐਪ ਭਾਸ਼ਾ',
        'Urdu': 'ایپ زبان',
      });

  String get invitationLanguage => _t({
        'English': 'Invitation Language',
        'Gujarati': 'આમંત્રણ ભાષા',
        'Hindi': 'निमंत्रण भाषा',
        'Marathi': 'निमंत्रण भाषा',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾ',
        'Urdu': 'دعوت نامہ زبان',
      });

  String get rateUs => _t({
        'English': 'Rate Us',
        'Gujarati': 'અમને રેટ કરો',
        'Hindi': 'हमें रेट करें',
        'Marathi': 'आम्हाला रेट करा',
        'Punjabi': 'ਸਾਨੂੰ ਰੇਟ ਕਰੋ',
        'Urdu': 'ہمیں ریٹ کریں',
      });

  String get shareApp => _t({
        'English': 'Share App',
        'Gujarati': 'એપ શેર કરો',
        'Hindi': 'ऐप शेयर करें',
        'Marathi': 'ऐप शेयर करा',
        'Punjabi': 'ਐਪ ਸਾਂਝੀ ਕਰੋ',
        'Urdu': 'ایپ شیئر کریں',
      });

  String get termsConditions => _t({
        'English': 'Terms Conditions',
        'Gujarati': 'નિયમો અને શરતો',
        'Hindi': 'नियम और शर्तें',
        'Marathi': 'अटी व शर्ती',
        'Punjabi': 'ਨਿਯਮ ਅਤੇ ਸ਼ਰਤਾਂ',
        'Urdu': 'شرائط و ضوابط',
      });

  String get privacyPolicy => _t({
        'English': 'Privacy Policy',
        'Gujarati': 'ગોપનીયતા નીતિ',
        'Hindi': 'गोपनीयता नीति',
        'Marathi': 'गोपनीयता धोरण',
        'Punjabi': 'ਗੋਪਨੀਯਤਾ ਨੀਤੀ',
        'Urdu': 'رازداری کی پالیسی',
      });

  String get signOut => _t({
        'English': 'Sign Out',
        'Gujarati': 'સાઇન આઉટ',
        'Hindi': 'साइन आउट',
        'Marathi': 'साइन आउट',
        'Punjabi': 'ਸਾਈਨ ਆਊਟ',
        'Urdu': 'سائن آؤٹ',
      });

  String get apply => _t({
        'English': 'Apply',
        'Gujarati': 'લાગુ કરો',
        'Hindi': 'लागू करें',
        'Marathi': 'लागू करा',
        'Punjabi': 'ਲਾਗੂ ਕਰੋ',
        'Urdu': 'لاگو کریں',
      });

  String get noFavoritesYet => _t({
        'English': 'No favorites yet',
        'Gujarati': 'હજુ સુધી કોઈ પસંદગી નથી',
        'Hindi': 'अभी तक कोई पसंदीदा नहीं',
        'Marathi': 'अजून कोणतेही आवडते नाही',
        'Punjabi': 'ਅਜੇ ਕੋਈ ਮਨਪਸੰਦ ਨਹੀਂ',
        'Urdu': 'ابھی تک کوئی پسندیدہ نہیں',
      });

  String get noDraftsYet => _t({
        'English': 'No drafts yet. Start designing!',
        'Gujarati': 'હજુ સુધી કોઈ ડ્રાફ્ટ નથી. ડિઝાઇન શરૂ કરો!',
        'Hindi': 'अभी तक कोई ड्राफ्ट नहीं. डिझाइन शरू करें!',
        'Marathi': 'अजून कोणताही मसुदा नाही. डिझाइन सुरू करा!',
        'Punjabi': 'ਅਜੇ ਕੋਈ ਡਰਾਫਟ ਨਹੀਂ। ਡਿਜ਼ਾਈਨ ਸ਼ੁਰੂ ਕਰੋ!',
        'Urdu': 'ابھی تک کوئی ڈرافٹ نہیں، ڈیزائن شروع کریں!',
      });

  String get selected => _t({
        'English': 'Selected',
        'Gujarati': 'પસંદ કરેલ',
        'Hindi': 'चयनित',
        'Marathi': 'निवडले',
        'Punjabi': 'ਚੁਣਿਆ',
        'Urdu': 'منتخب',
      });

  String get changeAppLanguage => _t({
        'English': 'Change App Language',
        'Gujarati': 'એપ ભાષા બદલો',
        'Hindi': 'ऐप भाषा बदलें',
        'Marathi': 'ऐप भाषा बदला',
        'Punjabi': 'ਐਪ ਭਾਸ਼ਾ ਬਦલો',
        'Urdu': 'ایپ کی زبان تبدیل کریں',
      });

  String get selectInvitationLanguages => _t({
        'English': 'Select Invitation Languages',
        'Gujarati': 'આમંત્રણ ભાષાઓ પસંદ કરો',
        'Hindi': 'निमंत्रण भाषाएं चुनें',
        'Marathi': 'निमंत्रण भाषा निवडा',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾਵਾਂ ਚੁਣੋ',
        'Urdu': 'دعوت نامہ کی زبانیں منتخب کریں',
      });

  String get yourProfile => _t({
        'English': 'Your Profile',
        'Gujarati': 'તમારી પ્રોફાઇલ',
        'Hindi': 'आपकी प्रोफाइल',
        'Marathi': 'तुमची प्रोफाइल',
        'Punjabi': 'ਤੁਹਾਡੀ ਪ੍ਰੋਫਾਈਲ',
        'Urdu': 'آپ کی پروفائل',
      });

  String get personalInformation => _t({
        'English': 'Personal Information',
        'Gujarati': 'વ્યક્તિગત માહિતી',
        'Hindi': 'व्यक्तिगत जानकारी',
        'Marathi': 'वैयक्तिक माहिती',
        'Punjabi': 'ਨਿੱજી ਜਾਣਕਾਰੀ',
        'Urdu': 'ذاتی معلومات',
      });

  String get fullName => _t({
        'English': 'Full Name',
        'Gujarati': 'આખું નામ',
        'Hindi': 'पूरा नाम',
        'Marathi': 'पूर्ण नाव',
        'Punjabi': 'ਪੂਰਾ ਨਾਮ',
        'Urdu': 'پورا نام',
      });

  String get phoneNumber => _t({
        'English': 'Phone Number',
        'Gujarati': 'ફોન નંબર',
        'Hindi': 'फ़ोन नंबर',
        'Marathi': 'फोन नंबर',
        'Punjabi': 'ਫ਼ੋਨ ਨੰਬਰ',
        'Urdu': 'فون نمبر',
      });

  String get updateProfile => _t({
        'English': 'Update Profile',
        'Gujarati': 'પ્રોફાઇલ અપડેટ કરો',
        'Hindi': 'प्रोफाइल अपडेट करें',
        'Marathi': 'प्रोफाइल अपडेट करा',
        'Punjabi': 'ਪ੍ਰੋਫਾਈਲ ਅਪਡੇਟ ਕਰੋ',
        'Urdu': 'پروفائل اپ ڈیٹ کریں',
      });

  String get change => _t({
        'English': 'change',
        'Gujarati': 'બદલો',
        'Hindi': 'बदलें',
        'Marathi': 'बदला',
        'Punjabi': 'ਬਦਲੋ',
        'Urdu': 'تبدیل کریں',
      });

  String get email => _t({
        'English': 'Email',
        'Gujarati': 'ઈમેલ',
        'Hindi': 'ईमेल',
        'Marathi': 'ईमेल',
        'Punjabi': 'ਈਮੇਲ',
        'Urdu': 'ای میل',
      });

  String get profileUpdated => _t({
        'English': 'Profile updated successfully!',
        'Gujarati': 'પ્રોફાઇલ સફળતાપૂર્વક અપડેટ થઈ!',
        'Hindi': 'प्रोफ़ाइल सफलतापूर्वक अपडेट की गई!',
        'Marathi': 'प्रोफाइल यशस्वीरित्या अपडेट झाली!',
        'Punjabi': 'ਪ੍ਰੋਫਾਈਲ ਸਫਲਤਾਪੂਰਵਕ ਅਪਡੇਟ ਕੀਤੀ ਗਈ!',
        'Urdu': 'پروفائل کامیابی کے ساتھ اپ ڈیٹ ہوگئی!',
      });

  // ─────────────────────────────────────────────────────────────
  // 🔧 TEMPLATE LABELS
  // ─────────────────────────────────────────────────────────────

  String get customizeTemplate => _t({
        'English': 'Customize This Template',
        'Gujarati': 'આ ટેમ્પ્લેટ કસ્ટમાઇઝ કરો',
        'Hindi': 'इस टेम्पलेट को कस्टमाइझ करें',
        'Marathi': 'हे टेम्पलेट सानुकूलित करा',
        'Punjabi': 'ਇਸ ਟੈਂਪਲੇਟ ਨੂੰ ਅਨੁਕੂਲਿਤ ਕਰੋ',
        'Urdu': 'اس ٹیمپلیٹ کو اپنی مرضی کے مطابق بنائیں',
      });

  String get features => _t({
        'English': 'Features:',
        'Gujarati': 'વિશેષતાઓ:',
        'Hindi': 'विशेषताएं:',
        'Marathi': 'वैशिष्ट्ये:',
        'Punjabi': 'ਵਿਸ਼ੇਸ਼ਤਾਵਾਂ:',
        'Urdu': 'خصوصیات:',
      });

  String get feature1 => _t({
        'English': 'Edit text in seconds',
        'Gujarati': 'સેકન્ડોમાં ટેક્સ્ટ સંપાદિત કરો',
        'Hindi': 'सेकंडों में टेक्स्ट एडिट करें',
        'Marathi': 'काही सेकंदात मजकूर संपादित करा',
        'Punjabi': 'ਸਕਿੰਟਾਂ ਵਿੱਚ ਟੈਕਸਟ ਨੂੰ ਸੰਪਾਦਿਤ ਕਰੋ',
        'Urdu': 'سیکنڈوں میں متن میں ترمیم کریں',
      });

  String get feature2 => _t({
        'English': 'Download high-quality invitation',
        'Gujarati': 'ઉચ્ચ-ગુણવત્તાનું આમંત્રણ ડાઉનલોડ કરો',
        'Hindi': 'उच्च गुणवत्ता वाला निमंत्रण डाउनलोड करें',
        'Marathi': 'उच्च-गुणवत्तेचे निमंत्रण डाउनलोड करा',
        'Punjabi': 'ਉੱਚ-ਗੁਣਵੱਤਾ ਵਾਲਾ ਸੱਦਾ ਪੱਤਰ ਡਾਊਨਲੋਡ ਕਰੋ',
        'Urdu': 'اعلیٰ معیار کا دعوت نامہ ڈاؤن لوڈ کریں',
      });

  String get feature3 => _t({
        'English': 'Perfect for WhatsApp sharing',
        'Gujarati': 'વોટ્સએપ શેરિંગ માટે યોગ્ય',
        'Hindi': 'व्हाट्सएप शेरिंग के लिए बिलकुल सही',
        'Marathi': 'व्हॉट्सऐप शेयरिंगसाठी योग्य',
        'Punjabi': 'ਵਟਸਐਪ ਸ਼ੇਅਰਿੰਗ ਲਈ ਸੰਪੂਰਨ',
        'Urdu': 'واٹس ایپ شیئرنگ کے لیے بہترین',
      });

  String get templateDescription => _t({
        'English': 'Celebrate your special day with a touch of tradition!',
        'Gujarati': 'પરંપરાના સ્પર્શ સાથે તમારા ખાસ દિવસની ઉજવણી કરો!',
        'Hindi': 'परंपरा के स्पर्श के साथ अपने विशेष दिन का जश्न मनाएं!',
        'Marathi': 'परंपरेच्या स्पर्शासह तुमच्या विशेष दिवसाचा उत्सव साजरा करा!',
        'Punjabi': 'ਪਰੰਪਰਾ ਦੇ ਅਹਿਸਾਸ ਨਾਲ ਆਪਣੇ ਖਾਸ ਦਿਨ ਦਾ ਜਸ਼ਨ ਮਨਾਓ!',
        'Urdu': 'روایت کے لمس کے ساتھ اپنے خاص دن کا جشن منائیں!',
      });

  String get next => _t({
        'English': 'Next',
        'Gujarati': 'આગળ',
        'Hindi': 'अगला',
        'Marathi': 'पुढील',
        'Punjabi': 'ਅਗਲਾ',
        'Urdu': 'اگلا',
      });

  String get continueLabel => _t({
        'English': 'Continue',
        'Gujarati': 'ચાલુ રાખો',
        'Hindi': 'जारी रखें',
        'Marathi': 'सुरू ठेवा',
        'Punjabi': 'ਜਾਰੀ ਰੱਖੋ',
        'Urdu': 'جاری رکھیں'
      });


  String get chooseExactlyOneLanguage => _t({
        'English': 'Choose exactly one language for the editor',
        'Gujarati': 'એડિટર માટે બરાબર એક ભાષા પસંદ કરો',
        'Hindi': 'संपादक के लिए ठीक एक भाषा चुनें',
        'Marathi': 'संपादकासाठी अचूक एक भाषा निवडा',
        'Punjabi': 'ਸੰਪਾਦਕ ਲਈ ਬਿਲਕੁਲ ਇੱਕ ਭਾਸ਼ਾ ਚੁਣੋ',
        'Urdu': 'ایڈیٹر کے لیے ایک زبان منتخب کریں'
      });

  String get selectOneOrMoreLanguages => _t({
        'English': 'Select one or more languages for your templates',
        'Gujarati': 'તમારા ટેમ્પલેટ્સ માટે એક અથવા વધુ ભાષાઓ પસંદ કરો',
        'Hindi': 'अपने टेम्पलेट्स के लिए एक या अधिक भाषाएं चुनें',
        'Marathi': 'तुमच्या टेम्पलेटसाठी एक किंवा अधिक भाषा निवडा',
        'Punjabi': 'ਆਪਣੇ ਟੈਂਪਲੇਟਸ ਲਈ ਇੱਕ ਜਾਂ ਵੱਧ ਭਾਸ਼ਾਵਾਂ ਚੁਣੋ',
        'Urdu': 'اپنے ٹیمپلیٹس کے لیے ایک یا زیادہ زبانیں منتخب کریں'
      });




  String get previous => _t({
        'English': 'Previous',
        'Gujarati': 'પાછળ',
        'Hindi': 'पिछला',
        'Marathi': 'मागील',
        'Punjabi': 'ਪਿਛਲਾ',
        'Urdu': 'پچھلا',
      });

  String get save => _t({
        'English': 'Save',
        'Gujarati': 'સાચવો',
        'Hindi': 'सहेजें',
        'Marathi': 'जतन करा',
        'Punjabi': 'ਸੁਰੱਖਿਅਤ ਕਰੋ',
        'Urdu': 'محفوظ کریں',
      });

  String get saving => _t({
        'English': 'Saving...',
        'Gujarati': 'સાચવી રહ્યા છીએ...',
        'Hindi': 'सहेज रहे हैं...',
        'Marathi': 'जतन करत आहे...',
        'Punjabi': 'ਸੁਰੱਖਿਅਤ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ...',
        'Urdu': 'محفوظ کیا جا رہا ہے...',
      });

  String get downloadComplete => _t({
        'English': 'Download Complete',
        'Gujarati': 'ડાઉનલોડ પૂર્ણ થયું',
        'Hindi': 'डाउनलोड पूर्ण हुआ',
        'Marathi': 'डाउनलोड पूर्ण झाले',
        'Punjabi': 'ਡਾਊਨਲੋਡ ਪੂਰਾ ਹੋਇਆ',
        'Urdu': 'ڈاؤن لوڈ مکمل ہوا',
      });

  String get done => _t({
        'English': 'Done',
        'Gujarati': 'પૂર્ણ',
        'Hindi': 'पूर्ण',
        'Marathi': 'पूर्ण',
        'Punjabi': 'ਹੋ ਗਿਆ',
        'Urdu': 'مکمل ہو گیا'
      });
  String get cancel => _t({
        'English': 'Cancel',
        'Gujarati': 'રદ કરો',
        'Hindi': 'रद्द करें',
        'Marathi': 'रद्द करा',
        'Punjabi': 'ਰੱਦ ਕਰੋ',
        'Urdu': 'منسوخ کریں'
      });

  String get preview => _t({
        'English': 'Preview',
        'Gujarati': 'પૂર્વાવલોકન',
        'Hindi': 'पूर्वावलोकन',
        'Marathi': 'पूर्वावलोकन',
        'Punjabi': 'ਪੂਰਵਦਰਸ਼ਨ',
        'Urdu': 'پیش نظارہ',
      });

  String get download => _t({
        'English': 'Download',
        'Gujarati': 'ડાઉનલોડ કરો',
        'Hindi': 'डाउनलोड करें',
        'Marathi': 'डाउनलोड करा',
        'Punjabi': 'ਡਾਊਨਲੋਡ ਕਰੋ',
        'Urdu': 'ڈاؤن لوڈ کریں',
      });

  String get deletePage => _t({
        'English': 'Delete Page?',
        'Gujarati': 'પૃષ્ઠ કાઢી નાખવું?',
        'Hindi': 'पेज हटाएं?',
        'Marathi': 'पृष्ठ हटवायचे?',
        'Punjabi': 'ਪੰਨਾ ਮિટਾਉਣਾ?',
        'Urdu': 'صفحہ حذف کریں؟',
      });

  String get deletePageConfirm => _t({
        'English': 'Are you sure you want to delete this page?',
        'Gujarati': 'શું તમે ખરેખર આ પૃષ્ઠ કાઢી નાખવા માંગો છો?',
        'Hindi': 'क्या आप वाकई इस पेज को हटाना चाहते हैं?',
        'Marathi': 'तुम्हाला नक्की हे पृष्ठ हटवायचे आहे का?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਵਾਕਈ ਇਸ ਪੰਨੇ ਨੂੰ ਮਿਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی اس صفحہ کو حذف کرنا چاہتے ہیں؟',
      });

  String pageLabel(int index, int total) => _t({
        'English': 'Page $index/$total',
        'Gujarati': 'પૃષ્ઠ $index/$total',
        'Hindi': 'पेज $index/$total',
        'Marathi': 'पृष्ठ $index/$total',
        'Punjabi': 'ਪੰਨਾ $index/$total',
        'Urdu': 'صفحہ $index/$total',
      });

  String get edit => _t({
        'English': 'Edit',
        'Gujarati': 'સુધારો',
        'Hindi': 'एडिट',
        'Marathi': 'संपादन',
        'Punjabi': 'ਸੋਧੋ',
        'Urdu': 'ترمیم',
      });

  String get format => _t({
        'English': 'Format',
        'Gujarati': 'ફોર્મેટ',
        'Hindi': 'फॉर्मेट',
        'Marathi': 'स्वरूप',
        'Punjabi': 'ਫਾਰਮੈਟ',
        'Urdu': 'فارمیٹ',
      });

  String get rotate => _t({
        'English': 'Rotate',
        'Gujarati': 'ફેરવો',
        'Hindi': 'घुमाएं',
        'Marathi': 'फिरवा',
        'Punjabi': 'ਘੁਮਾਓ',
        'Urdu': 'گھمائیں',
      });

  String get color => _t({
        'English': 'Color',
        'Gujarati': 'રંગ',
        'Hindi': 'रंग',
        'Marathi': 'रंग',
        'Punjabi': 'ਰੰਗ',
        'Urdu': 'رنگ',
      });

  String get opacity => _t({
        'English': 'Opacity',
        'Gujarati': 'પારદર્શકતા',
        'Hindi': 'पारदर्शिता',
        'Marathi': 'अपारदर्शकता',
        'Punjabi': 'ਧੁੰਦਲਾਪਨ',
        'Urdu': 'دھندلاپن',
      });

  String get selectTextFieldPrompt => _t({
        'English': 'Please select a text field first',
        'Gujarati': 'કૃપા કરીને પહેલા લખાણ પસંદ કરો',
        'Hindi': 'कृपया पहले एक टेक्स्ट फ़ील्ड चुनें',
        'Marathi': 'कृपया आधी मजकूर फील्ड निवडा',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਪਹਿਲਾਂ ਇੱਕ ਟੈਕਸਟ ਫੀਲਡ ਚੁਣੋ',
        'Urdu': 'براہ کرم پہلے ٹیکسٹ فیلڈ منتخب کریں',
      });

  // ─────────────────────────────────────────────────────────────
  // 🕉 INVITATION LABELS (SYNCED TO CANVAS)
  // ─────────────────────────────────────────────────────────────

  String ganeshayNamahLabelFor(String lang) => _tFor({
        'English': '|| Shree Ganeshay Namah ||',
        'Gujarati': '|| શ્રી ગણેશાય નમઃ ||',
        'Hindi': '|| श्री गणेशाय नमः ||',
        'Marathi': '|| श्री गणेशाय नमः ||',
        'Punjabi': '|| ਸ਼੍ਰੀ ਗਣੇਸ਼ਾਏ ਨਮਹ ||',
        'Urdu': '|| شری گنیشائے نمہ ||'
      }, lang);

  String mangalikPrasangoLabelFor(String lang) => _tFor({
        'English': 'Mangalik Prasango',
        'Gujarati': 'માંગલિક પ્રસંગો',
        'Hindi': 'मांगलिक प्रसंग',
        'Marathi': 'मांगलिक प्रसंग',
        'Punjabi': 'ਮੰਗਲਿਕ ਪ੍ਰਸੰਗ',
        'Urdu': 'مانگلک پرسنگ'
      }, lang);

  String shubhVivahLabelFor(String lang) => _tFor({
        'English': 'Shubh Vivah',
        'Gujarati': 'શુભ વિવાહ',
        'Hindi': 'शुभ विवाह',
        'Marathi': 'शुभ विवाह',
        'Punjabi': 'ਸ਼ੁਭ ਵਿਆਹ',
        'Urdu': 'شادی مبارک'
      }, lang);

  String dearGuestLabelFor(String lang) => _tFor({
        'English': 'Dear Guest, ...........................................',
        'Gujarati':
            'સ્નેહી સ્વજન...........................................................................',
        'Hindi':
            'प्रिय अतिथि, ...........................................',
        'Marathi':
            'प्रिय पाहुणे, ...........................................',
        'Punjabi':
            'ਪਿਆਰੇ ਮਹਿਮਾਨ, ...........................................',
        'Urdu':
            'محترم مہمان، ...........................................'
      }, lang);

  String sangeetSandhyaLabelFor(String lang) => _tFor({
        'English': 'Sangeet Sandhya',
        'Gujarati': 'સંગીત સંધ્યા',
        'Hindi': 'संगीत संध्या',
        'Marathi': 'संगीत संध्या',
        'Punjabi': 'ਸੰਗੀਤ ਸੰਧਿਆ',
        'Urdu': 'سنگیت سندھیا'
      }, lang);

  String lagnotsavLabelFor(String lang) => _tFor({
        'English': 'Lagnotsav',
        'Gujarati': 'લગ્નોત્સવ',
        'Hindi': 'लग्नोत्सव',
        'Marathi': 'लग्नोत्सव',
        'Punjabi': 'ਲਗਨੋਤਸਵ',
        'Urdu': 'لگنوتسو'
      }, lang);

  String parinayUtsavLabelFor(String lang) => _tFor({
        'English': 'Parinay Utsav',
        'Gujarati': 'પરિણય ઉત્સવ',
        'Hindi': 'परिणय उत्सव',
        'Marathi': 'परिणय उत्सव',
        'Punjabi': 'ਪਰਿਣਯ ਉਤਸਵ',
        'Urdu': 'پرینائے اتسو'
      }, lang);

  String sangLabelFor(String lang) => _tFor({
        'Hindi': 'संग',
        'Marathi': 'सोबत',
        'Punjabi': 'ਸੰਗ',
        'Urdu': 'سنگ'
      }, lang);

  String get guestUpdated => _t({
        'English': 'Guest updated successfully!',
        'Gujarati': 'મહેમાન સફળતાપૂર્વક અપડેટ થયા!',
        'Hindi': 'अतिथि सफलतापूर्वक अपडेट किया गया!',
        'Marathi': 'पाहुणे यशस्वीरित्या अपडेट झाले!',
        'Punjabi': 'ਮਹਿਮਾਨ ਸਫਲਤਾਪੂਰਵਕ ਅਪਡੇਟ ਕੀਤਾ ਗਿਆ!',
        'Urdu': '!مہمان کامیابی کے ساتھ اپ ڈیٹ ہو گیا'
      });
  String get guestAdded => _t({
        'English': 'Guest added successfully!',
        'Gujarati': 'મહેમાન સફળતાપૂર્વક ઉમેરાયા!',
        'Hindi': 'अतिथि सफलतापूर्वक जोड़ा गया!',
        'Marathi': 'पाहुणे यशस्वीरित्या जोडले गेले!',
        'Punjabi': 'ਮਹਿਮਾਨ ਸਫਲਤਾਪੂਰਵਕ ਜੋੜਿਆ ਗਿਆ!',
        'Urdu': 'مہمان کامیابی کے ساتھ شامل کیا گیا!'
      });
  String get pleaseEnterNameAndPhone => _t({
        'English': 'Please enter name and phone number',
        'Gujarati': 'કૃપા કરીને નામ અને ફોન નંબર દાખલ કરો',
        'Hindi': 'कृपया नाम और फ़ोन नंबर दर्ज करें',
        'Marathi': 'कृपया नाव आणि फोन नंबर प्रविष्ट करा',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਨਾਮ ਅਤੇ ਫੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Urdu': 'براہ کرم نام اور فون نمبر درج کریں'
      });

  String nimantrakLabelFor(String lang) => _tFor({
        'English': 'Inviter',
        'Gujarati': 'નિમંત્રક',
        'Hindi': 'निमंत्रक',
        'Marathi': 'निमंत्रक',
        'Punjabi': 'ਨਿਮੰਤਰਕ',
        'Urdu': 'نمنترک'
      }, lang);

  String taLabelFor(String lang) => _tFor({
        'English': 'Date',
        'Gujarati': 'તા.',
        'Hindi': 'दि.',
        'Marathi': 'दि.',
        'Punjabi': 'ਮਿਤੀ',
        'Urdu': 'تاریخ'
      }, lang);

  String samayLabelFor(String lang) => _tFor({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'समय',
        'Marathi': 'वेळ',
        'Punjabi': 'ਸਮਾਂ',
        'Urdu': 'وقت'
      }, lang);

  String chiLabelFor(String lang) => _tFor({
        'English': 'Chi.',
        'Gujarati': 'ચિ.',
        'Hindi': 'चि.',
        'Marathi': 'श्री.',
        'Punjabi': 'ਚਿ.',
        'Urdu': 'عزیز'
      }, lang);

  String sthalLabelFor(String lang) => _tFor({
        'English': 'Venue',
        'Gujarati': 'સ્થળ',
        'Hindi': 'स्थान',
        'Marathi': 'ठिकाण',
        'Punjabi': 'ਸਥਾਨ',
        'Urdu': 'مقام'
      }, lang);

  String weddingCeremonyLabelFor(String lang) => _tFor({
        'English': 'Wedding Ceremony',
        'Gujarati': 'લગ્ન વિધિ',
        'Hindi': 'विवाह समारोह',
        'Marathi': 'विवाह समारोह',
        'Punjabi': 'ਵਿਅਾਹ ਸਮਾਗਮ',
        'Urdu': 'شادی کی تقریب'
      }, lang);

  // ─────────────────────────────────────────────────────────────
  // 🛠 OTHER UI STRINGS
  // ─────────────────────────────────────────────────────────────

  String get addEventLabel => _t({
        'English': 'Add Event',
        'Gujarati': 'પ્રસંગ ઉમેરો',
        'Hindi': 'कार्यक्रम जोड़ें',
        'Marathi': 'प्रसंग जोडा',
        'Punjabi': 'ਪ੍ਰੋਗਰਾਮ ਜੋੜੋ',
        'Urdu': 'تقریب شامل کریں'
      });
  String get generateContentLabel => _t({
        'English': 'Generate Content',
        'Gujarati': 'કન્ટેન્ટ બનાવો',
        'Hindi': 'सामग्री बनाएं',
        'Marathi': 'मजकूर तयार करा',
        'Punjabi': 'ਸਮੱਗਰੀ ਤਿਆਰ ਕਰੋ',
        'Urdu': 'مواد تیار کریں'
      });
  String get previewLabel => _t({
        'English': 'Preview',
        'Gujarati': 'પૂર્વાવલોકન',
        'Hindi': 'पूर्वावलोकन',
        'Marathi': 'पूर्वावलोकन',
        'Punjabi': 'ਪੂਰਵ દરਸ਼ਨ',
        'Urdu': 'پیش نظارہ'
      });
  String get nextLabel => _t({
        'English': 'Next',
        'Gujarati': 'આગળ',
        'Hindi': 'आगे',
        'Marathi': 'पुढे',
        'Punjabi': 'ਅੱਗੇ',
        'Urdu': 'اگلا'
      });
  String get back => _t({
        'English': 'Back',
        'Gujarati': 'પાછળ',
        'Hindi': 'पीछे',
        'Marathi': 'मागे',
        'Punjabi': 'ਪਿੱਛੇ',
        'Urdu': 'پیچھے'
      });
  String get weddingDateLabel => _t({
        'English': 'Wedding Date',
        'Gujarati': 'લગ્ન તારીખ',
        'Hindi': 'शादी की तारीख',
        'Marathi': 'लग्नाची तारीख',
        'Punjabi': 'ਵਿਆਹ ਦੀ ਤਾਰੀਖ',
        'Urdu': 'شادی کی تاریخ'
      });
  String get eventNameLabel => _t({
        'English': 'Event Name',
        'Gujarati': 'પ્રસંગનું નામ',
        'Hindi': 'कार्यक्रम का नाम',
        'Marathi': 'प्रसंगाचे नाव',
        'Punjabi': 'ਪ੍ਰੋਗਰਾਮ ਦਾ ਨਾਮ',
        'Urdu': 'تقریب کا نام'
      });
  String get ratingSubtitle => _t({
        'English': "We'd love to hear your feedback.",
        'Gujarati': 'અમે તમારો પ્રતિસાદ સાંભળવા માંગીએ છીએ.',
        'Hindi': 'हम आपकी प्रतिक्रिया सुनना चाहेंगे.',
        'Marathi': 'आम्हाला तुमचा अभिप्राय आवडेल.',
        'Punjabi': 'ਅਸੀਂ ਤੁਹਾਡੀ ਫੀਡਬੈਕ ਸੁਣਨਾ ਚਾਹੁੰਦੇ ਹਾਂ।',
        'Urdu': 'ہم آپ کی رائے جاننا چاہیں گے۔'
      });
  String get loginRequired => _t({
        'English': 'Please login to rate the app',
        'Gujarati': 'કૃપા કરીને રેટિંગ આપવા માટે લોગિન કરો',
        'Hindi': 'कृपया रेटिंग देने के लिए लॉग इन करें',
        'Marathi': 'कृपया रेटिंग देण्यासाठी लॉग इन करा',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਰੇਟਿੰਗ ਦੇਣ ਲਈ ਲੌਗਇਨ ਕਰੋ',
        'Urdu': 'براہ کرم درجہ بندی کرنے کے لیے لاگ ان کریں'
      });
  String get errorOccurred => _t({
        'English': 'An error occurred. Please try again.',
        'Gujarati': 'ભૂલ આવી. ફરી પ્રયાસ કરો.',
        'Hindi': 'त्रुटि हुई। कृपया पुनः प्रयास करें।',
        'Marathi': 'त्रुटी आली. कृपया पुन्हा प्रयत्न करा.',
        'Punjabi': 'ਗਲਤੀ ਹੋਈ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰา ਕੋਸ਼ਿਸ਼ ਕਰੋ।',
        'Urdu': 'خرابی پیش آگئی۔ براہ کرم دوبارہ کوشش کریں۔'
      });
  String get alreadyRated => _t({
        'English': 'You have already submitted a rating.',
        'Gujarati': 'તમે પહેલેથી જ રેટિંગ સબમિટ કર્યું છે.',
        'Hindi': 'आप पहले ही रेटिंग सबमिट कर चुके हैं.',
        'Marathi': 'तुम्ही आधीच रेटिंग सबमिट केले आहे.',
        'Punjabi': 'ਤੁਸੀਂ ਪਹਿਲਾਂ ਹੀ ਰੇਟਿੰਗ ਸਪੁਰਦ ਕਰ ਚੁੱਕੇ ਹੋ।',
        'Urdu': 'آپ پہلے ہی درجہ بندی جمع کروا چکے ہیں۔'
      });
  String get dateLabel => _t({
        'English': 'Date',
        'Gujarati': 'તારીખ',
        'Hindi': 'तारीख',
        'Marathi': 'तारीख',
        'Punjabi': 'ਤਾਰੀਖ',
        'Urdu': 'تاریخ'
      });
  String get timeLabel => _t({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'समय',
        'Marathi': 'वेळ',
        'Punjabi': 'ਸਮਾਂ',
        'Urdu': 'وقت'
      });
  String get venuePlaceLabel => _t({
        'English': 'Venue / Place',
        'Gujarati': 'સ્થળ / જગ્યા',
        'Hindi': 'स्थान / जगह',
        'Marathi': 'स्थळ',
        'Punjabi': 'ਸਥਾਨ',
        'Urdu': 'مقام'
      });
  String get weddingDetailsLabel => _t({
        'English': 'Wedding Details',
        'Gujarati': 'લગ્નની વિગત',
        'Hindi': 'शादी का विवरण',
        'Marathi': 'लग्नाचे तपशील',
        'Punjabi': 'ਵਿਆਹ ਦੇ ਵੇਰਵੇ',
        'Urdu': 'شادی کی تفصیلات'
      });
  String get brideName => _t({
        'English': "Bride's Name",
        'Gujarati': "કન્યાનું નામ",
        'Hindi': "दुल्हन का नाम",
        'Marathi': "वधूचे नाव",
        'Punjabi': "ਵਹੁਟੀ ਦਾ ਨਾਮ",
        'Urdu': 'دلہن کا نام'
      });
  String get groomName => _t({
        'English': "Groom's Name",
        'Gujarati': "વરનું નામ",
        'Hindi': "दूल्हे का नाम",
        'Marathi': "वराचे नाव",
        'Punjabi': "ਲਾੜੇ ਦਾ ਨਾਮ",
        'Urdu': 'دولہے کا نام'
      });
  String get getStartedLabel => _t({
        'English': 'Get Started',
        'Gujarati': 'શરૂ કરો',
        'Hindi': 'शुरू करें',
        'Marathi': 'सुरू करा',
        'Punjabi': 'ਸ਼ੁਰੂ ਕਰੋ',
        'Urdu': 'شروع کریں'
      });
  String get planActive => _t({
        'English': 'Plan Active',
        'Gujarati': 'પ્લાન એક્ટિવ',
        'Hindi': 'प्लान एक्टिव',
        'Marathi': 'प्लॅन सक्रिय',
        'Punjabi': 'ਪਲਾਨ ਐਕਟਿਵ',
        'Urdu': 'پلان ایکٹو',
      });

  String get downloadShare => _t({
        'English': 'Download & Share',
        'Gujarati': 'ડાઉનલોડ અને શેર કરો',
        'Hindi': 'डाउनलोड और साझा करें',
        'Marathi': 'डाउनलोड आणि शेयर करा',
        'Punjabi': 'ਡਾਊਨਲੋਡ ਅਤੇ ਸਾਂਝਾ ਕਰੋ',
        'Urdu': 'ڈاؤن لوڈ اور شیئر کریں'
      });

  String get invitationLanguageLabel => _t({
        'English': 'Invitation Language',
        'Gujarati': 'આમંત્રણ ભાષા',
        'Hindi': 'निमंत्रण भाषा',
        'Marathi': 'निमंत्रण भाषा',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾ',
        'Urdu': 'دعوت نامہ کی زبان'
      });
  String get rotationLabel => _t({
        'English': 'Rotation',
        'Gujarati': 'પરિભ્રમણ',
        'Hindi': 'रोटेशन',
        'Marathi': 'रोटेशन',
        'Punjabi': 'ਰੋਟੇਸ਼ਨ',
        'Urdu': 'گھماؤ'
      });
  String get opacityLabel => _t({
        'English': 'Opacity',
        'Gujarati': 'પારદર્શિતા',
        'Hindi': 'अपारदर्शिता',
        'Marathi': 'अपारदर्शकता',
        'Punjabi': 'ਪਾਰਦਰਸ਼ਤਾ',
        'Urdu': 'دھندلاپن'
      });
  String get chooseColorLabel => _t({
        'English': 'Choose Color',
        'Gujarati': 'રંગ પસંદ કરો',
        'Hindi': 'रंग चुनें',
        'Marathi': 'रंग निवडा',
        'Punjabi': 'ਰੰਗ ਚੁਣੋ',
        'Urdu': 'رنگ منتخب کریں'
      });

  // 👥 GUEST MANAGEMENT
  String get editGuest => _t({
        'English': 'Edit Guest',
        'Gujarati': 'મહેમાન સંપાદિત કરો',
        'Hindi': 'अतिथि संपादित करें',
        'Marathi': 'पाहुणे संपादित करा',
        'Punjabi': 'ਮਹਿਮਾਨ ਨੂੰ ਸੋਧੋ',
        'Urdu': 'مہمان کی ترمیم کریں'
      });
  String get viewed => _t({
        'English': 'Viewed',
        'Gujarati': 'જોયેલ',
        'Hindi': 'देखा गया',
        'Marathi': 'पाहिलेले',
        'Punjabi': 'ਵੇખ્યા ગયા',
        'Urdu': 'دیکھا گیا'
      });
  String rsvpStatusLabel(RsvpStatus status) {
    switch (status) {
      case RsvpStatus.pending:
        return pending;
      case RsvpStatus.sent:
        return sent;
      case RsvpStatus.viewed:
        return viewed;
    }
  }
  String get deleteGuest => _t({
        'English': 'Delete Guest',
        'Gujarati': 'મહેમાન કાઢી નાખો',
        'Hindi': 'अतिथि हटाएं',
        'Marathi': 'पाहुणे काढून टाका',
        'Punjabi': 'ਮਹਿਮਾਨ ਨੂੰ ਹਟਾਓ',
        'Urdu': 'مہمان کو حذف کریں'
      });
  String get saveChanges => _t({
        'English': 'Save Changes',
        'Gujarati': 'ફેરફારો સાચવો',
        'Hindi': 'बदलाव सहेजें',
        'Marathi': 'बदल जतन करा',
        'Punjabi': 'ਤਬਦੀਲੀਆਂ ਸੁਰੱਖਿਅਤ ਕਰੋ',
        'Urdu': 'تبدیلیاں محفوظ کریں'
      });
  String get delete => _t({
        'English': 'Delete',
        'Gujarati': 'કાઢી નાખો',
        'Hindi': 'हटाएं',
        'Marathi': 'काढा',
        'Punjabi': 'ਹਟਾਓ',
        'Urdu': 'حذف کریں'
      });
  String get guestRemoved => _t({
        'English': 'Guest removed.',
        'Gujarati': 'મહેમાન દૂર કર્યા.',
        'Hindi': 'अतिथि हटा दिया गया.',
        'Marathi': 'पाहुणे काढले.',
        'Punjabi': 'ਮਹਿਮਾਨ ਹਟਾ ਦਿੱਤਾ ਗਿਆ।',
        'Urdu': '.مہمان کو ہٹا دیا گیا'
      });
  String get noGuestsToExport => _t({
        'English': 'No guests to export.',
        'Gujarati': 'નિકાસ કરવા માટે કોઈ મહેમાન નથી.',
        'Hindi': 'निर्यात करने के लिए कोई अतिथि नहीं हैं.',
        'Marathi': 'निर्यात करण्यासाठी पाहुणे नाहीत.',
        'Punjabi': 'ਨਿਰਯਾਤ ਕਰਨ ਲਈ ਕੋਈ ਮਹਿਮਾਨ ਨਹੀਂ ਹੈ।',
        'Urdu': '.برآمد کرنے کے لیے کوئی مہمان نہیں ہے'
      });
  String get exportGuestList => _t({
        'English': 'Export Guest List',
        'Gujarati': 'મહેમાન યાદી નિકાસ કરો',
        'Hindi': 'अतिथि सूची निर्यात करें',
        'Marathi': 'पाहुण्यांची यादी निर्यात करा',
        'Punjabi': 'ਮਹਿਮਾਨ ਸੂਚੀ ਨਿਰਯਾਤ ਕਰੋ',
        'Urdu': 'مہمانوں کی فہرست برآمد کریں'
      });
  String get chooseExportFormat => _t({
        'English': 'Choose export format',
        'Gujarati': 'નિકાસ ફોર્મેટ પસંદ કરો',
        'Hindi': 'निर्यात प्रारूप चुनें',
        'Marathi': 'निर्यात स्वरूप निवडा',
        'Punjabi': 'ਨਿਰਯਾਤ ਫਾਰਮੈਟ ਚੁਣੋ',
        'Urdu': 'ایکسپورٹ فارمیٹ منتخب کریں'
      });
  String get csvFile => _t({
        'English': 'CSV File',
        'Gujarati': 'CSV ફાઇલ',
        'Hindi': 'CSV फ़ाइल',
        'Marathi': 'CSV फाइल',
        'Punjabi': 'CSV ਫਾਈਲ',
        'Urdu': 'سی ایس وی فائل'
      });
  String get csvSubtitle => _t({
        'English': 'For Excel / Google Sheets',
        'Gujarati': 'એક્સેલ / ગૂગલ શીટ્સ માટે',
        'Hindi': 'एक्सेल / गूगल शीट्स के लिए',
        'Marathi': 'एक्सेल / गूगल शीट्ससाठी',
        'Punjabi': 'ਐਕਸਲ / ਗੂਗਲ ਸ਼ੀਟਸ ਲਈ',
        'Urdu': 'ایکسل / گوگل شیٹس کے لیے'
      });
  String get vcfContacts => _t({
        'English': 'VCF Contacts',
        'Gujarati': 'VCF સંપર્કો',
        'Hindi': 'VCF संपर्क',
        'Punjabi': 'VCF ਸੰਪਰਕ',
        'Urdu': 'وی سی ایف روابط'
      });
  String get vcfSubtitle => _t({
        'English': 'Import to Phone Contacts',
        'Gujarati': 'ફોન સંપર્કોમાં આયાત કરો',
        'Hindi': 'फ़ोन संपर्कों में आयात करें',
        'Marathi': 'फोन संपर्कातून आयात करा',
        'Punjabi': 'ਫੋਨ ਸੰਪਰਕਾਂ ਵਿੱਚ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'فون روابط میں درآمد کریں'
      });
  String get pdfDocument => _t({
        'English': 'PDF Document',
        'Gujarati': 'PDF દસ્તાવેજ',
        'Hindi': 'PDF दस्तावेज़',
        'Marathi': 'PDF दस्तऐवज',
        'Punjabi': 'PDF ਦਸਤਾਵੇਜ਼',
        'Urdu': 'پی ڈی ایف دستاویز'
      });
  String get pdfSubtitle => _t({
        'English': 'For Printing / Sharing',
        'Gujarati': 'પ્રિન્ટિંગ / શેરિંગ માટે',
        'Hindi': 'प्रिंटिंग / शेयरिंग के लिए',
        'Marathi': 'प्रिंटिंग / शेयरिंगसाठी',
        'Punjabi': 'ਪ੍ਰਿੰਟਿੰਗ / ਸ਼ੇਅਰਿੰਗ ਲਈ',
        'Urdu': 'پرنٹنگ / شیئرنگ کے لیے'
      });

  String deleteGuestConfirm(String name) => _t({
        'English': 'Are you sure you want to delete $name?',
        'Gujarati': 'શું તમે ખરેખર $name ને કાઢી નાખવા માંગો છો?',
        'Hindi': 'क्या आप वाकई $name को हटाना चाहते हैं?',
        'Marathi': 'तुम्हाला खरोखर $name काढून टाकायचे आहे?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨੀ ਤੌਰ ਤੇ $name ਨੂੰ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی $name کو حذف کرنا چاہتے ہیں؟',
      });

  // ⭐ RATING DIALOG
  String get thanks => _t({
        'English': 'Thanks!',
        'Gujarati': 'આભાર!',
        'Hindi': 'धन्यवाद!',
        'Marathi': 'धन्यवाद!',
        'Punjabi': 'ਧੰਨਵਾਦ!',
        'Urdu': 'شکریہ!'
      });

  String get submit => _t({
        'English': 'Submit',
        'Gujarati': 'સબમિટ કરો',
        'Hindi': 'सबमिट करें',
        'Marathi': 'सबमिट करा',
        'Punjabi': 'ਸਬਮਿਟ ਕਰੋ',
        'Urdu': 'جمع کروائیں'
      });
  String get noThanks => _t({
        'English': 'No, Thanks',
        'Gujarati': 'ના, આભાર',
        'Hindi': 'नहीं, धन्यवाद',
        'Marathi': 'नाही, धन्यवाद',
        'Punjabi': 'ਨਹੀਂ, ਧੰਨਵਾਦ',
        'Urdu': 'نہیں، شکریہ'
      });

  // 🎉 SUCCESS SCREEN
  String get finalizingDesign => _t({
        'English': 'Please wait, finalizing your design...',
        'Gujarati': 'તમારી ડિઝાઇનને આખરી ઓપ આપી રહ્યા છીએ...',
        'Hindi': 'आपकी डिझाइन को अंतिम रूप दे रहे हैं...',
        'Marathi': 'तुमची डिझाइन अंतिम करत आहोत...',
        'Punjabi': 'ਤੁਹਾਡੇ ਡਿਜ਼ਾਈਨ ਨੂੰ ਅੰਤਿਮ ਰੂਪ ਦਿੱਤਾ ਜਾ ਰਿਹਾ ਹੈ...',
        'Urdu': 'آپ کے ڈیزائن کو حتمی شکل دی جا رہی ہے...'
      });
  String get savedToDownloads => _t({
        'English': 'It will be saved to your Downloads folder',
        'Gujarati': 'ડાઉનલોડ્સમાં સાચવ્યું',
        'Hindi': 'डाउनलोड में सहेजा गया',
        'Marathi': 'डाउनलोड्समध्ये जतन केले',
        'Punjabi': 'ਡਾਊਨਲੋਡਾਂ ਵਿੱਚ ਸੁਰੱਖਿਅਤ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'ڈاؤن لوڈز میں محفوظ کر لیا گیا'
      });
  String get openPdf => _t({
        'English': 'Open PDF',
        'Gujarati': 'PDF ખોલો',
        'Hindi': 'PDF खोलें',
        'Marathi': 'PDF उघडा',
        'Punjabi': 'PDF ਖੋਲ੍ਹੋ',
        'Urdu': 'پی ڈی ایف کھولیں'
      });
  String get renamePdf => _t({
        'English': 'Rename PDF',
        'Gujarati': 'PDF નામ બદલો',
        'Hindi': 'PDF का नाम बदलें',
        'Marathi': 'PDF चे नाव बदला',
        'Punjabi': 'PDF ਦਾ ਨਾਮ ਬਦਲੋ',
        'Urdu': 'پی ڈی ایف کا نام تبدیل کریں'
      });
  String get fileName => _t({
        'English': 'File Name',
        'Gujarati': 'ફાઇલનું નામ',
        'Hindi': 'फ़ाइल का नाम',
        'Marathi': 'फाइलचे नाव',
        'Punjabi': 'ਫਾਈਲ ਦਾ ਨਾਮ',
        'Urdu': 'فائل کا نام'
      });
  String get rename => _t({
        'English': 'Rename',
        'Gujarati': 'નામ બદલો',
        'Hindi': 'नाम बदलें',
        'Marathi': 'नाव बदला',
        'Punjabi': 'ਨਾਮ ਬਦਲੋ',
        'Urdu': 'نام تبدیل کریں'
      });
  String get saveFailed => _t({
        'English': 'Failed to save PDF. Please try again.',
        'Gujarati': 'PDF સાચવવામાં નિષ્ફળ. ફરી પ્રયાસ કરો.',
        'Hindi': 'PDF सहेजने में विफल। कृपया पुनः प्रयास करें।',
        'Marathi': 'PDF जतन अयशस्वी. पुन्हा प्रयत्न करा.',
        'Punjabi': 'PDF ਸੁਰੱਖਿਅਤ ਕਰਨ ਵਿੱਚ ਅਸਫਲ। ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।',
        'Urdu': 'پی ڈی ایف محفوظ نہیں ہوئی۔ دوبارہ کوشش کریں۔'
      });
  String get retry => _t({
        'English': 'Try Again',
        'Gujarati': 'ફરી પ્રયાસ કરો',
        'Hindi': 'पुनः प्रयास करें',
        'Marathi': 'पुन्हा प्रयत्न करा',
        'Punjabi': 'ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ',
        'Urdu': 'دوبارہ کوشش کریں'
      });
  String savingPage(int current, int total) => _t({
        'English': 'Saving page $current of $total...',
        'Gujarati': 'પૃષ્ઠ $current / $total સાચવી રહ્યા છીએ...',
        'Hindi': 'पृष्ठ $current / $total सहेज रहे हैं...',
        'Marathi': 'पान $current / $total जतन करत आहे...',
        'Punjabi': 'ਸਫ਼ਾ $current / $total ਸੁਰੱਖਿਅਤ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ...',
        'Urdu': 'صفحہ $current / $total محفوظ ہو رہا ہے...'
      });
  String get shareWith => _t({
        'English': 'Share with',
        'Gujarati': 'શેર કરો',
        'Hindi': 'इसके साथ साझा करें',
        'Marathi': 'यांच्यासोबत शेयर करा',
        'Punjabi': 'ਨਾਲ ਸਾਂਝਾ ਕਰੋ',
        'Urdu': 'کے ساتھ شیئر کریں'
      });

  // 🚪 PROFILE & LOGOUT
  String get comingSoon => _t({
        'English': 'Coming Soon',
        'Gujarati': 'ટૂંક સમયમાં આવી રહ્યું છે',
        'Hindi': 'जल्द आ रहा है',
        'Marathi': 'लवकरच येत आहे',
        'Punjabi': 'ਜਲਦੀ ਆ ਰਿਹਾ ਹੈ',
        'Urdu': 'جلد آرہا ہے'
      });
  String get logoutConfirmation => _t({
        'English': 'Logout Confirmation',
        'Gujarati': 'લોગઆઉટ કન્ફર્મેશન',
        'Hindi': 'लॉगआउट पुष्टिकरण',
        'Marathi': 'लॉगआउट पुष्टीकरण',
        'Punjabi': 'ਲੌਗਆਊਟ ਪੁਸ਼ਟੀਕਰਨ',
        'Urdu': 'لاگ آؤٹ کی تصدیق'
      });
  String get logoutMessage => _t({
        'English': 'Are you sure you want to logout?',
        'Gujarati': 'શું તમે ખરેખર લોગઆઉટ કરવા માંગો છો?',
        'Hindi': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
        'Marathi': 'तुम्हाला खरोखर लॉगआउट करायचे आहे?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨੀ ਤੌਰ ਤੇ ਲੌਗਆਊਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
      });
  String get confirm => _t({
        'English': 'Confirm',
        'Gujarati': 'પુષ્ટિ કરો',
        'Hindi': 'पुष्टि करें',
        'Marathi': 'पुष्टी करा',
        'Punjabi': 'ਪੁਸ਼ਟੀ ਕਰੋ',
        'Urdu': 'تصدیق کریں'
      });

  // 📋 GUEST FILTERS & OPTIONS
  String get noGuestsYet => _t({
        'English': 'No guests yet',
        'Gujarati': 'હજુ કોઈ મહેમાન નથી',
        'Hindi': 'अभी तक कोई अतिथि नहीं',
        'Marathi': 'अजून पाहुणे नाहीत',
        'Punjabi': 'ਅਜੇ ਕੋਈ ਮਹਿਮਾਨ ਨਹੀਂ',
        'Urdu': 'ابھی تک کوئی مہمان نہیں'
      });
  String get addGuestsHint => _t({
        'English':
            'Start adding guests to manage your wedding invitations efficiently.',
        'Gujarati':
            'તમારા લગ્ન આમંત્રણોને અસરકારક રીતે સંચાલિત કરવા માટે મહેમાનો ઉમેરવાનું શરૂ કરો.',
        'Hindi':
            'अपने शादी के निमंत्रणों को कुशलतापूर्वक प्रबंधित करने के लिए मेहमानों को जोड़ना शुरू करें.',
        'Marathi':
            'तुमच्या लग्न निमंत्रणांचे कार्यक्षम व्यवस्थापन करण्यासाठी पाहुणे जोडण्यास सुरुवात करा.',
        'Punjabi':
            'ਆਪਣੇ ਵਿਆਹ ਦੇ ਸੱਦੇ ਨੂੰ ਕੁਸ਼ਲਤਾ ਨਾਲ ਪ੍ਰਬੰਧਿਤ ਕਰਨ ਲਈ ਮਹਿਮਾਨਾਂ ਨੂੰ ਜੋੜਨਾ ਸ਼ੁਰੂ ਕਰੋ।',
        'Urdu':
            'اپنی شادی کے دعوت ناموں کو مؤثر طریقے سے منظم کرنے کے لیے مہمانوں کو شامل کرنا شروع کریں۔'
      });
  String get addGuest => _t({
        'English': 'Add Guest',
        'Gujarati': 'મહેમાન ઉમેરો',
        'Hindi': 'अतिथि जोड़ें',
        'Marathi': 'पाहुणे जोडा',
        'Punjabi': 'ਮਹਿਮਾਨ ਜੋੜੋ',
        'Urdu': 'مہمان شامل کریں'
      });
  String get searchGuests => _t({
        'English': 'Search Guests...',
        'Gujarati': 'મહેમાનો શોધો...',
        'Hindi': 'अतिथि खोजें...',
        'Marathi': 'पाहुणे शोधा...',
        'Punjabi': 'ਮਹਿਮਾਨ ਲੱਭੋ...',
        'Urdu': 'مہمان تلاش کریں...'
      });
  String get all => _t({
        'English': 'All',
        'Gujarati': 'બધા',
        'Hindi': 'सभी',
        'Marathi': 'सर्व',
        'Punjabi': 'ਸਾਰੇ',
        'Urdu': 'تمام'
      });
  String get sent => _t({
        'English': 'Sent',
        'Gujarati': 'મોકલેલ',
        'Hindi': 'भेजा गया',
        'Marathi': 'पाठवलेले',
        'Punjabi': 'ਭੇਜਿਆ ਗਿਆ',
        'Urdu': 'بھیجا گیا'
      });
  String get pending => _t({
        'English': 'Pending',
        'Gujarati': 'બાકી',
        'Hindi': 'लंबित',
        'Marathi': 'बाकी',
        'Punjabi': 'ਬਾਕੀ',
        'Urdu': 'زیر التواء'
      });
  String get accountSuspended => _t({
        'English': 'Account Suspended',
        'Gujarati': 'એકાઉન્ટ સ્થગિત કરવામાં આવ્યું',
        'Hindi': 'खाता निलंबित',
        'Marathi': 'खाते निलंबित केले',
        'Punjabi': 'ਖਾਤਾ ਮੁਅੱਤਲ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'اکاؤنٹ معطل کر دیا گیا'
      });

  String get addText => _t({
        'English': 'Add Text',
        'Gujarati': 'લખાણ ઉમેરો',
        'Hindi': 'टेक्स्ट जोड़ें',
        'Marathi': 'टेक्स्ट जोडा',
        'Punjabi': 'ਟੈਕਸਟ ਜੋੜੋ',
        'Urdu': 'تحریر شامل کریں'
      });
  String get noGuestsMatch => _t({
        'English': 'No guests match your search',
        'Gujarati': 'તમારી શોધ સાથે કોઈ મહેમાન મળતા નથી',
        'Hindi': 'आपकी खोज से कोई अतिथि मेल नहीं खाता',
        'Marathi': 'तुमच्या शोधाशी कोणतेही पाहुणे जुळत नाहीत',
        'Punjabi': 'ਤੁہائی ਖੋਜ ਨਾਲ ਕੋਈ ਮਹਿਮਾਨ ਨਹੀਂ ਮਿਲਦਾ',
        'Urdu': 'آپ کی تلاش سے کوئی مہمان مطابقت نہیں رکھتا'
      });
  String get addManually => _t({
        'English': 'Add Manually',
        'Gujarati': 'જાતે ઉમેરો',
        'Hindi': 'स्वयं जोड़ें',
        'Marathi': 'वैयक्तिकरित्या जोडा',
        'Punjabi': 'ਖੁਦ ਜੋੜੋ',
        'Urdu': 'دستی طور پر شامل کریں'
      });
  String get enterGuestDetail => _t({
        'English': 'Enter guest details manually',
        'Gujarati': 'મહેમાનની વિગતો જાતે દાખલ કરો',
        'Hindi': 'अतिथि विवरण स्वयं दर्ज करें',
        'Marathi': 'पाहुण्यांचे तपशील वैयक्तिकरित्या भरा',
        'Punjabi': 'ਮਹਿਮਾਨ ਦੇ ਵੇਰਵੇ ਖੁਦ ਦਰਜ ਕਰੋ',
        'Urdu': 'مہمان کی تفصیلات دستی طور پر درج کریں'
      });
  String get importContacts => _t({
        'English': 'Import Contacts',
        'Gujarati': 'સંપર્કો આયાત કરો',
        'Hindi': 'संपर्क आयात करें',
        'Marathi': 'संपर्क आयात करा',
        'Punjabi': 'ਸੰਪਰਕ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'روابط درآمد کریں'
      });
  String get importFromContacts => _t({
        'English': 'Import from phone contacts',
        'Gujarati': 'ફોન સંપર્કોમાંથી આયાત કરો',
        'Hindi': 'फ़ोन संपर्कों से आयात करें',
        'Marathi': 'फोन संपर्कांतून आयात करा',
        'Punjabi': 'ਫੋਨ ਸੰਪਰਕਾਂ ਤੋਂ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'فون روابط سے درآمد کریں'
      });
  String get selectContacts => _t({
        'English': 'Select Contacts',
        'Gujarati': 'સંપર્કો પસંદ કરો',
        'Hindi': 'संपर्क चुनें',
        'Marathi': 'संपर्क निवडा',
        'Punjabi': 'ਸੰਪਰਕ ਚੁਣੋ',
        'Urdu': 'روابط منتخب کریں'
      });
  String get searchContacts => _t({
        'English': 'Search contacts',
        'Gujarati': 'સંપર્કો શોધો',
        'Hindi': 'संपर्क खोजें',
        'Marathi': 'संपर्क शोधा',
        'Punjabi': 'ਸੰਪਰਕ ਖੋਜੋ',
        'Urdu': 'روابط تلاش کریں'
      });
  String get noContactsFound => _t({
        'English': 'No contacts found',
        'Gujarati': 'કોઈ સંપર્કો મળ્યા નથી',
        'Hindi': 'कोई संपर्क नहीं मिला',
        'Marathi': 'कोणतेही संपर्क आढळले नाहीत',
        'Punjabi': 'ਕੋਈ ਸੰਪਰਕ ਨਹੀਂ ਮਿਲਿਆ',
        'Urdu': 'کوئی رابطہ نہیں ملا'
      });
  String get importCsvVcf => _t({
        'English': 'Import CSV/VCF',
        'Gujarati': 'CSV/VCF આયાત કરો',
        'Hindi': 'CSV/VCF आयात करें',
        'Marathi': 'CSV/VCF आयात करा',
        'Punjabi': 'CSV/VCF ਆਯਾਤ ਕਰੋ',
        'Urdu': 'سی ایس وی / وی سی ایف درآمد کریں'
      });
  String get importFromFile => _t({
        'English': 'Import from CSV or VCF file',
        'Gujarati': 'CSV અથવા VCF ફાઇલમાંથી આયાત કરો',
        'Hindi': 'CSV या VCF फ़ाइल से आयात करें',
        'Marathi': 'CSV किंवा VCF फाइलमधून आयात करा',
        'Punjabi': 'CSV ਜਾਂ VCF ਫਾਈਲ ਤੋਂ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'سی ایس وی یا وی سی ایف فائل سے درآمد کریں'
      });

  String get addAnyNote => _t({
        'English': 'Add any note',
        'Gujarati': 'કોઈપણ નોંધ ઉમેરો',
        'Hindi': 'कोई भी नोट जोड़ें',
        'Marathi': 'कोणतीही टीप जोडा',
        'Punjabi': 'ਕੋਈ ਵੀ ਨੋਟ ਜੋੜੋ',
        'Urdu': 'کوئی بھی نوٹ شامل کریں'
      });

  String guestsCount(int count) => _t({
        'English': '$count Guests',
        'Gujarati': '$count મહેમાનો',
        'Hindi': '$count अतिथि',
        'Marathi': '$count पाहुणे',
        'Punjabi': '$count ਮਹਿਮਾਨ',
        'Urdu': '$count مہمان',
      });

  // ─────────────────────────────────────────────────────────────
  // 🚀 ONBOARDING
  // ─────────────────────────────────────────────────────────────
  String get templates500 => _t({
        'English': '500+ Templates',
        'Gujarati': '૫૦૦+ ટેમ્પ્લેટ્સ',
        'Hindi': '500+ टेम्पलेट्स',
        'Marathi': '500+ टेम्पलेट्स',
        'Punjabi': '500+ ਟੈਂਪਲੇਟਸ',
        'Urdu': '500+ ٹیمپلیٹس'
      });
  String get easyCustomize => _t({
        'English': 'Easy customize',
        'Gujarati': 'સરળ કસ્ટમાઇઝ',
        'Hindi': 'आसान कस्टमाइज़',
        'Marathi': 'सुलभ कस्टमाइझ',
        'Punjabi': 'ਆਸਾਨ ਕਸਟਮਾਈਜ਼',
        'Urdu': 'آسان کسٹمائز'
      });
  String get shareInstantly => _t({
        'English': 'Share instantly',
        'Gujarati': 'તરત જ શેર કરો',
        'Hindi': 'तुरंत साझा करें',
        'Marathi': 'त्वरित शेअर करा',
        'Punjabi': 'ਤੁਰੰਤ ਸਾਂਝਾ ਕਰੋ',
        'Urdu': 'فوری شیئر کریں'
      });
  String get chooseAppLanguage => _t({
        'English': 'Choose App Language',
        'Gujarati': 'એપ ભાષા પસંદ કરો',
        'Hindi': 'ऐप भाषा चुनें',
        'Marathi': 'ऐप भाषा निवडा',
        'Punjabi': 'ਐਪ ਭਾਸ਼ਾ ਚੁਣੋ',
        'Urdu': 'ایپ کی زبان منتخب کریں'
      });
  String get selectPreferredLanguage => _t({
        'English': 'Select your preferred language to use the app.',
        'Gujarati': 'એપનો ઉપયોગ કરવા માટે તમારી પસંદગીની ભાષા પસંદ કરો.',
        'Hindi': 'ऐप का उपयोग करने के लिए अपनी पसंदीदा भाषा चुनें.',
        'Marathi': 'ऐप वापरण्यासाठी तुमची आवडती भाषा निवडा.',
        'Punjabi': 'ਐਪ ਦੀ ਵਰਤੋਂ ਕਰਨ ਲਈ ਆਪਣੀ ਪਸੰਦੀਦਾ ਭਾਸ਼ਾ ਚੁਣੋ।',
        'Urdu': 'ایپ استعمال کرنے کے لیے اپنی پسندیدہ زبان منتخب کریں۔'
      });
  String get customizeInvitationLanguages => _t({
        'English': 'Customize Invitation Languages',
        'Gujarati': 'આમંત્રણ ભાષાઓ કસ્ટમાઇઝ કરો',
        'Hindi': 'निमंत्रण भाषाएं कस्टमाइज़ करें',
        'Marathi': 'निमंत्रण भाषा सानुकूलित करा',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾਵਾਂ ਨੂੰ ਅਨੁਕੂਲਿਤ ਕਰੋ',
        'Urdu': 'دعوت نامہ کی زبانیں اپنی مرضی کے مطابق بنائیں'
      });
  String get chooseInvitationLanguagesDescription => _t({
        'English': 'Select the languages you want to use for your invitations.',
        'Gujarati':
            'તમારા આમંત્રણો માટે તમે જે ભાષાઓ વાપરવા માંગો છો તે પસંદ કરો.',
        'Hindi':
            'उन भाषाओं को चुनें जिन्हें आप अपने निमंत्रणों के लिए उपयोग करना चाहते हैं.',
        'Marathi': 'तुमच्या निमंत्रणासाठी तुम्हाला वापरायच्या भाषा निवडा.',
        'Punjabi': 'ਉਹ ਭਾਸ਼ਾਵਾਂ ਚੁਣੋ ਜੋ ਤੁਸੀਂ ਆਪਣੇ ਸੱਦੇ ਲਈ ਵਰਤਣਾ ਚਾਹੁੰਦੇ ਹੋ।',
        'Urdu':
            'وہ زبانیں منتخب کریں جو آپ اپنے دعوت ناموں کے لیے استعمال کرنا چاہتے ہیں۔'
      });
  String get createInvitationSteps => _t({
        'English': 'Create Invitation in 3 Steps',
        'Gujarati': '૩ સ્ટેપમાં આમંત્રણ બનાવો',
        'Hindi': '3 स्टेप में निमंत्रण बनाएं',
        'Marathi': '३ पायऱ्यांत निमंत्रण बनवा',
        'Punjabi': '3 ਕਦਮਾਂ ਵਿੱਚ ਸੱਦਾ ਬਣਾਓ',
        'Urdu': '3 مراحل میں دعوت نامہ بنائیں'
      });
  String get exploreCategoriesDescription => _t({
        'English': 'Explore various categories of invitations.',
        'Gujarati': 'આમંત્રણોની વિવિધ શ્રેણીઓ શોધો.',
        'Hindi': 'निमंत्रण की विभिन्न श्रेणियों का पता लगाएं.',
        'Marathi': 'निमंत्रणांच्या विविध श्रेणी पहा.',
        'Punjabi': 'ਸੱਦੇ ਦੀਆਂ ਵੱਖ-ਵੱਖ ਸ਼੍ਰੇਣੀਆਂ ਦੀ ਪੜਚੋਲ ਕਰੋ।',
        'Urdu': 'دعوت ناموں کے مختلف زمروں کو دریافت کریں۔'
      });
  String get chooseTemplate => _t({
        'English': 'Choose Template',
        'Gujarati': 'ટેમ્પ્લેટ પસંદ કરો',
        'Hindi': 'टेम्पलेट चुनें',
        'Marathi': 'टेम्पलेट निवडा',
        'Punjabi': 'ਟੈਂਪਲੇਟ ਚੁਣੋ',
        'Urdu': 'ٹیمپلیٹ منتخب کریں'
      });
  String get chooseTemplateDescription => _t({
        'English': 'Pick your favorite design from hundreds of templates.',
        'Gujarati': 'સેંકડો ટેમ્પ્લેટ્સમાંથી તમારી મનપસંદ ડિઝાઇન પસંદ કરો.',
        'Hindi': 'सैकड़ों टेम्पलेट्स में से अपना पसंदीदा डिझाइन चुनें.',
        'Marathi': 'शंभर टेम्पलेट्समधून तुमची आवडती डिझाइन निवडा.',
        'Punjabi': 'ਸੈਂਕੜੇ ਟੈਂਪਲੇਟਾਂ ਵਿੱਚੋਂ ਆਪਣਾ ਮਨਪਸੰਦ ਡਿਜ਼ਾਈਨ ਚੁਣੋ।',
        'Urdu': 'سینکڑوں ٹیمپلیٹس میں سے اپنا پسندیدہ ڈیزائن منتخب کریں۔'
      });
  String get customizeCard => _t({
        'English': 'Customize Card',
        'Gujarati': 'કાર્ડ કસ્ટમાઇઝ કરો',
        'Hindi': 'कार्ड कस्टमाइज़ करें',
        'Marathi': 'कार्ड सानुकूलित करा',
        'Punjabi': 'ਕਾਰਡ ਨੂੰ ਅਨੁਕੂਲਿਤ ਕਰੋ',
        'Urdu': 'کارڈ کو اپنی مرضی کے مطابق بنائیں'
      });
  String get customizeCardDescription => _t({
        'English': 'Add your details and edit colors, fonts, and more.',
        'Gujarati': 'તમારી વિગતો ઉમેરો અને રંગો, ફોન્ટ્સ અને વધુ સંપાદિત કરો.',
        'Hindi': 'अपना विवरण जोड़ें और रंग, फ़ॉन्ट और बहुत कुछ संपादित करें.',
        'Marathi':
            'तुमचे तपशील जोडा आणि रंग, फॉन्ट आणि बरेच काही संपादित करा.',
        'Punjabi':
            'ਆਪਣੇ ਵੇਰਵੇ ਸ਼ਾਮਲ ਕਰੋ ਅਤੇ ਰੰਗ, ਫੋਂਟ ਅਤੇ ਹੋਰ ਬਹੁਤ ਕੁਝ ਸੰਪਾਦਿਤ ਕਰੋ।',
        'Urdu':
            'اپنی تفصیلات شامل کریں اور رنگ، فونٹ اور بہت کچھ میں ترمیم کریں۔'
      });
  String get downloadShareDescription => _t({
        'English': 'Download and share with your friends and family.',
        'Gujarati': 'ડાઉનલોડ કરો અને તમારા મિત્રો અને પરિવાર સાથે શેર કરો.',
        'Hindi': 'डाउनलोड करें और अपने दोस्तों और परिवार के साथ साझा करें.',
        'Marathi': 'डाउनलोड करा आणि तुमच्या मित्र आणि कुटुंबासोबत शेयर करा.',
        'Punjabi': 'ਡਾਊਨਲੋਡ ਕਰੋ ਅਤੇ ਆਪਣੇ ਦੋਸਤਾਂ ਅਤੇ ਪਰਿਵਾਰ ਨਾਲ ਸਾਂਝਾ ਕਰੋ।',
        'Urdu': 'ڈاؤن لوڈ کریں اور اپنے دوستوں اور اہل خانہ کے ساتھ شیئر کریں۔'
      });

  // ─────────────────────────────────────────────────────────────
  // 🏠 HOME & SEARCH
  // ─────────────────────────────────────────────────────────────
  String get noTemplatesFound => _t({
        'English': 'No templates found',
        'Gujarati': 'કોઈ ટેમ્પ્લેટ મળ્યા નથી',
        'Hindi': 'कोई टेम्पलेट नहीं मिला',
        'Marathi': 'कोणतेही टेम्पलेट सापडले नाही',
        'Punjabi': 'ਕੋਈ ਟੈਂਪਲੇਟ ਨਹੀਂ ਮਿਲਿਆ',
        'Urdu': 'کوئی ٹیمپلیٹ نہیں ملا'
      });
  String get searchResults => _t({
        'English': 'Search Results',
        'Gujarati': 'શોધ પરિણામો',
        'Hindi': 'खोज परिणाम',
        'Marathi': 'शोध निकाल',
        'Punjabi': 'ਖੋਜ ਦੇ ਨਤੀਜੇ',
        'Urdu': 'تلاش کے نتائج'
      });
  String get deleteDesign => _t({
        'English': 'Delete Design',
        'Gujarati': 'ડિઝાઇન કાઢી નાખો',
        'Hindi': 'डिझाइन हटाएं',
        'Marathi': 'डिझाइन काढा',
        'Punjabi': 'ਡਿਜ਼ਾਈਨ ਹਟਾਓ',
        'Urdu': 'ڈیزائن حذف کریں'
      });
  String get deleteDesignConfirm => _t({
        'English': 'Are you sure you want to delete this design?',
        'Gujarati': 'શું તમે ખરેખર આ ડિઝાઇન કાઢી નાખવા માંગો છો?',
        'Hindi': 'क्या आप वाकई इस डिझाइन को हटाना चाहते हैं?',
        'Marathi': 'तुम्हाला खरोखर ही डिझाइन काढायची आहे?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨੀ ਤੌਰ ਤੇ ਇਸ ਡਿਜ਼ਾਈਨ ਨੂੰ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی اس ڈیزائن کو حذف کرنا چاہتے ہیں؟'
      });
  String get designDeleted => _t({
        'English': 'Design deleted successfully',
        'Gujarati': 'ડિઝાઇન સફળતાપૂર્વક કાઢી નાખવામાં આવી',
        'Hindi': 'डिझाइन सफलतापूर्वक हटा दी गई',
        'Marathi': 'डिझाइन यशस्वीरित्या काढली',
        'Punjabi': 'ਡਿਜ਼ਾਈਨ ਸਫਲਤਾਪੂਰਵਕ ਹਟਾ ਦਿੱਤਾ ਗਿਆ',
        'Urdu': 'ڈیزائن کامیابی کے ساتھ حذف ہو گیا'
      });

  // ─────────────────────────────────────────────────────────────
  // ✍️ EDITOR
  // ─────────────────────────────────────────────────────────────
  String get saveDraft => _t({
        'English': 'Save Draft',
        'Gujarati': 'ડ્રાફ્ટ સાચવો',
        'Hindi': 'ड्राफ्ट सहेजें',
        'Marathi': 'मसुदा जतन करा',
        'Punjabi': 'ਡਰਾਫਟ ਸੁਰੱਖਿਅਤ ਕਰੋ',
        'Urdu': 'ڈرافٹ محفوظ کریں'
      });
  String get unsavedChanges => _t({
        'English': 'You have made unsaved changes to this design. Are you sure?',
        'Gujarati': 'તમે આ ડિઝાઇનમાં સાચવ્યા વગરના ફેરફારો કર્યા છે. શું તમને ખાતરી છે?',
        'Hindi': 'आपने इस डिज़ाइन में बिना सहेजे गए बदलाव किए हैं। क्या आप वाकई सुनिश्चित हैं?',
        'Marathi': 'तुम्ही या डिझाइनमध्ये जतन न केलेले बदल केले आहेत. तुमची खात्री आहे का?',
        'Punjabi': 'ਤੁਸੀਂ ਇਸ ਡਿਜ਼ਾਈਨ ਵਿੱਚ ਅਣ-ਸੁਰੱਖਿਅਤ ਤਬਦੀਲੀਆਂ ਕੀਤੀਆਂ ਹਨ। ਕੀ ਤੁਹਾਨੂੰ ਯਕੀਨ ਹੈ?',
        'Urdu': 'آپ نے اس ڈیزائن میں غیر محفوظ تبدیلیاں کی ہیں۔ کیا آپ کو یقین ہے؟',
      });
  String get discard => _t({
        'English': 'Discard',
        'Gujarati': 'રદ કરો',
        'Hindi': 'त्यागें',
        'Marathi': 'काढून टाका',
        'Punjabi': 'ਰੱਦ ਕਰੋ',
        'Urdu': 'خارج کریں'
      });
  String get draftSaved => _t({
        'English': 'Draft saved successfully',
        'Gujarati': 'ડ્રાફ્ટ સફળતાપૂર્વક સાચવવામાં આવ્યો',
        'Hindi': 'ड्राफ्ट सफलतापूर्वक सहेजा गया',
        'Marathi': 'मसुदा यशस्वीरित्या जतन केला',
        'Punjabi': 'ਡਰਾਫਟ ਸਫਲਤਾਪੂਰਵਕ ਸੁਰੱਖਿਅਤ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'ڈرافٹ کامیابی کے ساتھ محفوظ ہو گیا'
      });

  // ─────────────────────────────────────────────────────────────
  // 🌟 PROFILE & RATING
  // ─────────────────────────────────────────────────────────────
  String get thankYouRating => _t({
        'English': 'Thank you for your rating!',
        'Gujarati': 'તમારા રેટિંગ માટે આભાર!',
        'Hindi': 'आपकी रेटिंग के लिए धन्यवाद!',
        'Marathi': 'तुमच्या रेटिंगसाठी धन्यवाद!',
        'Punjabi': 'ਤੁਹਾਡੀ ਰੇਟਿੰਗ ਲਈ ਧੰਨਵਾਦ!',
        'Urdu': 'آپ کی درجہ بندی کے لیے شکریہ!'
      });
  String get pleaseEnterName => _t({
        'English': 'Please enter your name',
        'Gujarati': 'મહેરબાની કરીને તમારું નામ દાખલ કરો',
        'Hindi': 'कृपया अपना नाम दर्ज करें',
        'Marathi': 'कृपया तुमचे नाव भरा',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਆਪਣਾ ਨਾਮ ਦਰਜ ਕਰੋ',
        'Urdu': 'براہ کرم اپنا نام درج کریں'
      });
  String get pleaseEnterPhone => _t({
        'English': 'Please enter a valid 10-digit phone number',
        'Gujarati': 'મહેરબાની કરીને માન્ય ૧૦-આંકડાનો ફોન નંબર દાખલ કરો',
        'Hindi': 'कृपया एक वैध 10-अंकीय फ़ोन नंबर दर्ज करें',
        'Marathi': 'कृपया १० अंकी वैध फोन नंबर भरा',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10-ਅੰਕੀ ਫ਼ੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Urdu': 'براہ کرم 10 ہندسوں کا درست فون نمبر درج کریں'
      });
  String get pleaseEnterEmail => _t({
        'English': 'Please enter a valid email address',
        'Gujarati': 'મહેરબાની કરીને માન્ય ઈમેલ એડ્રેસ દાખલ કરો',
        'Hindi': 'कृपया एक वैध ईमेल पता दर्ज करें',
        'Marathi': 'कृपया वैध ईमेल पत्ता भरा',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ ਈਮੇਲ ਪਤਾ ਦਰਜ ਕਰੋ',
        'Urdu': 'براہ کرم ایک درست ای میل پتہ درج کریں'
      });

  // ─────────────────────────────────────────────────────────────
  // 🕉 INVITATION HELPERS
  // ─────────────────────────────────────────────────────────────
  String dateLabelFor(String lang) => _tFor({
        'English': 'Date',
        'Gujarati': 'તારીખ',
        'Hindi': 'तारीख',
        'Marathi': 'तारीख',
        'Punjabi': 'ਤਾਰੀਖ',
        'Urdu': 'تاریخ'
      }, lang);
  String timeLabelFor(String lang) => _tFor({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'समय',
        'Marathi': 'वेळ',
        'Punjabi': 'ਸਮਾਂ',
        'Urdu': 'وقت'
      }, lang);

  // ─────────────────────────────────────────────────────────────
  // 🔔 NOTIFICATIONS & FEEDBACK
  // ─────────────────────────────────────────────────────────────
  String shareDesignText(String name) => _t({
        'English': 'Check out my design: $name',
        'Gujarati': 'મારી ડિઝાઇન જુઓ: $name',
        'Hindi': 'मेरी डिझाइन देखें: $name',
        'Marathi': 'माझी डिझाइन पहा: $name',
        'Punjabi': 'ਮੇਰਾ ਡਿਜ਼ਾਈਨ ਦੇਖੋ: $name',
        'Urdu': '$name :میرا ڈیزائن دیکھیں',
      });
  String get shareAppText => _t({
        'English':
            'Check out Nimantran - Create beautiful wedding invitations! Download now.',
        'Gujarati':
            'આમંત્રણ જુઓ - સુંદર લગ્ન આમંત્રણો બનાવો! હમણાં ડાઉનલોડ કરો.',
        'Hindi':
            'निमंत्रण देखें - सुंदर शादी के निमंत्रण बनाएं! अभी डाउनलोड करें.',
        'Marathi':
            'निमंत्रण पहा - सुंदर लग्न निमंत्रण बनवा! आत्ताच डाउनलोड करा.',
        'Punjabi': 'ਨਿਮੰਤਰਨ ਦੇਖੋ - ਸੁੰਦਰ ਵਿਆਹ ਦੇ ਸੱਦੇ ਬਣਾਓ! ਹੁਣੇ ਡਾਊਨਲੋਡ ਕਰੋ।',
        'Urdu':
            '!نمنترک دیکھیں - شادی کے خوبصورت دعوت نامے بنائیں! ابھی ڈاؤن لوڈ کریں',
      });

  // ─────────────────────────────────────────────────────────────
  // 🧩 ADDED TRANSLATION GETTERS
  // ─────────────────────────────────────────────────────────────
  String get accountRemoved => _t({
        'English': 'Account deleted successfully',
        'Gujarati': 'એકાઉન્ટ સફળતાપૂર્વક કાઢી નાખવામાં આવ્યું',
        'Hindi': 'खाता सफलतापूर्वक हटा दिया गया',
        'Marathi': 'खाते यशस्वीरित्या हटवले गेले',
        'Punjabi': 'ਖਾਤਾ ਸਫਲਤਾਪੂਰਵਕ ਹਟਾ ਦਿੱਤਾ ਗਿਆ',
        'Urdu': 'اکاؤنٹ کامیابی کے ساتھ حذف کر دیا گیا'
  });

  String get accountStatus => _t({
        'English': 'Account Status',
        'Gujarati': 'એકાઉન્ટ સ્થિતિ',
        'Hindi': 'खाता स्थिति',
        'Marathi': 'खाते स्थिती',
        'Punjabi': 'ਖਾਤਾ ਸਥਿਤੀ',
        'Urdu': 'اکاؤنٹ کی حیثیت'
  });


  String get signInToContinue => _t({
        'English': 'Sign in to continue creating beautiful\ninvitations',
        'Gujarati': 'સુંદર આમંત્રણો બનાવવાનું ચાલુ રાખવા માટે સાઇન ઇન કરો',
        'Hindi': 'सुंदर निमंत्रण बनाना जारी रखने के लिए साइन इन करें',
        'Marathi': 'सुंदर निमंत्रण तयार करणे सुरू રાખવા માટે साइन इन करा',
        'Punjabi': 'ਸੁੰਦਰ ਸੱਦਾ ਪੱਤਰ ਬਣਾਉਣਾ ਜਾਰੀ ਰੱਖਣ ਲਈ ਸਾਈਨ ਇਨ ਕਰੋ',
        'Urdu': 'خوبصورت دعوت نامے بنانا جاری رکھنے کے لیے سائن ان کریں'
      });

  String get chooseYourAccount => _t({
        'English': 'Choose your account',
        'Gujarati': 'તમારું એકાઉન્ટ પસંદ કરો',
        'Hindi': 'अपना खाता चुनें',
        'Marathi': 'तुमचे खाते निवडा',
        'Punjabi': 'ਆਪਣਾ ਖਾਤਾ ਚੁਣੋ',
        'Urdu': 'اپنا اکاؤنٹ منتخب کریں'
      });

  String get removeAccount => _t({
        'English': 'Remove Account',
        'Gujarati': 'એકાઉન્ટ દૂર કરો',
        'Hindi': 'खाता हटाएं',
        'Marathi': 'खाते काढा',
        'Punjabi': 'ਖਾਤਾ ਹਟਾਓ',
        'Urdu': 'اکاؤنٹ ہٹائیں'
      });

  String get logInOrSignUp => _t({
        'English': 'Log in or Sign up',
        'Gujarati': 'લોગિન અથવા સાઇનઅપ',
        'Hindi': 'लॉगिन या साइनअप',
        'Marathi': 'लॉगिन किंवा साइनअप',
        'Punjabi': 'ਲੌਗਇਨ ਜਾਂ ਸਾਈਨ ਅੱਪ',
        'Urdu': 'لاگ ان یا سائن اپ'
      });

  String get enterPhoneNumber => _t({
        'English': 'Enter Your Phone Number',
        'Gujarati': 'તમારો ફોન નંબર દાખલ કરો',
        'Hindi': 'अपना फोन नंबर दर्ज करें',
        'Marathi': 'तुमचा फोन नंबर प्रविष्ट करा',
        'Punjabi': 'ਆਪਣਾ ਫੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Urdu': 'اپنا فون نمبر درج کریں'
      });

  String get enter10DigitNumber => _t({
        'English': 'Enter 10-digit number',
        'Gujarati': '૧૦-આંકડાનો નંબર દાખલ કરો',
        'Hindi': '१०-अंकीय नंबर दर्ज करें',
        'Marathi': '१०-अंकी क्रमांक प्रविष्ट करा',
        'Punjabi': '10-ਅੰਕਾਂ ਦਾ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Urdu': '10 ہندسوں کا نمبر درج کریں'
      });

  String get weWillSendVerificationCode => _t({
        'English': "We'll send a code to verify your account",
        'Gujarati': 'અમે તમારા એકાઉન્ટની ચકાસણી કરવા માટે કોડ મોકલીશું',
        'Hindi': 'हम आपके खाते को सत्यापित करने के लिए एक कोड भेजेंगे',
        'Marathi': 'आम्ही तुमचे खाते सत्यापित करण्यासाठी कोड पाठवू',
        'Punjabi': 'ਅਸੀਂ ਤੁਹਾਡੇ ਖਾਤੇ ਦੀ ਪੁਸ਼ਟੀ ਕਰਨ ਲਈ ਇੱਕ ਕੋਡ ਭੇਜਾਂਗੇ',
        'Urdu': 'ہم آپ کے اکاؤنٹ کی تصدیق کے لیے ایک کوڈ بھیجیں گے'
      });

  String get secureAndPrivate => _t({
        'English': 'Secure & Private',
        'Gujarati': 'સુરક્ષિત અને ખાનગી',
        'Hindi': 'सुरक्षित और निजी',
        'Marathi': 'सुरक्षित आणि खाजगी',
        'Punjabi': 'ਸੁਰੱਖਿਅਤ ਅਤੇ ਨਿੱਜੀ',
        'Urdu': 'محفوظ اور نجی'
      });

  String get phoneEncryptionDisclaimer => _t({
        'English': 'Your phone number is encrypted and used only for verification.',
        'Gujarati': 'તમારો ફોન નંબર એન્ક્રિપ્ટ થયેલ છે અને તેનો ઉપયોગ ફક્ત ચકાસણી માટે થાય છે.',
        'Hindi': 'आपका फोन नंबर एन्क्रिप्टेड है और इसका उपयोग केवल सत्यापन के लिए किया जाता है।',
        'Marathi': 'तुमचा फोन नंबर एनक्रिप्ट केलेला आहे आणि फक्त पडताळणीसाठी वापरला जातो.',
        'Punjabi': 'ਤੁਹਾਡਾ ਫੋਨ ਨੰਬਰ ਐਨਕ੍ਰਿਪਟਡ ਹੈ ਅਤੇ ਸਿਰਫ ਪੁਸ਼ਟੀਕਰਨ ਲਈ ਵਰਤਿਆ ਜਾਂਦਾ ਹੈ।',
        'Urdu': 'آپ کا فون نمبر انکرپٹڈ ہے اور صرف تصدیق کے لیے استعمال ہوتا ہے۔'
      });

  String get continueButton => _t({
        'English': 'Continue',
        'Gujarati': 'ચાલુ રાખો',
        'Hindi': 'जारी रखें',
        'Marathi': 'सुरू ठेवा',
        'Punjabi': 'ਜਾਰੀ ਰੱਖੋ',
        'Urdu': 'جاری رکھیں'
      });

  String get orLoginWith => _t({
        'English': 'Or login with',
        'Gujarati': 'અથવા આનાથી લોગિન કરો',
        'Hindi': 'या इसके साथ लॉगिन करें',
        'Marathi': 'किंवा याद्वारे लॉगिन करा',
        'Punjabi': 'ਜਾਂ ਇਸ ਨਾਲ ਲੌਗਇਨ ਕਰੋ',
        'Urdu': 'یا لاگ ان کریں'
      });

  String get returningUserDisclaimer => _t({
        'English': 'By continuing, you agree to our Terms of Service, Privacy Policy, and Content Policy.',
        'Gujarati': 'આગળ વધીને, તમે અમારી સેવાની શરતો, ગોપનીયતા નીતિ અને સામગ્રી નીતિ સાથે સંમત થાઓ છો.',
        'Hindi': 'आगे बढ़कर, आप हमारी सेवा की शर्तों, गोपनीयता नीति और सामग्री नीति से सहमत होते हैं।',
        'Marathi': 'सुरू ठेवून, आपण आमच्या सेवा अटी, गोपनीयता धोरण आणि सामग्री धोरणाशी सहमत आहात.',
        'Punjabi': 'ਜਾਰੀ ਰੱਖ ਕੇ, ਤੁਸੀਂ ਸਾਡੀ ਸੇਵਾ ਦੀਆਂ ਸ਼ਰਤਾਂ, ਗੋਪਨੀਯਤਾ નીતિ ਅਤੇ ਵਿਸ਼ਾ-ਵਸਤੂ ਨੀਤੀ ਨਾਲ ਸਹਿਮਤ ਹੁੰਦੇ ਹੋ।',
        'Urdu': 'جاری رکھ کر، آپ ہماری سروس کی شرائط، رازداری کی پالیسی اور مواد کی پالیسی سے اتفاق کرتے ہیں۔'
      });

  String get newUserDisclaimer => _t({
        'English': 'By proceeding, you agree to receive SMS messages for verification. Standard rates may apply.',
        'Gujarati': 'આગળ વધીને, તમે ચકાસણી માટે એસએમએસ સંદેશા પ્રાપ્ત કરવા માટે સંમત થાઓ છો. સામાન્ય દર લાગુ થઈ શકે છે.',
        'Hindi': 'आगे बढ़कर, आप सत्यापन के लिए एसएमएस संदेश प्राप्त करने के लिए सहमत होते हैं। सामान्य दरें लागू हो सकती हैं।',
        'Marathi': 'पुढे चालू ठेवून, आपण पडताळणीसाठी एसएमएस संदेश प्राप्त करण्यास सहमत आहात. सामान्य दर लागू होऊ शकतात.',
        'Punjabi': 'ਅੱਗੇ ਵਧ ਕੇ, ਤੁਸੀਂ ਪੁਸ਼ਟੀਕਰਨ ਲਈ ਐਸਐਮਐਸ ਸੰਦੇਸ਼ ਪ੍ਰਾਪਤ ਕਰਨ ਲਈ ਸਹਿਮਤ ਹੁੰਦੇ ਹੋ। ਆਮ ਦਰਾਂ ਲਾਗੂ ਹੋ ਸਕਦੀਆਂ ਹਨ।',
        'Urdu': 'آگے بڑھ کر، آپ تصدیق کے لیے ایس ایم ایس پیغامات موصول کرنے سے اتفاق کرتے ہیں۔ عام چارجز لاگو ہو سکتے ہیں۔'
      });

  String get weSentAnEmail => _t({
        'English': 'We just sent an Email',
        'Gujarati': 'અમે હમણાં જ ઈમેલ મોકલ્યો છે',
        'Hindi': 'हमने अभी एक ईमेल भेजा है',
        'Marathi': 'आम्ही नुकताच एक ईमेल पाठवला आहे',
        'Punjabi': 'ਅਸੀਂ ਹੁਣੇ ਹੀ ਇੱਕ ਈਮੇਲ ਭੇਜੀ ਹੈ',
        'Urdu': 'ہم نے ابھی ایک ای میل بھیجی ہے'
      });

  String get weSentAWhatsappMessage => _t({
        'English': 'We just sent a WhatsApp message',
        'Gujarati': 'અમે હમણાં જ એક વોટ્સએપ સંદેશ મોકલ્યો છે',
        'Hindi': 'हमने अभी एक व्हाट्सएप संदेश भेजा है',
        'Marathi': 'आम्ही नुकताच एक व्हॉट्सॲप संदेश पाठवला आहे',
        'Punjabi': 'ਅਸੀਂ ਹੁਣੇ ਹੀ ਇੱਕ ਵਟਸਐਪ ਸੰਦੇਸ਼ ਭੇਜਿਆ ਹੈ',
        'Urdu': 'ہم نے ابھی ایک واٹس ایپ پیغام بھیجا ہے'
      });

  String get weSentAnSms => _t({
        'English': 'We just sent an SMS',
        'Gujarati': 'અમે હમણાં જ એક એસએમએસ મોકલ્યો છે',
        'Hindi': 'हमने अभी एक एसएमएस भेजा है',
        'Marathi': 'आम्ही नुकताच एक एसएमएस पाठवला आहे',
        'Punjabi': 'ਅਸੀਂ ਹੁਣੇ ਹੀ ਇੱਕ ਐਸਐਮਐਸ ਭੇਜਿਆ ਹੈ',
        'Urdu': 'ہم نے ابھی ایک ایس ایم ایس بھیجا ہے'
      });

  String enterCodeSentTo(String target) => _t({
        'English': 'Enter the code sent to $target',
        'Gujarati': 'આના પર મોકલેલો કોડ દાખલ કરો: $target',
        'Hindi': '$target पर भेजा गया कोड दर्ज करें',
        'Marathi': '$target वर पाठवलेला कोड प्रविष्ट करा',
        'Punjabi': '$target ਤੇ ਭੇਜਿਆ ਕੋਡ ਦਰਜ ਕਰੋ',
        'Urdu': '$target پر بھیجا گیا کوڈ درج کریں'
      });

  String get verificationCode => _t({
        'English': 'Verification Code',
        'Gujarati': 'ચકાસણી કોડ',
        'Hindi': 'सत्यापन कोड',
        'Marathi': 'पडताळणी कोड',
        'Punjabi': 'ਪੁਸ਼ਟੀਕਰਨ ਕੋਡ',
        'Urdu': 'تصدیقی کوڈ'
      });

  String resendIn(String timer) => _t({
        'English': 'Resend in $timer',
        'Gujarati': '$timer માં ફરી મોકલો',
        'Hindi': '$timer में पुनः भेजें',
        'Marathi': '$timer मध्ये पुन्हा पाठवा',
        'Punjabi': '$timer ਵਿੱਚ ਦੁਬਾਰਾ ਭੇਜੋ',
        'Urdu': '$timer میں دوبارہ بھیجیں'
      });

  String get readyToResend => _t({
        'English': 'Ready to resend',
        'Gujarati': 'ફરીથી મોકલવા માટે તૈયાર',
        'Hindi': 'पुनः भेजने के लिए तैयार',
        'Marathi': 'पुन्हा पाठवण्यासाठी तयार',
        'Punjabi': 'ਦੁਬਾਰਾ ਭੇਜਣ ਲਈ ਤਿਆਰ',
        'Urdu': 'دوبارہ بھیجنے کے لیے تیار'
      });

  String get alreadyHaveAccountLogin => _t({
        'English': 'Already have an account? Log in',
        'Gujarati': 'પહેલેથી જ એકાઉન્ટ છે? લોગિન કરો',
        'Hindi': 'पहले से ही खाता है? लॉग इन करें',
        'Marathi': 'आधीच खाते आहे का? लॉग इन करा',
        'Punjabi': 'ਪਹਿਲਾਂ ਹੀ ਖਾਤਾ ਹੈ? ਲੌਗਇਨ ਕਰੋ',
        'Urdu': 'پہلے سے ہی اکاؤنٹ ہے؟ لاگ ان کریں'
      });

  String get didntReceiveCode => _t({
        'English': "Didn't receive code?",
        'Gujarati': 'કોડ નથી મળ્યો?',
        'Hindi': 'कोड नहीं मिला?',
        'Marathi': 'कोड मिळाला नाही?',
        'Punjabi': 'ਕੋਡ ਨਹੀਂ ਮਿਲਿਆ?',
        'Urdu': 'کوڈ موصول نہیں ہوا؟'
      });

  String get verifyAndContinue => _t({
        'English': 'Verify & Continue',
        'Gujarati': 'ચકાસો અને આગળ વધો',
        'Hindi': 'सत्यापित करें और जारी रखें',
        'Marathi': 'पडताळणी करा आणि सुरू ठेवा',
        'Punjabi': 'ਤਸਦੀਕ ਕਰੋ ਅਤੇ ਜਾਰੀ ਰੱਖੋ',
        'Urdu': 'تصدیق کریں اور جاری رکھیں'
      });

  String get amantranPremium => _t({
        'English': 'Amantran Premium',
        'Gujarati': 'આમંત્રણ પ્રીમિયમ',
        'Hindi': 'आमंत्रण प्रीमियम',
        'Marathi': 'आमंत्रण प्रीमियम',
        'Punjabi': 'ਆਮੰਤਰਨ પ્રીમીਅਮ',
        'Urdu': 'نمنترک پریمیم'
  });

  String get autoRenewDisabled => _t({
        'English': 'Auto-renew disabled successfully',
        'Gujarati': 'ઓટો-રીન્યુ સફળતાપૂર્વક બંધ કર્યું',
        'Hindi': 'ऑटो-रिन्यू सफलतापूर्वक अक्षम किया गया',
        'Marathi': 'ऑटो-रिन्यू यशस्वीरित्या बंद केले',
        'Punjabi': 'ਆਟੋ-ਰੀਨਿਊ ਸਫਲਤਾਪੂਰਵਕ ਅਸਮਰੱਥ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'خودکار تجدید کامیابی سے بند کر دی گئی'
  });

  String get autoRenewOff => _t({
        'English': 'Auto-renew is off',
        'Gujarati': 'ઓટો-રીન્યુ બંધ છે',
        'Hindi': 'ऑटो-रिन्यू बंद है',
        'Marathi': 'ऑटो-रिन्यू बंद आहे',
        'Punjabi': 'ਆਟੋ-ਰੀਨਿਊ ਬੰਦ ਹੈ',
        'Urdu': 'خودکار تجدید بند ہے'
  });

  String get cancelSubscription => _t({
        'English': 'Cancel Subscription',
        'Gujarati': 'સબ્સ્ક્રિપ્શન રદ કરો',
        'Hindi': 'सदस्यता रद्द करें',
        'Marathi': 'सदस्यता रद्द करा',
        'Punjabi': 'ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਰੱਦ ਕਰੋ',
        'Urdu': 'سبسکرپشن منسوخ کریں'
  });

  String get cancelSubscriptionMessage => _t({
        'English': 'Are you sure you want to cancel your subscription?',
        'Gujarati': 'શું તમે ખરેખર તમારું સબ્સ્ક્રિપ્શન રદ કરવા માંગો છો?',
        'Hindi': 'क्या आप वाकई अपनी सदस्यता रद्द करना चाहते हैं?',
        'Marathi': 'तुम्हाला खात्री आहे का की तुम्ही तुमची सदस्यता रद्द करू इच्छिता?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨਨ ਆਪਣੀ ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਰੱਦ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی اپنی سبسکرپشن منسوخ کرنا چاہتے ہیں؟'
  });

  String get cardNumber => _t({
        'English': 'Card Number',
        'Gujarati': 'કાર્ડ નંબર',
        'Hindi': 'कार्ड संख्या',
        'Marathi': 'कार्ड नंबर',
        'Punjabi': 'ਕਾਰਡ ਨੰਬਰ',
        'Urdu': 'کارڈ نمبر'
  });

  String get chooseTemplateSubtitle => _t({
        'English': 'Choose a design for your occasion',
        'Gujarati': 'તમારા પ્રસંગ માટે એક ડિઝાઇન પસંદ કરો',
        'Hindi': 'अपने अवसर के लिए एक डिज़ाइन चुनें',
        'Marathi': 'तुमच्या प्रसंगासाठी डिझाईन निवडा',
        'Punjabi': 'ਆਪਣੇ ਮੌਕੇ ਲਈ ਇੱਕ ਡਿਜ਼ਾਈਨ ਚੁਣੋ',
        'Urdu': 'اپنے موقع کے لیے ایک ڈیزائن منتخب کریں'
  });

  String get confirmCancel => _t({
        'English': 'Yes, Cancel',
        'Gujarati': 'હા, રદ કરો',
        'Hindi': 'हाँ, रद्द करें',
        'Marathi': 'होय, रद्द करा',
        'Punjabi': 'ਹਾਂ, ਰੱਦ ਕਰੋ',
        'Urdu': 'ہاں، منسوخ کریں'
  });

  String get contactSupport => _t({
        'English': 'Contact Support',
        'Gujarati': 'સપોર્ટનો સંપર્ક કરો',
        'Hindi': 'सपोर्ट से संपर्क करें',
        'Marathi': 'सपोर्टशी संपर्क साधा',
        'Punjabi': 'ਸਹਾਇਤਾ ਨਾਲ ਸੰਪਰਕ ਕਰੋ',
        'Urdu': 'سپورٹ سے رابطہ کریں'
  });

  String get contactSupportMessage => _t({
        'English': 'Your account has been suspended. Please contact support.',
        'Gujarati': 'તમારું એકાઉન્ટ સ્થગિત કરવામાં આવ્યું છે. મહેરબાની કરીને સપોર્ટનો સંપર્ક કરો.',
        'Hindi': 'आपका खाता निलंबित कर दिया गया है। कृपया सपोर्ट से संपर्क करें।',
        'Marathi': 'तुमचे खाते निलंबित केले गेले आहे. कृपया सपोर्टशी संपर्क साधा.',
        'Punjabi': 'ਤੁਹਾਡਾ ਖਾਤਾ ਮੁਅੱਤਲ ਕਰ ਦਿੱਤਾ ਗਿਆ ਹੈ। ਕਿਰਪา ਕਰਕੇ ਸਹਾਇਤਾ ਨਾਲ ਸੰਪਰਕ ਕਰੋ।',
        'Urdu': 'آپ کا اکاؤنٹ معطل کر دیا گیا ہے۔ براہ کرم سپورٹ سے رابطہ کریں۔'
  });

  String get contactingPaymentSandbox => _t({
        'English': 'Contacting payment sandbox...',
        'Gujarati': 'પેમેન્ટ સેન્ડબોક્સનો સંપર્ક કરી રહ્યા છીએ...',
        'Hindi': 'पेमेंट सैंडबॉक्स से संपर्क किया जा रहा है...',
        'Marathi': 'पेमेंट सँडबॉक्सशी संपर्क साधत आहे...',
        'Punjabi': 'ਭੁਗਤਾਨ ਸੈਂਡਬਾਕਸ ਨਾਲ ਸੰਪਰਕ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ...',
        'Urdu': 'ادائیگی کے سینڈ باکس سے رابطہ کیا جا رہا ہے...'
  });

  String get createInvitationIn3Steps => _t({
        'English': '''Create Your Invitation
in 3 Steps''',
        'Gujarati': '''તમારું આમંત્રણ
3 પગલામાં બનાવો''',
        'Hindi': '''अपना निमंत्रण
3 चरणों में बनाएं''',
        'Marathi': '''तुमचे निमंत्रण
३ पायऱ्यांत बनवा''',
        'Punjabi': '''ਆਪਣਾ ਸੱਦਾ
3 ਪੜਾਵਾਂ ਵਿੱਚ ਬਣਾਓ''',
        'Urdu': '''اپنا دعوت نامہ
3 مراحل میں بنائیں'''
  });

  String get creditCard => _t({
        'English': 'Credit Card',
        'Gujarati': 'ક્રેડિટ કાર્ડ',
        'Hindi': 'क्रेडिट कार्ड',
        'Marathi': 'क्रेडिट कार्ड',
        'Punjabi': 'ਕ੍ਰੈਡਿਟ ਕਾਰਡ',
        'Urdu': 'کریڈٹ کارڈ'
  });

  String get customizeCardSubtitle => _t({
        'English': 'Edit text and add your details',
        'Gujarati': 'ટેક્સ્ટ સંપાદિત કરો અને તમારી વિગતો ઉમેરો',
        'Hindi': 'टेक्स्ट संपादित करें और अपना विवरण जोड़ें',
        'Marathi': 'मजकूर संपादित करा आणि तुमचे तपशील जोडा',
        'Punjabi': 'ਟੈਕਸਟ ਸੰਪਾਦਿਤ ਕਰੋ ਅਤੇ ਆਪਣੇ ਵੇਰਵੇ ਜੋੜੋ',
        'Urdu': 'تحریر میں ترمیم کریں اور اپنی تفصیلات شامل کریں'
  });

  String get cvvCode => _t({
        'English': 'CVV Code',
        'Gujarati': 'CVV કોડ',
        'Hindi': 'सीवीवी कोड',
        'Marathi': 'सीव्हीव्ही कोड',
        'Punjabi': 'ਸੀਵੀਵੀ ਕੋਡ',
        'Urdu': 'سی وی وی کوڈ'
  });

  String get darshanabhilashiList => _t({
        'English': 'Darshanabhilashi List',
        'Gujarati': 'દર્શનાભિલાષી યાદી',
        'Hindi': 'दर्शनाभिलाषी सूची',
        'Marathi': 'दर्शनाभिलाषी यादी',
        'Punjabi': 'ਦਰਸ਼ਨਾਭਿਲਾਸ਼ੀ ਸੂਚੀ',
        'Urdu': 'درشنابھیلاشی کی فہرست'
  });

  String get deleteElement => _t({
        'English': 'Delete Element',
        'Gujarati': 'તત્વ કાઢી નાખો',
        'Hindi': 'तत्व हटाएं',
        'Marathi': 'घटक हटवा',
        'Punjabi': 'ਤੱਤ ਹਟਾਓ',
        'Urdu': 'عنصر حذف کریں'
  });

  String get downloadShareSubtitle => _t({
        'English': 'Download and share your invitation easily',
        'Gujarati': 'તમારા આમંત્રણને સરળતાથી ડાઉનલોડ કરો અને શેર કરો',
        'Hindi': 'अपना निमंत्रण आसानी से डाउनलोड और साझा करें',
        'Marathi': 'तुमचे निमंत्रण सहजपणे डाउनलोड आणि शेअर करा',
        'Punjabi': 'ਆਪਣੇ ਸੱਦੇ ਨੂੰ ਆਸਾਨੀ ਨਾਲ ਡਾਊਨਲੋਡ ਅਤੇ ਸਾਂਝਾ ਕਰੋ',
        'Urdu': 'اپنا دعوت نامہ آسانی سے ڈاؤن لوڈ اور شیئر کریں'
  });

  String get duplicateElement => _t({
        'English': 'Duplicate Element',
        'Gujarati': 'ડુપ્લિકેટ તત્વ',
        'Hindi': 'डुप्लिकेट तत्व',
        'Marathi': 'ड्युप्लिकेट घटक',
        'Punjabi': 'ਡੁਪਲੀਕੇਟ ਤੱਤ',
        'Urdu': 'نقل تیار کریں'
  });

  String get addedToFavorites => _t({
        'English': 'Added to favorites',
        'Gujarati': 'પસંદગીમાં ઉમેર્યું',
        'Hindi': 'पसंदीदा में जोड़ा गया',
        'Marathi': 'आवडतांमध्ये जोडले',
        'Punjabi': 'ਪਸੰਦ ਵਿੱਚ ਜੋੜਿਆ ਗਿਆ',
        'Urdu': 'پسندیدہ میں شامل کیا گیا'
  });

  String get removedFromFavorites => _t({
        'English': 'Removed from favorites',
        'Gujarati': 'પસંદગીમાંથી દૂર કર્યું',
        'Hindi': 'पसंदीदा से हटा दिया गया',
        'Marathi': 'आवडतांमधून काढले',
        'Punjabi': 'ਪਸੰਦ ਤੋਂ ਹਟਾਇਆ ਗਿਆ',
        'Urdu': 'پسندیدہ سے ہٹا دیا گیا'
  });

  String get editContent => _t({
        'English': 'Edit Content',
        'Gujarati': 'સામગ્રી સંપાદિત કરો',
        'Hindi': 'सामग्री संपादित करें',
        'Marathi': 'सामग्री संपादित करा',
        'Punjabi': 'ਸਮੱਗਰੀ ਸੰਪਾਦਿਤ ਕਰੋ',
        'Urdu': 'مواد میں ترمیم کریں'
  });

  String get editInFewTaps => _t({
        'English': 'edit in just few taps',
        'Gujarati': 'માત્ર થોડા ક્લિક્સમાં સંપાદિત કરો',
        'Hindi': 'बस कुछ ही टैप में संपादित करें',
        'Marathi': 'फक्त काही टॅप्समध्ये संपादित करा',
        'Punjabi': 'ਸਿਰਫ਼ ਕੁਝ ਟੈਪਾਂ ਵਿੱਚ ਸੰਪਾਦਿਤ ਕਰੋ',
        'Urdu': 'صرف چند کلکس میں ترمیم کریں'
  });

  String get editText => _t({
        'English': 'Edit Text',
        'Gujarati': 'ટેક્સ્ટ સંપાદિત કરો',
        'Hindi': 'टेक्स्ट संपादित करें',
        'Marathi': 'मजकूर संपादित करा',
        'Punjabi': 'ਟੈਕਸਟ ਸੰਪาਦਿਤ ਕਰੋ',
        'Urdu': 'تحریر میں ترمیم کریں'
  });

  String get emailAddress => _t({
        'English': 'Email Address',
        'Gujarati': 'ઈમેલ એડ્રેસ',
        'Hindi': 'ईमेल पता',
        'Marathi': 'ईमेल पत्ता',
        'Punjabi': 'ਈਮੇਲ ਪਤਾ',
        'Urdu': 'ای میل پتہ'
  });

  String get enterName => _t({
        'English': 'Enter Name',
        'Gujarati': 'નામ દાખલ કરો',
        'Hindi': 'नाम दर्ज करें',
        'Marathi': 'नाव प्रविष्ट करा',
        'Punjabi': 'ਨਾਮ ਦਰਜ ਕਰੋ',
        'Urdu': 'نام درج کریں'
  });

  String get enterPhone => _t({
        'English': 'Enter Phone Number',
        'Gujarati': 'ફોન નંબર દાખલ કરો',
        'Hindi': 'फ़ोन नंबर दर्ज करें',
        'Marathi': 'फोन नंबर प्रविष्ट करा',
        'Punjabi': 'ਫ਼ੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Urdu': 'فون نمبر درج کریں'
  });

  String get expirationDate => _t({
        'English': 'Expiration Date',
        'Gujarati': 'સમાપ્તિ તારીખ',
        'Hindi': 'समाप्ति तिथि',
        'Marathi': 'कालबाह्य तारीख',
        'Punjabi': 'ਮਿਆਦ ਪੁੱਗਣ ਦੀ ਤਾਰੀਖ',
        'Urdu': 'میعاد ختم ہونے کی تاریخ'
  });

  String get expiresOn => _t({
        'English': 'Expires on',
        'Gujarati': 'સમાપ્ત થાય છે',
        'Hindi': 'को समाप्त होगा',
        'Marathi': 'रोजी संपेल',
        'Punjabi': 'ਨੂੰ ਮਿਆਦ ਪੁੱਗ ਰਹੀ ਹੈ',
        'Urdu': 'کو ختم ہوگا'
  });

  String get exploreCategoriesSubtitle => _t({
        'English': 'Explore categories and create a perfect invitation for your occasion',
        'Gujarati': 'શ્રેણીઓ શોધો અને તમારા પ્રસંગ માટે એક પરફેક્ટ આમંત્રણ બનાવો',
        'Hindi': 'श्रेणियां एक्सप्लोर करें और अपने अवसर के लिए एक परफेक्ट निमंत्रण बनाएं',
        'Marathi': 'श्रेण्या एक्सप्लोर करा आणि तुमच्या प्रसंगासाठी एक परिपूर्ण निमंत्रण तयार करा',
        'Punjabi': 'ਸ਼੍ਰੇਣੀਆਂ ਦੀ ਪੜਚੋਲ ਕਰੋ ਅਤੇ ਆਪਣੇ ਮੌਕੇ ਲਈ ਇੱਕ ਸੰਪੂਰਨ ਸੱਦਾ ਬਣਾਓ',
        'Urdu': 'زمرے دریافت کریں اور اپنے موقع کے لیے ایک بہترین دعوت نامہ بنائیں'
  });

  String get failedToCancel => _t({
        'English': 'Failed to cancel subscription',
        'Gujarati': 'સબ્સ્ક્રિપ્શન રદ કરવામાં નિષ્ફળ',
        'Hindi': 'सदस्यता रद्द करने में विफल',
        'Marathi': 'सदस्यता रद्द करण्यात अयशस्वी',
        'Punjabi': 'ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਰੱਦ ਕਰਨ ਵਿੱਚ ਅਸਫਲ',
        'Urdu': 'سبسکرپشن منسوخ کرنے میں ناکامی'
  });

  String get forEveryOccasion => _t({
        'English': 'for every occasion',
        'Gujarati': 'દરેક પ્રસંગ માટે',
        'Hindi': 'हर अवसर के लिए',
        'Marathi': 'प्रत्येक प्रसंगासाठी',
        'Punjabi': 'ਹਰ ਮੌਕੇ ਲਈ',
        'Urdu': 'ہر موقع کے لیے'
  });

  String get freeAccount => _t({
        'English': 'Free Account',
        'Gujarati': 'મફત એકાઉન્ટ',
        'Hindi': 'निःशुल्क खाता',
        'Marathi': 'मोफत खाते',
        'Punjabi': 'ਮੁਫ਼ਤ ਖਾਤਾ',
        'Urdu': 'مفت اکاؤنٹ'
  });

  String get gatewayMode => _t({
        'English': 'Gateway Mode',
        'Gujarati': 'ગેટવે મોડ',
        'Hindi': 'गेटवे मोड',
        'Marathi': 'गेटवे मोड',
        'Punjabi': 'ਗੇਟਵੇ ਮੋਡ',
        'Urdu': 'گیٹ وے موڈ'
  });

  String get guestName => _t({
        'English': 'Guest Name',
        'Gujarati': 'મહેમાનનું નામ',
        'Hindi': 'अतिथि का नाम',
        'Marathi': 'पाहुण्याचे नाव',
        'Punjabi': 'ਮਹਿਮਾਨ ਦਾ ਨਾਮ',
        'Urdu': 'مہمان کا نام'
  });

  String get hundredPlusTemplates => _t({
        'English': '100+ Template',
        'Gujarati': '૧૦૦+ ટેમ્પ્લેટ',
        'Hindi': '100+ टेम्पलेट',
        'Marathi': '१००+ टेम्पलेट्स',
        'Punjabi': '100+ ਟੈਂਪਲੇਟ',
        'Urdu': '100+ ٹیمپلیٹس'
  });

  String get invoiceTransactionCompleted => _t({
        'English': 'Transaction Completed',
        'Gujarati': 'ટ્રાન્ઝેક્શન પૂર્ણ થયું',
        'Hindi': 'लेनदेन पूरा हुआ',
        'Marathi': 'व्यवहार पूर्ण झाला',
        'Punjabi': 'ਲੈਣ-ਦੇਣ ਪੂਰਾ ਹੋਇਆ',
        'Urdu': 'لین دین مکمل ہو گیا'
  });

  String get invoiceTransactionHistory => _t({
        'English': 'Transaction History',
        'Gujarati': 'ટ્રાન્ઝેક્શન ઇતિહાસ',
        'Hindi': 'लेनदेन इतिहास',
        'Marathi': 'व्यवहार इतिहास',
        'Punjabi': 'ਲੈਣ-ਦੇਣ ਦਾ ઇਤિਹਾਸ',
        'Urdu': 'لین دین کی تاریخ'
  });

  String get keepPremium => _t({
        'English': 'Keep Premium',
        'Gujarati': 'પ્રીમિયમ ચાલુ રાખો',
        'Hindi': 'प्रीमियम रखें',
        'Marathi': 'प्रीमियम ठेवा',
        'Punjabi': 'ਪ੍ਰੀਮੀਅਮ ਰੱਖੋ',
        'Urdu': 'پریمیم رکھیں'
  });

  String get loadingDynamicPages => _t({
        'English': 'Loading dynamic page layers...',
        'Gujarati': 'ડાયનેમિક પેજ લેયર્સ લોડ કરી રહ્યાં છે...',
        'Hindi': 'डायनेमिक पेज लेयर्स लोड हो रहे हैं...',
        'Marathi': 'डायनॅमिक पेज लेयर्स लोड होत आहेत...',
        'Punjabi': 'ਡਾਇਨਾਮਿਕ ਪੰਨੇ ਦੇ ਲੇਅਰ ਲੋਡ ਹੋ ਰਹੇ ਹਨ...',
        'Urdu': 'ڈائنامک پیج لیئرز لوڈ ہو رہی ہیں...'
  });

  String get loginOrSignup => _t({
        'English': 'Login or Signup',
        'Gujarati': 'લોગિન અથવા સાઇનઅપ',
        'Hindi': 'लॉगिन या साइनअप',
        'Marathi': 'लॉगिन किंवा साइनअप',
        'Punjabi': 'ਲੌਗਇਨ ਜਾਂ ਸਾਈਨ ਅੱਪ',
        'Urdu': 'لاگ ان یا سائن اپ'
  });

  String get mameruMosalList => _t({
        'English': 'Mameru Mosal List',
        'Gujarati': 'મોસાળ યાદી',
        'Hindi': 'मामेरु मोसाल सूची',
        'Marathi': 'માमेरू मोसाळ यादी',
        'Punjabi': 'ਮਾਮੇਰੂ ਮੋਸਾਲ ਸੂਚੀ',
        'Urdu': 'مامیرو موسال کی فہرست'
  });

  String get manageSubscription => _t({
        'English': 'Manage Subscription',
        'Gujarati': 'સબ્સ્ક્રિપ્શન મેનેજ કરો',
        'Hindi': 'सदस्यता प्रबंधित करें',
        'Marathi': 'सदस्यता व्यवस्थापित करा',
        'Punjabi': 'ਸਬਸਕ੍ਰਿਪਸ਼ਨ ਪ੍ਰਬੰਧਿਤ ਕਰੋ',
        'Urdu': 'سبسکرپشن کا انتظام کریں'
  });

  String get masiFoiLadla => _t({
        'English': 'Masi Foi Ladla',
        'Gujarati': 'માસી ફોઈ લાડલા',
        'Hindi': 'मासी फोई लाडला',
        'Marathi': 'मावशी आत्या लाडके',
        'Punjabi': 'ਮਾਸੀ ਭੂਆ ਲਾਡਲੇ',
        'Urdu': 'ماسی پھپھو لاڈلے'
  });

  String get monthly => _t({
        'English': 'Monthly',
        'Gujarati': 'માસિક',
        'Hindi': 'मासिक',
        'Marathi': 'मासिक',
        'Punjabi': 'ਮਾਸਿਕ',
        'Urdu': 'ماہانہ'
  });

  String get monthlyPremiumPass => _t({
        'English': 'Monthly Premium Pass',
        'Gujarati': 'માસિક પ્રીમિયમ પાસ',
        'Hindi': 'मासिक प्रीमियम पास',
        'Marathi': 'मासिक प्रीमियम पास',
        'Punjabi': 'ਮਾਸਿਕ ਪ੍ਰੀਮੀਅม ਪਾਸ',
        'Urdu': 'ماہانہ پریمیم پاس'
  });

  String get mostPopularSave => _t({
        'English': 'Most Popular (Save 40%)',
        'Gujarati': 'સૌથી લોકપ્રિય (૪૦% બચાવો)',
        'Hindi': 'सबसे लोकप्रिय (40% बचाएं)',
        'Marathi': 'सर्वात लोकप्रिय (४०% वाचवा)',
        'Punjabi': 'ਸਭ ਤੋਂ ਪ੍ਰਸਿੱਧ (40% ਬਚਾਓ)',
        'Urdu': 'سب سے مقبول (40 فیصد بچت)'
  });

  String get noPlansAvailable => _t({
        'English': 'No plans available',
        'Gujarati': 'કોઈ પ્લાન ઉપલબ્ધ નથી',
        'Hindi': 'कोई प्लान उपलब्ध नहीं',
        'Marathi': 'कोणतीही योजना उपलब्ध नाही',
        'Punjabi': 'ਕੋਈ ਪਲਾਨ ਉਪਲਬਧ ਨਹੀਂ',
        'Urdu': 'کوئی پلان دستیاب نہیں ہے'
  });

  String get noteOptional => _t({
        'English': 'Note (Optional)',
        'Gujarati': 'નોંધ (વૈકલ્પિક)',
        'Hindi': 'नोट (वैकल्पिक)',
        'Marathi': 'टीप (पर्यायी)',
        'Punjabi': 'ਨੋਟ (ਵੈਕਲਪਿਕ)',
        'Urdu': 'نوٹ (اختیاری)'
  });

  String get paymentFailed => _t({
        'English': 'Payment Failed',
        'Gujarati': 'ચુકવણી નિષ્ફળ ગઈ',
        'Hindi': 'भुगतान विफल',
        'Marathi': 'पेमेंट अयशस्वी',
        'Punjabi': 'ਭੁਗਤਾਨ ਅਸਫਲ ਰਿਹਾ',
        'Urdu': 'ادائیگی ناکام ہو گئی'
  });

  String get paymentSandboxGateway => _t({
        'English': 'Payment Sandbox Gateway',
        'Gujarati': 'પેમેન્ટ સેન્ડબોક્સ ગેટવે',
        'Hindi': 'भुगतान सैंडबॉक्स गेटवे',
        'Marathi': 'पेमेंट सँडबॉक्स गेटवे',
        'Punjabi': 'ਭੁਗਤਾਨ ਸੈਂਡਬਾਕਸ ਗੇਟਵੇ',
        'Urdu': 'ادائیگی کا سینڈ باکس گیٹ وے'
  });

  String get paymentSuccessful => _t({
        'English': 'Payment Successful',
        'Gujarati': 'ચુકવણી સફળ રહી',
        'Hindi': 'भुगतान सफल रहा',
        'Marathi': 'पेमेंट यशस्वी',
        'Punjabi': 'ਭੁਗਤਾਨ ਸਫਲ ਰਿਹਾ',
        'Urdu': 'ادائیگی کامیاب رہی'
  });

  String get perDays => _t({
        'English': 'days',
        'Gujarati': 'દિવસો',
        'Hindi': 'दिन',
        'Marathi': 'दिवस',
        'Punjabi': 'ਦਿਨ',
        'Urdu': 'دن'
  });

  String get perMonth => _t({
        'English': 'month',
        'Gujarati': 'મહિનો',
        'Hindi': 'महीना',
        'Marathi': 'महिना',
        'Punjabi': 'ਮਹੀਨਾ',
        'Urdu': 'مہینہ'
  });

  String get perYear => _t({
        'English': 'year',
        'Gujarati': 'વર્ષ',
        'Hindi': 'वर्ष',
        'Marathi': 'वर्ष',
        'Punjabi': 'ਸਾਲ',
        'Urdu': 'سال'
  });

  String get premiumSubscription => _t({
        'English': 'Premium Subscription',
        'Gujarati': 'પ્રીમિયમ સબ્સ્ક્રિપ્શન',
        'Hindi': 'प्रीमियम सदस्यता',
        'Marathi': 'प्रीमियम सदस्यता',
        'Punjabi': 'ਪ੍ਰੀਮੀਅਮ ਸਬਸਕ੍ਰਿਪਸ਼ਨ',
        'Urdu': 'پریمیم سبسکرپشن'
  });

  String get preset => _t({
        'English': 'Preset',
        'Gujarati': 'પ્રિસેટ',
        'Hindi': 'प्रीसेट',
        'Marathi': 'प्रीसेट',
        'Punjabi': 'ਪ੍ਰੀਸੈਟ',
        'Urdu': 'پہلے سے طے شدہ'
  });

  String get renewsAutomaticallyOn => _t({
        'English': 'Renews automatically on',
        'Gujarati': 'ઓટોમેટીક રીન્યુ થાય છે',
        'Hindi': 'अपने आप नवीनीकृत होगा',
        'Marathi': 'रोजी आपोआप नूतनीकरण होईल',
        'Punjabi': 'ਨੂੰ ਆਪਣੇ ਆਪ ਨਵਿਆਇਆ ਜਾਵੇਗਾ',
        'Urdu': 'خود بخود تجدید ہوگی'
  });

  String get rsvp => _t({
        'English': 'RSVP',
        'Gujarati': 'RSVP',
        'Hindi': 'आरएसवीपी',
        'Marathi': 'आरएसव्हीपी',
        'Punjabi': 'ਆਰਐਸਵੀਪੀ',
        'Urdu': 'جواب دیں'
  });

  String get rsvpStatus => _t({
        'English': 'RSVP Status',
        'Gujarati': 'RSVP સ્થિતિ',
        'Hindi': 'आरएसवीपी स्थिति',
        'Marathi': 'आरएसव्हीपी स्थिती',
        'Punjabi': 'ਆਰਐਸਵੀਪੀ ਸਥਿਤੀ',
        'Urdu': 'آر ایس وی پی کی حیثیت'
  });

  String get sandboxTest => _t({
        'English': 'Sandbox Test',
        'Gujarati': 'સેન્ડબોક્સ ટેસ્ટ',
        'Hindi': 'सैंडबॉक्स परीक्षण',
        'Marathi': 'सँडबॉक्स चाचणी',
        'Punjabi': 'ਸੈਂਡਬਾਕਸ ਟੈਸਟ',
        'Urdu': 'سینڈ باکس ٹیسٹ'
  });

  String get saveLink => _t({
        'English': 'Save Link',
        'Gujarati': 'લિંક સાચવો',
        'Hindi': 'लिंक सहेजें',
        'Marathi': 'लिंक जतन करा',
        'Punjabi': 'ਲਿੰક સૂરક્ષિત કરો',
        'Urdu': 'لنک محفوظ کریں'
  });

  String get selectPaymentMethod => _t({
        'English': 'Select Payment Method',
        'Gujarati': 'ચુકવણી પદ્ધતિ પસંદ કરો',
        'Hindi': 'भुगतान विधि चुनें',
        'Marathi': 'पेमेंट पद्धत निवडा',
        'Punjabi': 'ਭੁਗਤਾਨ ਵਿਧੀ ਚੁਣੋ',
        'Urdu': 'ادائیگی کا طریقہ منتخب کریں'
  });

  String get sendOtp => _t({
        'English': 'Send OTP',
        'Gujarati': 'OTP મોકલો',
        'Hindi': 'ओटीपी भेजें',
        'Marathi': 'ओटीपी पाठवा',
        'Punjabi': 'ਓਟੀਪੀ ਭੇਜੋ',
        'Urdu': 'او ٹی پی بھیجیں'
  });

  String get simulatePaymentFailure => _t({
        'English': 'Simulate Payment Failure',
        'Gujarati': 'પેમેન્ટ નિષ્ફળતાનું અનુકરણ કરો',
        'Hindi': 'भुगतान विफलता का अनुकरण करें',
        'Marathi': 'पेमेंट अपयशाचे सिम्युलेट करा',
        'Punjabi': 'ਭੁਗਤਾਨ ਅਸਫਲਤਾ ਦਾ ਅਨੁਕਰਨ ਕਰੋ',
        'Urdu': 'ادائیگی کی ناکامی کی نقل کریں'
  });

  String get simulatePaymentTrial => _t({
        'English': 'Simulate Payment Trial',
        'Gujarati': 'પેમેન્ટ ટ્રાયલનું અનુકરણ કરો',
        'Hindi': 'भुगतान परीक्षण का अनुकरण करें',
        'Marathi': 'पेमेंट चाचणीचे सिम्युलेट करा',
        'Punjabi': 'ਭੁਗਤਾਨ ਟਰਾਇਲ ਦਾ ਅਨੁਕਰਨ ਕਰੋ',
        'Urdu': 'ادائیگی کے ٹرائل کی نقل کریں'
  });

  String get simulateSuccess => _t({
        'English': 'Simulate Success (',
        'Gujarati': 'સફળતાનું અનુકરણ કરો (',
        'Hindi': 'सफलता का अनुकरण करें (',
        'Marathi': 'यशस्वी सिम्युलेट करा (',
        'Punjabi': 'ਸਫਲਤਾ ਦਾ ਅਨੁਕਰਨ ਕਰੋ (',
        'Urdu': 'کامیابی کی نقل کریں ('
  });

  String get snehdhinList => _t({
        'English': 'Snehdhin List',
        'Gujarati': 'સ્નેહાધીન યાદી',
        'Hindi': 'स्नेहाधीन सूची',
        'Marathi': 'स्नेहाधीन यादी',
        'Punjabi': 'ਸਨੇਹਾਧੀਨ ਸੂਚੀ',
        'Urdu': 'سنیہادھین کی فہرست'
  });

  String get subscribeNow => _t({
        'English': 'Subscribe Now',
        'Gujarati': 'હમણાં સબ્સ્ક્રાઇબ કરો',
        'Hindi': 'अभी सदस्यता लें',
        'Marathi': 'आत्ताच सबस्क्राइब करा',
        'Punjabi': 'ਹੁਣੇ ਸਬਸਕ੍ਰਾਈਬ ਕਰੋ',
        'Urdu': 'ابھی سبسکرائب کریں'
  });

  String get subscribeToUnlock => _t({
        'English': 'Subscribe to unlock premium templates',
        'Gujarati': 'પ્રીમિયમ ટેમ્પ્લેટ્સ અનલૉક કરવા માટે સબ્સ્ક્રાઇબ કરો',
        'Hindi': 'प्रीमियम टेम्पलेट्स अनलॉक करने के लिए सदस्यता लें',
        'Marathi': 'प्रीमियम टेम्पलेट्स अनलॉक करण्यासाठी सबस्क्राइब करा',
        'Punjabi': 'ਪ੍ਰੀਮੀਅਮ ਟੈਂਪਲੇਟਸ ਨੂੰ ਅਨਲੌਕ ਕਰਨ ਲਈ ਸਬਸਕ੍ਰਾਈਬ ਕਰੋ',
        'Urdu': 'پریمیم ٹیمپلیٹس کو غیر مقفل کرنے کے لیے سبسکرائب کریں'
  });

  String get tahukoPoem => _t({
        'English': 'Tahuko Poem',
        'Gujarati': 'ટહુકો કવિતા',
        'Hindi': 'टहुको कविता',
        'Marathi': 'टहुको कविता',
        'Punjabi': 'ਟਹੂਕੋ ਕਵਿਤਾ',
        'Urdu': 'ٹہوکو نظم'
  });

  String get templateDetail => _t({
        'English': 'Template Detail',
        'Gujarati': 'ટેમ્પ્લેટ વિગત',
        'Hindi': 'टेम्पलेट विवरण',
        'Marathi': 'टेम्पलेट तपशील',
        'Punjabi': 'ਟੈਂਪਲੇਟ ਵੇਰਵਾ',
        'Urdu': 'ٹیمپلیٹ تفصیل'
  });

  String get threeDayFreeTrial => _t({
        'English': '3-Day Free Trial',
        'Gujarati': '૩-દિવસીય મફત ટ્રાયલ',
        'Hindi': '3-दिन का निःशुल्क परीक्षण',
        'Marathi': '३ दिवसांची मोफत चाचणी',
        'Punjabi': '3-ਦਿਨ ਦੀ ਮੁਫ਼ਤ ਅਜ਼ਮਾਇਸ਼',
        'Urdu': '3 روزہ مفت ٹرائل'
  });

  String get trialActiveUntil => _t({
        'English': 'Trial active until',
        'Gujarati': 'ટ્રાયલ સક્રિય છે સુધી',
        'Hindi': 'परीक्षण सक्रिय है तक',
        'Marathi': 'रोजीपर्यंत चाचणी सक्रिय असेल',
        'Punjabi': 'ਤੱਕ ਟਰਾਇਲ ਸਰਗਰਮ ਹੈ',
        'Urdu': 'ٹرائل فعال ہے تک'
  });

  String get tryAgain => _t({
        'English': 'Try Again',
        'Gujarati': 'ફરીથી પ્રયાસ કરો',
        'Hindi': 'पुनः प्रयास करें',
        'Marathi': 'पुन्हा प्रयत्न करा',
        'Punjabi': 'ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ',
        'Urdu': 'دوبارہ کوشش کریں'
  });

  String get upiApp => _t({
        'English': 'UPI App',
        'Gujarati': 'UPI એપ',
        'Hindi': 'यूपीआई ऐप',
        'Marathi': 'यूपीआय ॲप',
        'Punjabi': 'ਯੂਪੀਆਈ ਐਪ',
        'Urdu': 'یو پی آئی ایپ'
  });

  String get uploadSvg => _t({
        'English': 'Upload SVG',
        'Gujarati': 'SVG અપલોડ કરો',
        'Hindi': 'एसवीजी अपलोड करें',
        'Marathi': 'SVG अपलोड करा',
        'Punjabi': 'SVG ਅਪਲੋਡ ਕਰੋ',
        'Urdu': 'ایس وی جی اپ لوڈ کریں'
  });

  String get userManagement => _t({
        'English': 'User Management',
        'Gujarati': 'વપરાશકર્તા સંચાલન',
        'Hindi': 'उपयोगकर्ता प्रबंधन',
        'Marathi': 'वापरकर्ता व्यवस्थापन',
        'Punjabi': 'ਉਪਭੋਗਤਾ ਪ੍ਰਬੰਧਨ',
        'Urdu': 'صارف کا انتظام'
  });

  String get userRole => _t({
        'English': 'User Role',
        'Gujarati': 'વપરાશકર્તા ભૂમિકા',
        'Hindi': 'उपयोगकर्ता भूमिका',
        'Marathi': 'वापरकर्ता भूमिका',
        'Punjabi': 'ਉਪਭੋਗਤਾ ਦੀ ਭੂਮਿਕਾ',
        'Urdu': 'صارف کا کردار'
  });

  String get validUntil => _t({
        'English': 'Valid Until',
        'Gujarati': 'સુધી માન્ય',
        'Hindi': 'तक मान्य',
        'Marathi': 'पर्यंत वैध',
        'Punjabi': 'ਤੱਕ ਵੈਧ',
        'Urdu': 'تک درست'
  });

  String get verifyingFunds => _t({
        'English': 'Verifying funds...',
        'Gujarati': 'ભંડોળની ચકાસણી કરી રહ્યા છીએ...',
        'Hindi': 'फंड सत्यापित किया जा रहा है...',
        'Marathi': 'निधीची पडताळणी करत आहे...',
        'Punjabi': 'ਫੰਡਾਂ ਦੀ ਪੜਤਾਲ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ...',
        'Urdu': 'فنڈز کی تصدیق کی جا رہی ہے...'
  });

  String get virtualPaymentAddress => _t({
        'English': 'Virtual Payment Address (VPA)',
        'Gujarati': 'વર્ચ્યુઅલ પેમેન્ટ એડ્રેસ (VPA)',
        'Hindi': 'वर्चुअल भुगतान पता (VPA)',
        'Marathi': 'व्हर्च्युअल payment पत्ता (VPA)',
        'Punjabi': 'ਵਰਚੁਅਲ ਪੇਮੈਂਟ ਐਡਰੈੱਸ (VPA)',
        'Urdu': 'ورچوئل پیمنٹ ایڈریس (VPA)'
  });

  String get weddingTemplate => _t({
        'English': 'Wedding Template',
        'Gujarati': 'લગ્ન ટેમ્પ્લેટ',
        'Hindi': 'शादी का टेम्पलेट',
        'Marathi': 'लग्न टेम्पलेट',
        'Punjabi': 'ਵਿਆਹ ਦਾ ਟੈਂਪਲੇਟ',
        'Urdu': 'شادی کا ٹیمپلیٹ'
  });

  String get welcomeBack => _t({
        'English': 'Welcome Back!',
        'Gujarati': 'આપનું સ્વાગત છે!',
        'Hindi': 'आपका स्वागत है!',
        'Marathi': 'पुन्हा स्वागत आहे!',
        'Punjabi': 'ਜੀ ਆਇਆਂ ਨੂੰ!',
        'Urdu': 'خوش آمدید!'
  });

  String get withLovedOnes => _t({
        'English': 'with your loved ones',
        'Gujarati': 'તમારા સ્નેહીજનો સાથે',
        'Hindi': 'अपने प्रियजनों के साथ',
        'Marathi': 'तुमच्या प्रियजनांसोबत',
        'Punjabi': 'ਆਪਣੇ ਪਿਆਰਿਆਂ ਨਾਲ',
        'Urdu': 'اپنے پیاروں کے ساتھ'
  });

  String get yearlyPremiumPass => _t({
        'English': 'Yearly Premium Pass',
        'Gujarati': 'વાર્ષિક પ્રીમિયમ પાસ',
        'Hindi': 'वार्षिक प्रीमियम पास',
        'Marathi': 'वार्षिक प्रीमियम पास',
        'Punjabi': 'ਸਾਲਾਨਾ ਪ੍ਰੀਮੀਅਮ ਪਾਸ',
        'Urdu': 'سالانہ پریمیم پاس'
  });

  String get yearlySave => _t({
        'English': 'Yearly Save',
        'Gujarati': 'વાર્ષિક બચત',
        'Hindi': 'वार्षिक बचत',
        'Marathi': 'वार्षिक बचत',
        'Punjabi': 'ਸਾਲਾਨਾ ਬਚਤ',
        'Urdu': 'سالانہ بچت'
  });

}
