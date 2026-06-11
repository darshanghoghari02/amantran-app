import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/language_model.dart';
import '../repositories/user_repository.dart';
import '../services/interaction_service.dart';
import '../services/firestore_service.dart';
import '../services/language_registry.dart';

/// Holds all translated UI strings for the app.
/// When the language changes, all widgets listening to this provider rebuild instantly.
class LanguageProvider extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _keyAppLang = 'app_language';
  static const String _keyInvLang = 'invitation_language';
  static const String _keyInvLangsList = 'invitation_languages_list';

  final UserRepository _userRepository = UserRepository();
  StreamSubscription? _authSubscription;

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
        notifyListeners();
      }
    } catch (e) {
      print("Failed to load settings from Firestore: $e");
    }
  }

  Future<void> _saveSettingsToCloud() async {
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
    notifyListeners();
  }

  Future<void> _saveToHive(String key, dynamic value) async {
    final box = await Hive.openBox(_boxName);
    await box.put(key, value);
  }

  void setLanguage(String lang) {
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
    _invitationLanguages = filtered.isNotEmpty ? filtered : available;

    if (!_invitationLanguages.contains(_activeInvitationLanguage)) {
      _activeInvitationLanguage = _invitationLanguages.contains('Gujarati')
          ? 'Gujarati'
          : _invitationLanguages.first;
      _saveToHive(_keyInvLang, _activeInvitationLanguage);
    }
    _saveToHive(_keyInvLangsList, _invitationLanguages.toList());
    _saveSettingsToCloud();
    notifyListeners();
  }

  void setInvitationLanguages(Set<String> langs) {
    final available = LanguageRegistry.instance.languageNames;
    _invitationLanguages = available.isEmpty
        ? langs
        : langs.where((l) => available.contains(l)).toSet();
    if (_invitationLanguages.isEmpty && available.isNotEmpty) {
      _invitationLanguages = available;
    }
    _saveToHive(_keyInvLangsList, _invitationLanguages.toList());
    _saveSettingsToCloud();
    notifyListeners();
  }

  void setActiveInvitationLanguage(String lang) {
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
        'Gujarati': 'તમારું પરફેક્ટ ટેમ્પ્લેટ મેળવો.',
        'Hindi': 'अपना परफेक्ट टेम्पलेट पाएं.',
        'Marathi': 'तुमचा परिपूर्ण टेम्पलेट मिळवा.',
        'Punjabi': 'ਆਪਣਾ ਸੰਪੂਰਨ ਟੈਂਪਲੇਟ ਪ੍ਰਾਪਤ ਕਰੋ.',
        'Urdu': '.اپنا بہترین ٹیمپلیٹ حاصل کریں',
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
        'Urdu': 'رازداری की پالیسی',
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
        'Urdu': 'ابھی तक कोई पसंदीदा नहीं',
      });

  String get noDraftsYet => _t({
        'English': 'No drafts yet. Start designing!',
        'Gujarati': 'હજુ સુધી કોઈ ડ્રાફ્ટ નથી. ડિઝાઇન શરૂ કરો!',
        'Hindi': 'अभी तक कोई ड्राफ्ट नहीं. डिझाइन शरू करें!',
        'Marathi': 'अजून कोणताही मसुदा नाही. डिझाइन सुरू करा!',
        'Punjabi': 'ਅਜੇ ਕੋਈ ਡਰਾਫਟ ਨਹੀਂ। ਡਿਜ਼ਾਈਨ ਸ਼ੁਰੂ ਕਰੋ!',
        'Urdu': '!ابھی تک کوئی ڈرافٹ نہیں۔ ڈیزائن شروع کریں',
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
        'Urdu': 'ایپ زبان تبدیل کریں',
      });

  String get selectInvitationLanguages => _t({
        'English': 'Select Invitation Languages',
        'Gujarati': 'આમંત્રણ ભાષાઓ પસંદ કરો',
        'Hindi': 'निमंत्रण भाषाएं चुनें',
        'Marathi': 'निमंत्रण भाषा निवडा',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾਵਾਂ ਚੁਣੋ',
        'Urdu': 'دعوت نامہ زبانیں منتخب کریں',
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
        'Hindi': 'व्यक्तिगत जाणકારી',
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
        'Urdu': '!پروفائل کامیابی کے साथ अप अपडेट ہوگئی',
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
        'Urdu': ':خصوصیات',
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
        'Urdu': 'اعلی معیار کا دعوت نامہ ڈاؤن لوڈ کریں',
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
        'Hindi': 'પરંપરાના સ્પર્શ સાથે પોતાના વિશેષ દિવસની ઉજવણી કરો!',
        'Marathi': 'परंपरेच्या स्पर्शासह तुमच्या विशेष दिवसाचा उत्सव साजरा करा!',
        'Punjabi': 'ਪਰੰਪਰਾ ਦੇ ਅਹਿਸਾਸ ਨਾਲ ਆਪਣੇ ਖਾਸ ਦਿਨ ਦਾ ਜਸ਼ਨ ਮਨਾਓ!',
        'Urdu': '!روایت کے لمس کے ساتھ اپنے خاص دن کا جشن منائیں',
      });

  String get next => _t({
        'English': 'Next',
        'Gujarati': 'આગળ',
        'Hindi': 'अगला',
        'Marathi': 'पुढील',
        'Punjabi': 'ਅਗਲਾ',
        'Urdu': 'اگلا',
      });

  String get previous => _t({
        'English': 'Previous',
        'Gujarati': 'પાછળ',
        'Hindi': 'पिछલા',
        'Marathi': 'मागील',
        'Punjabi': 'ਪਿਛਲਾ',
        'Urdu': 'اگلا',
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
        'Urdu': 'محفوظ ہو رہا ہے...',
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
        'Urdu': 'ہو گیا'
      });
  String get cancel => _t({
        'English': 'Cancel',
        'Gujarati': 'રદ કરો',
        'Hindi': 'રદ કરા',
        'Marathi': 'रद्द करा',
        'Punjabi': 'ਰੱਦ ਕਰੋ',
        'Urdu': 'منسوخ کریں'
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
        'Urdu': '|| سری گنیشای نمہ ||'
      }, lang);

  String mangalikPrasangoLabelFor(String lang) => _tFor({
        'English': 'Mangalik Prasango',
        'Gujarati': 'માંગલિક પ્રસંગો',
        'Hindi': 'मांगलिक प्रसंग',
        'Marathi': 'मांगलिक प्रसंग',
        'Punjabi': 'ਮੰਗਲਿਕ ਪ੍ਰਸੰਗ',
        'Urdu': 'مانگلک پرسنگو'
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
        'English': 'with',
        'Gujarati': 'સંગ',
        'Hindi': 'संग',
        'Marathi': 'सोबत',
        'Punjabi': 'ਸੰਗ',
        'Urdu': 'سنگ'
      }, lang);

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
        'Punjabi': 'ਸਮੱਗરી ਤਿਆਰ ਕਰੋ',
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
        'Hindi': 'પીછે',
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
        'Hindi': 'તારીખ',
        'Marathi': 'तारीख',
        'Punjabi': 'ਤਾਰੀਖ',
        'Urdu': 'تاریخ'
      });
  String get timeLabel => _t({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'સમય',
        'Marathi': 'वेळ',
        'Punjabi': 'ਸਮਾਂ',
        'Urdu': 'وقت'
      });
  String get venuePlaceLabel => _t({
        'English': 'Venue / Place',
        'Gujarati': 'સ્થળ / જગ્યા',
        'Hindi': 'સ્થાન / જગહ',
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
        'Hindi': 'રોટેશન',
        'Marathi': 'रोटेशन',
        'Punjabi': 'ਰੋਟੇਸ਼ਨ',
        'Urdu': 'گھماؤ'
      });
  String get opacityLabel => _t({
        'English': 'Opacity',
        'Gujarati': 'પારદર્શિતા',
        'Hindi': 'અપારદર્શિતા',
        'Marathi': 'अपारदर्शकता',
        'Punjabi': 'ਪਾਰਦਰਸ਼ਤਾ',
        'Urdu': 'دھندلاپن'
      });
  String get chooseColorLabel => _t({
        'English': 'Choose Color',
        'Gujarati': 'રંગ પસંદ કરો',
        'Hindi': 'રંગ ચુને',
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
  String get guestUpdated => _t({
        'English': 'Guest updated successfully!',
        'Gujarati': 'મહેમાન સફળતાપૂર્વક અપડેટ થયા!',
        'Hindi': 'अतिथि सफलतापूर्वक अपडेट किया गया!',
        'Marathi': 'पाहुणे यशस्वीरित्या अपडेट झाले!',
        'Punjabi': 'ਮਹਿਮਾਨ ਸਫਲਤਾਪੂਰਵਕ ਅਪਡੇਟ ਕੀਤਾ ਗਿਆ!',
        'Urdu': '!مہمان کامیابی کے ساتھ اپ ڈیٹ ہو گیا'
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
        'Marathi': 'VCF संपर्क',
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
        'Hindi': 'प्रिंटिंग / शेयरિંગ के लिए',
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
  String get edit => _t({
        'English': 'Edit',
        'Gujarati': 'સંપાદિત કરો',
        'Hindi': 'एडिट करें',
        'Marathi': 'संपादित करा',
        'Punjabi': 'ਸੋਧੋ',
        'Urdu': 'ترمیم کریں'
      });
  String get shareWith => _t({
        'English': 'Share with',
        'Gujarati': 'શેર કરો',
        'Hindi': 'इसके साथ साझा करें',
        'Marathi': 'यांच्यासोबत शेयर करा',
        'Punjabi': 'ਨਾਲ સਾਂਝਾ કરો',
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
        'Punjabi': 'ਪੁਸ਼ટી ਕਰੋ',
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
        'Punjabi': 'ਬਾਕી',
        'Urdu': 'زیر التواء'
      });
  String get viewed => _t({
        'English': 'Viewed',
        'Gujarati': 'જોયેલ',
        'Hindi': 'देखा गया',
        'Marathi': 'पाहिलेले',
        'Punjabi': 'ਵੇખ્યા ગયા',
        'Urdu': 'دیکھا گیا'
      });
  String get noGuestsMatch => _t({
        'English': 'No guests match your search',
        'Gujarati': 'તમારી શોધ સાથે કોઈ મહેમાન મળતા નથી',
        'Hindi': 'आपकी खोज से कोई अतिथि मेल नहीं खाता',
        'Marathi': 'तुमच्या शोधाशी कोणतेही पाहुणे जुळत नाहीत',
        'Punjabi': 'ਤੁਹਾਡੀ ਖੋਜ ਨਾਲ કોઈ ਮਹਿਮਾਨ ਨਹੀਂ ਮਿਲਦਾ',
        'Urdu': 'آپ کی تلاش سے کوئی مہمان مطابقت نہیں رکھتا'
      });
  String get addManually => _t({
        'English': 'Add Manually',
        'Gujarati': 'જાતે ઉમેરો',
        'Hindi': 'स्वयं जोड़ें',
        'Marathi': 'वैयक्तिकरित्या जोडा',
        'Punjabi': 'ਖੁਦ ਜੋੜੋ',
        'Urdu': 'دستی طور પર शामिल करें'
      });
  String get enterGuestDetail => _t({
        'English': 'Enter guest details manually',
        'Gujarati': 'મહેમાનની વિગતો જાતે દાખલ કરો',
        'Hindi': 'अतिथि विवरण स्वयं दर्ज करें',
        'Marathi': 'पाहुण्यांचे तपशील वैयक्तिकरित्या भरा',
        'Punjabi': 'ਮਹਿਮਾਨ ਦੇ ਵੇਰવે ਖੁਦ ਦਰਜ ਕਰੋ',
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
        'English': 'Easy to Customize',
        'Gujarati': 'કસ્ટમાઇઝ કરવું સરળ',
        'Hindi': 'कस्टमाइज़ करना आसान',
        'Marathi': 'सानुकूलित करणे सोपे',
        'Punjabi': 'ਅਨੁਕੂਲਿਤ ਕਰਨਾ ਆਸਾਨ',
        'Urdu': 'اپنی مرضی کے مطابق بنانا آسان ہے'
      });
  String get shareInstantly => _t({
        'English': 'Share Instantly',
        'Gujarati': 'તરત જ શેર કરો',
        'Hindi': 'तुरंत साझा करें',
        'Marathi': 'त्वरित शेयर करा',
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
  String get addedToFavorites => _t({
        'English': 'Added to favorites',
        'Gujarati': 'પસંદગીમાં ઉમેર્યું',
        'Hindi': 'पसंदीदा में जोड़ा गया',
        'Marathi': 'आवडीत जोडले',
        'Punjabi': 'ਮਨਪਸੰਦ ਵਿੱਚ ਸ਼ਾਮਲ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'پسندیدہ میں شامل کر دیا گیا'
      });
  String get removedFromFavorites => _t({
        'English': 'Removed from favorites',
        'Gujarati': 'પસંદગીમાંથી દૂર કર્યું',
        'Hindi': 'पसंदीदा से हटा दिया गया',
        'Marathi': 'आवडीतून काढले',
        'Punjabi': 'ਮਨਪਸੰਦ ਤੋਂ ਹਟਾ ਦਿੱਤਾ ਗਿਆ',
        'Urdu': 'پسندیدہ سے ہٹا دیا گیا'
      });
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
}
