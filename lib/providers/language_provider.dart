import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../repositories/user_repository.dart';
import '../services/interaction_service.dart';
import '../services/firestore_service.dart';

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
        _activeInvitationLanguage = settings[_keyInvLang] ?? _activeInvitationLanguage;
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
    _activeInvitationLanguage = box.get(_keyInvLang, defaultValue: 'Gujarati');
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

  void setInvitationLanguages(Set<String> langs) {
    _invitationLanguages = langs;
    _saveToHive(_keyInvLangsList, langs.toList());
    _saveSettingsToCloud();
    notifyListeners();
  }

  void setActiveInvitationLanguage(String lang) {
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
        'Marathi': 'निमंत्रण કાર્ડ મેકર',
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
        'Marathi': 'तुमचा परिपूर्ण टेम्पलेट मेळવા.',
        'Punjabi': 'ਆਪਣਾ ਸੰਪੂਰਨ ਟੈਂਪਲੇਟ ਪ੍ਰਾਪਤ ਕਰੋ.',
        'Urdu': '.اپنا بہترین ٹیمپلیٹ حاصل کریں',
      });

  String get searchHint => _t({
        'English': 'Search templates....',
        'Gujarati': 'ટેમ્પ્લેટ શોધો....',
        'Hindi': 'टेम्पलेट खोजें....',
        'Marathi': 'ટેમ્પ્લેટ શોધા....',
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
        'Marathi': 'સાખરપુડા નિમંત્રણ',
        'Punjabi': 'ਮੰਗਣੀ ਦਾ ਸੱਦਾ',
        'Urdu': 'منگنی کا دعوت نامہ',
      });

  String get babyShower => _t({
        'English': 'Baby Shower',
        'Gujarati': 'બેબી શાવર',
        'Hindi': 'बेबी शावर',
        'Marathi': 'બેબી શોવર',
        'Punjabi': 'ਬੇਬੀ ਸ਼ਾਵਰ',
        'Urdu': 'بیبی شاور',
      });

  String get seeAll => _t({
        'English': 'See All',
        'Gujarati': 'બધા જુઓ',
        'Hindi': 'सभी देखें',
        'Marathi': 'સર્વ પહા',
        'Punjabi': 'ਸਭ ਵੇਖੋ',
        'Urdu': 'سب دیکھیں',
      });

  String get home => _t({
        'English': 'Home',
        'Gujarati': 'હોમ',
        'Hindi': 'होम',
        'Marathi': 'હોમ',
        'Punjabi': 'ਹੋਮ',
        'Urdu': 'Û ÙˆÙ…',
      });

  String get yourDesign => _t({
        'English': 'Your Design',
        'Gujarati': 'તમારી ડિઝાઇન',
        'Hindi': 'आपकी डिझाइन',
        'Marathi': 'તુમચી ડિઝાઇન',
        'Punjabi': 'ਤੁਹਾਡੀ ਡਿਜ਼ਾਈਨ',
        'Urdu': 'آپ کا ڈیزائن',
      });

  String get favorites => _t({
        'English': 'Favorites',
        'Gujarati': 'પસંદગીનું',
        'Hindi': 'पसंदीदा',
        'Marathi': 'આવડતે',
        'Punjabi': 'ਮਨਪਸੰਦ',
        'Urdu': 'پسندیدہ',
      });

  String get guests => _t({
        'English': 'Guests',
        'Gujarati': 'મહેમાનો',
        'Hindi': 'अतिथि',
        'Marathi': 'પાહુણે',
        'Punjabi': 'ਮਹਿਮਾਨ',
        'Urdu': 'مہمان',
      });

  String get drafts => _t({
        'English': 'Drafts',
        'Gujarati': 'ડ્રાફ્ટ',
        'Hindi': 'ड्राफ्ट',
        'Marathi': 'મસુદા',
        'Punjabi': 'ਡਰਾਫਟ',
        'Urdu': 'ڈرافٹ',
      });

  String get yourDesigns => _t({
        'English': 'Your Designs',
        'Gujarati': 'તમારી ડિઝાઇન',
        'Hindi': 'आपकी डिझाइन',
        'Marathi': 'તુમચી ડિઝાઇન',
        'Punjabi': 'ਤੁਹਾਡੀ ਡਿਜ਼ਾਈਨ',
        'Urdu': 'آپ کے ڈیزائن',
      });

  String get appLanguage => _t({
        'English': 'App Language',
        'Gujarati': 'એપ ભાષા',
        'Hindi': 'ऐप भाषा',
        'Marathi': 'અપ્ ભાષા',
        'Punjabi': 'ਐਪ ਭਾਸ਼ਾ',
        'Urdu': 'ایپ زبان',
      });

  String get invitationLanguage => _t({
        'English': 'Invitation Language',
        'Gujarati': 'આમંત્રણ ભાષા',
        'Hindi': 'निमंत्रण भाषा',
        'Marathi': 'નિમંત્રણ ભાષા',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾ',
        'Urdu': 'دعوت نامہ زبان',
      });

  String get rateUs => _t({
        'English': 'Rate Us',
        'Gujarati': 'અમને રેટ કરો',
        'Hindi': 'हमें रेट करें',
        'Marathi': 'આમ્હાલા રેટ કરા',
        'Punjabi': 'ਸਾਨੂੰ ਰੇਟ ਕਰੋ',
        'Urdu': 'ہمیں ریٹ کریں',
      });

  String get shareApp => _t({
        'English': 'Share App',
        'Gujarati': 'એપ શેર કરો',
        'Hindi': 'ऐप शेयर करें',
        'Marathi': 'અપ્ શેર કરા',
        'Punjabi': 'ਐਪ ਸਾਂਝੀ ਕਰੋ',
        'Urdu': 'ایپ شیئر کریں',
      });

  String get termsConditions => _t({
        'English': 'Terms Conditions',
        'Gujarati': 'નિયમો અને શરતો',
        'Hindi': 'नियम और शर्तें',
        'Marathi': 'અટી વ શર્તી',
        'Punjabi': 'ਨਿਯਮ ਅਤੇ ਸ਼ਰਤਾਂ',
        'Urdu': 'شرائط و ضوابط',
      });

  String get privacyPolicy => _t({
        'English': 'Privacy Policy',
        'Gujarati': 'ગોપનીયતા નીતિ',
        'Hindi': 'गोपनीयता नीति',
        'Marathi': 'ગોપનીયતા ધોરણ',
        'Punjabi': 'ਗੋਪਨੀਯਤਾ ਨੀਤੀ',
        'Urdu': 'رازداری की پالیسی',
      });

  String get signOut => _t({
        'English': 'Sign Out',
        'Gujarati': 'સાઇન આઉટ',
        'Hindi': 'साइन आउट',
        'Marathi': 'સાઇન આઉટ',
        'Punjabi': 'ਸਾਈਨ ਆਊਟ',
        'Urdu': 'سائن آؤٹ',
      });

  String get apply => _t({
        'English': 'Apply',
        'Gujarati': 'લાગુ કરો',
        'Hindi': 'लागू करें',
        'Marathi': 'લાગુ કરા',
        'Punjabi': 'ਲਾਗੂ ਕਰੋ',
        'Urdu': 'لاگو کریں',
      });

  String get noFavoritesYet => _t({
        'English': 'No favorites yet',
        'Gujarati': 'હજુ સુધી કોઈ પસંદગી નથી',
        'Hindi': 'अभी तक कोई पसंदीदा नहीं',
        'Marathi': 'અજૂન કોણતેહી આવડતે નાહી',
        'Punjabi': 'ਅਜੇ ਕੋਈ ਮਨਪਸੰਦ ਨਹੀਂ',
        'Urdu': 'ابھی तक कोई पसंदीदा नहीं',
      });

  String get noDraftsYet => _t({
        'English': 'No drafts yet. Start designing!',
        'Gujarati': 'હજુ સુધી કોઈ ડ્રાફ્ટ નથી. ડિઝાઇન શરૂ કરો!',
        'Hindi': 'अभी तक कोई ड्राफ्ट नहीं. डिझाइन शरू करें!',
        'Marathi': 'અજૂન કોણતાહી મસુદા નાહી. ડિઝાઇન સૂરુ કરા!',
        'Punjabi': 'ਅਜੇ ਕੋਈ ਡਰਾਫਟ ਨਹੀਂ। ਡਿਜ਼ਾਈਨ ਸ਼ੁਰੂ ਕਰੋ!',
        'Urdu': '!ابھی تک کوئی ڈرافٹ نہیں۔ ڈیزائن شروع کریں',
      });

  String get selected => _t({
        'English': 'Selected',
        'Gujarati': 'પસંદ કરેલ',
        'Hindi': 'चयनित',
        'Marathi': 'નિવડલે',
        'Punjabi': 'ਚੁਣਿਆ',
        'Urdu': 'منتخب',
      });

  String get changeAppLanguage => _t({
        'English': 'Change App Language',
        'Gujarati': 'એપ ભાષા બદલો',
        'Hindi': 'ऐप भाषा बदलें',
        'Marathi': 'અપ્ ભાષા બદલા',
        'Punjabi': 'ਐਪ ਭਾਸ਼ਾ ਬਦલો',
        'Urdu': 'ایپ زبان تبدیل کریں',
      });

  String get selectInvitationLanguages => _t({
        'English': 'Select Invitation Languages',
        'Gujarati': 'આમંત્રણ ભાષાઓ પસંદ કરો',
        'Hindi': 'निमंत्रण भाषाएं चुनें',
        'Marathi': 'નિમંત્રણ ભાષા નિવડા',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾਵਾਂ ਚੁਣੋ',
        'Urdu': 'دعوت نامہ زبانیں منتخب کریں',
      });

  String get yourProfile => _t({
        'English': 'Your Profile',
        'Gujarati': 'તમારી પ્રોફાઇલ',
        'Hindi': 'आपकी प्रोफाइल',
        'Marathi': 'તુમચી પ્રોફાઇલ',
        'Punjabi': 'ਤੁਹਾਡੀ ਪ੍ਰੋਫਾਈਲ',
        'Urdu': 'آپ کی پروفائل',
      });

  String get personalInformation => _t({
        'English': 'Personal Information',
        'Gujarati': 'વ્યક્તિગત માહિતી',
        'Hindi': 'व्यक्तिगत जाणકારી',
        'Marathi': 'વૈયક્તિક માહિતી',
        'Punjabi': 'ਨਿੱજી ਜਾਣਕਾਰੀ',
        'Urdu': 'ذاتی معلومات',
      });

  String get fullName => _t({
        'English': 'Full Name',
        'Gujarati': 'આખું નામ',
        'Hindi': 'पूरा नाम',
        'Marathi': 'પૂર્ણ નાવ',
        'Punjabi': 'ਪੂਰਾ ਨਾਮ',
        'Urdu': 'پورا نام',
      });

  String get phoneNumber => _t({
        'English': 'Phone Number',
        'Gujarati': 'ફોન નંબર',
        'Hindi': 'फ़ोन नंबर',
        'Marathi': 'ફોન નંબર',
        'Punjabi': 'ਫ਼ੋਨ ਨੰਬਰ',
        'Urdu': 'فون نمبر',
      });

  String get updateProfile => _t({
        'English': 'Update Profile',
        'Gujarati': 'પ્રોફાઇલ અપડેટ કરો',
        'Hindi': 'प्रोफाइल अपडेट करें',
        'Marathi': 'પ્રોફાઇલ અપડેટ કરા',
        'Punjabi': 'ਪ੍ਰੋਫਾਈਲ ਅਪਡੇਟ ਕਰੋ',
        'Urdu': 'پروفائل اپ ڈیٹ کریں',
      });

  String get change => _t({
        'English': 'change',
        'Gujarati': 'બદલો',
        'Hindi': 'बदलें',
        'Marathi': 'બદલા',
        'Punjabi': 'ਬਦਲੋ',
        'Urdu': 'تبدیل کریں',
      });

  String get email => _t({
        'English': 'Email',
        'Gujarati': 'ઈમેલ',
        'Hindi': 'ईमेल',
        'Marathi': 'ઈમેલ',
        'Punjabi': 'ਈਮੇਲ',
        'Urdu': 'ای میل',
      });

  String get profileUpdated => _t({
        'English': 'Profile updated successfully!',
        'Gujarati': 'પ્રોફાઇલ સફળતાપૂર્વક અપડેટ થઈ!',
        'Hindi': 'प्रोफ़ाइल सफलतापूर्वक अपडेट की गई!',
        'Marathi': 'પ્રોફાઇલ યશસ્વીપણે અપડેટ ઝાલી!',
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
        'Marathi': 'હે ટેમ્પ્લેટ સાનુકૂલિત કરા',
        'Punjabi': 'ਇਸ ਟੈਂਪਲੇਟ ਨੂੰ ਅਨੁਕੂਲਿਤ ਕਰੋ',
        'Urdu': 'اس ٹیمپلیٹ کو اپنی مرضی کے مطابق بنائیں',
      });

  String get features => _t({
        'English': 'Features:',
        'Gujarati': 'વિશેષતાઓ:',
        'Hindi': 'विशेषताएं:',
        'Marathi': 'વૈશિષ્ટ્યે:',
        'Punjabi': 'ਵਿਸ਼ੇਸ਼ਤਾਵਾਂ:',
        'Urdu': ':خصوصیات',
      });

  String get feature1 => _t({
        'English': 'Edit text in seconds',
        'Gujarati': 'સેકન્ડોમાં ટેક્સ્ટ સંપાદિત કરો',
        'Hindi': 'सेकंडों में टेक्स्ट एडिट करें',
        'Marathi': 'કાહી સેકંદાન મજકૂર સંપાદિત કરા',
        'Punjabi': 'ਸਕਿੰਟਾਂ ਵਿੱਚ ਟੈਕਸਟ ਨੂੰ ਸੰਪਾਦਿਤ ਕਰੋ',
        'Urdu': 'سیکنڈوں میں متن میں ترمیم کریں',
      });

  String get feature2 => _t({
        'English': 'Download high-quality invitation',
        'Gujarati': 'ઉચ્ચ-ગુણવત્તાનું આમંત્રણ ડાઉનલોડ કરો',
        'Hindi': 'उच्च गुणवत्ता वाला निमंत्रण डाउनलोड करें',
        'Marathi': 'ઉચ્ચ-ગુણવત્તેચે નિમંત્રણ ડાઉનલોડ કરા',
        'Punjabi': 'ਉੱਚ-ਗੁਣਵੱਤਾ ਵਾਲਾ ਸੱਦਾ ਪੱਤਰ ਡਾਊਨਲੋਡ ਕਰੋ',
        'Urdu': 'اعلی معیار کا دعوت نامہ ڈاؤن لوڈ کریں',
      });

  String get feature3 => _t({
        'English': 'Perfect for WhatsApp sharing',
        'Gujarati': 'વોટ્સએપ શેરિંગ માટે યોગ્ય',
        'Hindi': 'व्हाट्सएप शेरिंग के लिए बिलकुल सही',
        'Marathi': 'વ્હૉટ્સઍપ શેરિંગસાઠી યોગ્ય',
        'Punjabi': 'ਵਟਸਐਪ ਸ਼ੇਅਰਿੰਗ ਲਈ ਸੰਪੂਰਨ',
        'Urdu': 'واٹس ایپ شیئرنگ کے لیے بہترین',
      });

  String get templateDescription => _t({
        'English': 'Celebrate your special day with a touch of tradition!',
        'Gujarati': 'પરંપરાના સ્પર્શ સાથે તમારા ખાસ દિવસની ઉજવણી કરો!',
        'Hindi': 'પરંપરાના સ્પર્શ સાથે પોતાના વિશેષ દિવસની ઉજવણી કરો!',
        'Marathi': 'પરંપરાના સ્પર્શ સાથે પોતાના વિશેષ દિવસની ઉજવણી કરો!',
        'Punjabi': 'ਪਰੰਪਰਾ ਦੇ ਅਹਿਸਾਸ ਨਾਲ ਆਪਣੇ ਖਾਸ ਦਿਨ ਦਾ ਜਸ਼ਨ ਮਨਾਓ!',
        'Urdu': '!روایت کے لمس کے ساتھ اپنے خاص دن کا جشن منائیں',
      });

  String get next => _t({
        'English': 'Next',
        'Gujarati': 'આગળ',
        'Hindi': 'अगला',
        'Marathi': 'પુઢીલ',
        'Punjabi': 'ਅਗਲਾ',
        'Urdu': 'اگلا',
      });

  String get previous => _t({
        'English': 'Previous',
        'Gujarati': 'પાછળ',
        'Hindi': 'पिछલા',
        'Marathi': 'માગીલ',
        'Punjabi': 'ਪਿਛਲਾ',
        'Urdu': 'اگلا',
      });

  String get save => _t({
        'English': 'Save',
        'Gujarati': 'સાચવો',
        'Hindi': 'सहेजें',
        'Marathi': 'જતન કરા',
        'Punjabi': 'ਸੁਰੱਖਿਅਤ ਕਰੋ',
        'Urdu': 'محفوظ کریں',
      });

  String get saving => _t({
        'English': 'Saving...',
        'Gujarati': 'સાચવી રહ્યા છીએ...',
        'Hindi': 'सहेज रहे हैं...',
        'Marathi': 'જતન કરત આહે...',
        'Punjabi': 'ਸੁਰੱਖਿਅਤ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ...',
        'Urdu': 'محفوظ ہو رہا ہے...',
      });

  String get downloadComplete => _t({
        'English': 'Download Complete',
        'Gujarati': 'ડાઉનલોડ પૂર્ણ થયું',
        'Hindi': 'डाउनलोड पूर्ण हुआ',
        'Marathi': 'ડાઉનલોડ પૂર્ણ ઝાલે',
        'Punjabi': 'ਡਾਊਨਲੋਡ ਪੂਰਾ ਹੋਇਆ',
        'Urdu': 'ڈاؤن لوڈ مکمل ہوا',
      });

  String get done => _t({
        'English': 'Done',
        'Gujarati': 'પૂર્ણ',
        'Hindi': 'पूर्ण',
        'Marathi': 'પૂર્ણ',
        'Punjabi': 'ਹੋ ਗਿਆ',
        'Urdu': 'ہو گیا'
      });
  String get cancel => _t({
        'English': 'Cancel',
        'Gujarati': 'રદ કરો',
        'Hindi': 'રદ કરા',
        'Marathi': 'રદ કરા',
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
        'Marathi': 'માંગલિક પ્રસંગ',
        'Punjabi': 'ਮੰਗਲਿਕ ਪ੍ਰਸੰਗ',
        'Urdu': 'مانگلک پرسنگو'
      }, lang);

  String shubhVivahLabelFor(String lang) => _tFor({
        'English': 'Shubh Vivah',
        'Gujarati': 'શુભ વિવાહ',
        'Hindi': 'शुभ विवाह',
        'Marathi': 'શુભ વિવાહ',
        'Punjabi': 'ਸ਼ੁਭ ਵਿਆਹ',
        'Urdu': 'شبھ وواہ'
      }, lang);

  String sangeetSandhyaLabelFor(String lang) => _tFor({
        'English': 'Sangeet Sandhya',
        'Gujarati': 'સંગીત સંધ્યા',
        'Hindi': 'संगीत संध्या',
        'Marathi': 'સંગીત સંધ્યા',
        'Punjabi': 'ਸੰਗੀਤ ਸੰਧਿਆ',
        'Urdu': 'سنگیت سندھیا'
      }, lang);

  String lagnotsavLabelFor(String lang) => _tFor({
        'English': 'Lagnotsav',
        'Gujarati': 'લગ્નોત્સવ',
        'Hindi': 'लग्नोत्सव',
        'Marathi': 'લગ્નોત્સવ',
        'Punjabi': 'ਲਗਨੋਤਸਵ',
        'Urdu': 'لگنوتسو'
      }, lang);

  String parinayUtsavLabelFor(String lang) => _tFor({
        'English': 'Parinay Utsav',
        'Gujarati': 'પરિણય ઉત્સવ',
        'Hindi': 'परिणय उत्सव',
        'Marathi': 'પરિણય ઉત્સવ',
        'Punjabi': 'ਪਰਿਣਯ ਉਤਸਵ',
        'Urdu': 'پرینائے اتسو'
      }, lang);

  String sangLabelFor(String lang) => _tFor({
        'English': 'with',
        'Gujarati': 'સંગ',
        'Hindi': 'संग',
        'Marathi': 'સંગ',
        'Punjabi': 'ਸੰਗ',
        'Urdu': 'سنگ'
      }, lang);

  String nimantrakLabelFor(String lang) => _tFor({
        'English': 'Inviter',
        'Gujarati': 'નિમંત્રક',
        'Hindi': 'निमंत्रक',
        'Marathi': 'નિમંત્રક',
        'Punjabi': 'ਨਿਮੰਤਰਕ',
        'Urdu': 'نمنترک'
      }, lang);

  String taLabelFor(String lang) => _tFor({
        'English': 'Date',
        'Gujarati': 'તા.',
        'Hindi': 'ता.',
        'Marathi': 'તા.',
        'Punjabi': 'ਮਿਤੀ',
        'Urdu': 'تاریخ'
      }, lang);

  String samayLabelFor(String lang) => _tFor({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'समय',
        'Marathi': 'વેળ',
        'Punjabi': 'ਸਮਾਂ',
        'Urdu': 'وقت'
      }, lang);

  String chiLabelFor(String lang) => _tFor({
        'English': 'Chi.',
        'Gujarati': 'ચિ.',
        'Hindi': 'चि.',
        'Marathi': 'ચિ.',
        'Punjabi': 'ਚਿ.',
        'Urdu': 'عزیز'
      }, lang);

  String sthalLabelFor(String lang) => _tFor({
        'English': 'Venue',
        'Gujarati': 'સ્થળ',
        'Hindi': 'स्थान',
        'Marathi': 'સ્થળ',
        'Punjabi': 'ਸਥਾਨ',
        'Urdu': 'مقام'
      }, lang);

  String weddingCeremonyLabelFor(String lang) => _tFor({
        'English': 'Wedding Ceremony',
        'Gujarati': 'લગ્ન વિધિ',
        'Hindi': 'विवाह समारोह',
        'Marathi': 'વિવાહ સોહળા',
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
        'Marathi': 'પ્રસંગ ઉમેરો',
        'Punjabi': 'ਪ੍ਰੋਗਰਾਮ ਜੋੜੋ',
        'Urdu': 'تقریب شامل کریں'
      });
  String get generateContentLabel => _t({
        'English': 'Generate Content',
        'Gujarati': 'કન્ટેન્ટ બનાવો',
        'Hindi': 'सामग्री बनाएं',
        'Marathi': 'કન્ટેન્ટ બનાવો',
        'Punjabi': 'ਸਮੱਗરી ਤਿਆਰ ਕਰੋ',
        'Urdu': 'مواد تیار کریں'
      });
  String get previewLabel => _t({
        'English': 'Preview',
        'Gujarati': 'પૂર્વાવલોકન',
        'Hindi': 'पूर्वावलोकन',
        'Marathi': 'પૂર્વાવલોકન',
        'Punjabi': 'ਪੂਰਵ દરਸ਼ਨ',
        'Urdu': 'پیش نظارہ'
      });
  String get nextLabel => _t({
        'English': 'Next',
        'Gujarati': 'આગળ',
        'Hindi': 'आगे',
        'Marathi': 'આગળ',
        'Punjabi': 'ਅੱਗੇ',
        'Urdu': 'اگلا'
      });
  String get back => _t({
        'English': 'Back',
        'Gujarati': 'પાછળ',
        'Hindi': 'પીછે',
        'Marathi': 'માગે',
        'Punjabi': 'ਪਿੱਛੇ',
        'Urdu': 'پیچھے'
      });
  String get weddingDateLabel => _t({
        'English': 'Wedding Date',
        'Gujarati': 'લગ્ન તારીખ',
        'Hindi': 'शादी की तारीख',
        'Marathi': 'લગ્નાચી તારીખ',
        'Punjabi': 'ਵਿਆਹ ਦੀ ਤਾਰੀਖ',
        'Urdu': 'شادی کی تاریخ'
      });
  String get eventNameLabel => _t({
        'English': 'Event Name',
        'Gujarati': 'પ્રસંગનું નામ',
        'Hindi': 'कार्यक्रम का नाम',
        'Marathi': 'પ્રસંગાચે નાવ',
        'Punjabi': 'ਪ੍ਰੋਗਰਾਮ ਦਾ ਨਾਮ',
        'Urdu': 'تقریب کا نام'
      });
  String get ratingSubtitle => _t({
        'English': "We'd love to hear your feedback.",
        'Gujarati': 'અમે તમારો પ્રતિસાદ સાંભળવા માંગીએ છીએ.',
        'Hindi': 'हम आपकी प्रतिक्रिया सुनना चाहेंगे.',
        'Marathi': 'અમ્હાલા તુમચા પ્રતિસાદ આયકાયલા આવડેલ.',
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
        'Marathi': 'તારીખ',
        'Punjabi': 'ਤਾਰੀਖ',
        'Urdu': 'تاریخ'
      });
  String get timeLabel => _t({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'સમય',
        'Marathi': 'વેળ',
        'Punjabi': 'ਸਮਾਂ',
        'Urdu': 'وقت'
      });
  String get venuePlaceLabel => _t({
        'English': 'Venue / Place',
        'Gujarati': 'સ્થળ / જગ્યા',
        'Hindi': 'સ્થાન / જગહ',
        'Marathi': 'સ્થળ',
        'Punjabi': 'ਸਥਾਨ',
        'Urdu': 'مقام'
      });
  String get weddingDetailsLabel => _t({
        'English': 'Wedding Details',
        'Gujarati': 'લગ્નની વિગત',
        'Hindi': 'शादी का विवरण',
        'Marathi': 'લગ્નાચા તપશીલ',
        'Punjabi': 'ਵਿਆਹ ਦੇ ਵੇਰਵੇ',
        'Urdu': 'شادی کی تفصیلات'
      });
  String get brideName => _t({
        'English': "Bride's Name",
        'Gujarati': "કન્યાનું નામ",
        'Hindi': "दुल्हन का नाम",
        'Marathi': "નવરીચે નાવ",
        'Punjabi': "ਵਹੁਟੀ ਦਾ ਨਾਮ",
        'Urdu': 'دلہن کا نام'
      });
  String get groomName => _t({
        'English': "Groom's Name",
        'Gujarati': "વરનું નામ",
        'Hindi': "दूल्हे का नाम",
        'Marathi': "નવરદેવાચે નાવ",
        'Punjabi': "ਲਾੜੇ ਦਾ ਨਾਮ",
        'Urdu': 'دولہے کا نام'
      });
  String get getStartedLabel => _t({
        'English': 'Get Started',
        'Gujarati': 'શરૂ કરો',
        'Hindi': 'शुरू करें',
        'Marathi': 'સુરૂ કરા',
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
        'Marathi': 'ડાઉનલોડ આણિ શેર કરા',
        'Punjabi': 'ਡਾਊਨਲੋਡ ਅਤੇ ਸਾਂਝਾ ਕਰੋ',
        'Urdu': 'ڈاؤن لوڈ اور شیئر کریں'
      });

  String get invitationLanguageLabel => _t({
        'English': 'Invitation Language',
        'Gujarati': 'આમંત્રણ ભાષા',
        'Hindi': 'निमंत्रण भाषा',
        'Marathi': 'નિમંત્રણ ભાષા',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾ',
        'Urdu': 'دعوت نامہ کی زبان'
      });
  String get rotationLabel => _t({
        'English': 'Rotation',
        'Gujarati': 'પરિભ્રમણ',
        'Hindi': 'રોટેશન',
        'Marathi': 'રોટેશન',
        'Punjabi': 'ਰੋਟੇਸ਼ਨ',
        'Urdu': 'گھماؤ'
      });
  String get opacityLabel => _t({
        'English': 'Opacity',
        'Gujarati': 'પારદર્શિતા',
        'Hindi': 'અપારદર્શિતા',
        'Marathi': 'અપારદર્શકતા',
        'Punjabi': 'ਪਾਰਦਰਸ਼ਤਾ',
        'Urdu': 'دھندلاپن'
      });
  String get chooseColorLabel => _t({
        'English': 'Choose Color',
        'Gujarati': 'રંગ પસંદ કરો',
        'Hindi': 'રંગ ચુને',
        'Marathi': 'રંગ પસંદ કરા',
        'Punjabi': 'ਰੰਗ ਚੁਣੋ',
        'Urdu': 'رنگ منتخب کریں'
      });

  // 👥 GUEST MANAGEMENT
  String get editGuest => _t({
        'English': 'Edit Guest',
        'Gujarati': 'મહેમાન સંપાદિત કરો',
        'Hindi': 'अतिथि संपादित करें',
        'Marathi': 'પાહુણે સંપાદિત કરા',
        'Punjabi': 'ਮਹਿਮਾਨ ਨੂੰ ਸੋਧੋ',
        'Urdu': 'مہمان کی ترمیم کریں'
      });
  String get deleteGuest => _t({
        'English': 'Delete Guest',
        'Gujarati': 'મહેમાન કાઢી નાખો',
        'Hindi': 'अतिथि हटाएं',
        'Marathi': 'પાહુણે કાઢૂન ટાકા',
        'Punjabi': 'ਮਹਿਮਾਨ ਨੂੰ ਹਟਾਓ',
        'Urdu': 'مہمان کو حذف کریں'
      });
  String get saveChanges => _t({
        'English': 'Save Changes',
        'Gujarati': 'ફેરફારો સાચવો',
        'Hindi': 'बदलाव सहेजें',
        'Marathi': 'બદલ જતન કરા',
        'Punjabi': 'ਤਬਦੀਲੀਆਂ ਸੁਰੱਖਿਅਤ ਕਰੋ',
        'Urdu': 'تبدیلیاں محفوظ کریں'
      });
  String get guestUpdated => _t({
        'English': 'Guest updated successfully!',
        'Gujarati': 'મહેમાન સફળતાપૂર્વક અપડેટ થયા!',
        'Hindi': 'अतिथि सफलतापूर्वक अपडेट किया गया!',
        'Marathi': 'પાહુણે યશસ્વીપણે અપડેટ ઝાલે!',
        'Punjabi': 'ਮਹਿਮਾਨ ਸਫਲਤਾਪੂਰਵਕ ਅਪਡੇਟ ਕੀਤਾ ਗਿਆ!',
        'Urdu': '!مہمان کامیابی کے ساتھ اپ ڈیٹ ہو گیا'
      });
  String get delete => _t({
        'English': 'Delete',
        'Gujarati': 'કાઢી નાખો',
        'Hindi': 'हटाएं',
        'Marathi': 'કાઢા',
        'Punjabi': 'ਹਟਾਓ',
        'Urdu': 'حذف کریں'
      });
  String get guestRemoved => _t({
        'English': 'Guest removed.',
        'Gujarati': 'મહેમાન દૂર કર્યા.',
        'Hindi': 'अतिथि हटा दिया गया.',
        'Marathi': 'પાહુણે કાઢલે.',
        'Punjabi': 'ਮਹਿਮਾਨ ਹਟਾ ਦਿੱਤਾ ਗਿਆ।',
        'Urdu': '.مہمان کو ہٹا دیا گیا'
      });
  String get noGuestsToExport => _t({
        'English': 'No guests to export.',
        'Gujarati': 'નિકાસ કરવા માટે કોઈ મહેમાન નથી.',
        'Hindi': 'निर्यात करने के लिए कोई अतिथि नहीं हैं.',
        'Marathi': 'નિર્ષાત કરણ્યાસાઠી પાહુણે નાહીત.',
        'Punjabi': 'ਨਿਰਯਾਤ ਕਰਨ ਲਈ ਕੋਈ ਮਹਿਮਾਨ ਨਹੀਂ ਹੈ।',
        'Urdu': '.برآمد کرنے کے لیے کوئی مہمان نہیں ہے'
      });
  String get exportGuestList => _t({
        'English': 'Export Guest List',
        'Gujarati': 'મહેમાન યાદી નિકાસ કરો',
        'Hindi': 'अतिथि सूची निर्यात करें',
        'Marathi': 'પાહુણે યાદી નિર્ષાત કરા',
        'Punjabi': 'ਮਹਿਮਾਨ ਸੂਚੀ ਨਿਰਯਾਤ ਕਰੋ',
        'Urdu': 'مہمانوں کی فہرست برآمد کریں'
      });
  String get chooseExportFormat => _t({
        'English': 'Choose export format',
        'Gujarati': 'નિકાસ ફોર્મેટ પસંદ કરો',
        'Hindi': 'निर्यात प्रारूप चुनें',
        'Marathi': 'નિર્ષાત પ્રારૂપ નિવડા',
        'Punjabi': 'ਨਿਰਯਾਤ ਫਾਰਮੈਟ ਚੁਣੋ',
        'Urdu': 'ایکسپورٹ فارمیٹ منتخب کریں'
      });
  String get csvFile => _t({
        'English': 'CSV File',
        'Gujarati': 'CSV ફાઇલ',
        'Hindi': 'CSV फ़ाइल',
        'Marathi': 'CSV ફાઇલ',
        'Punjabi': 'CSV ਫਾਈਲ',
        'Urdu': 'سی ایس وی فائل'
      });
  String get csvSubtitle => _t({
        'English': 'For Excel / Google Sheets',
        'Gujarati': 'એક્સેલ / ગૂગલ શીટ્સ માટે',
        'Hindi': 'एक्सेल / गूगल शीट्स के लिए',
        'Marathi': 'એક્સેલ / ગૂગલ શીટ્સસાઠી',
        'Punjabi': 'ਐਕਸਲ / ਗੂਗਲ ਸ਼ੀਟਸ ਲਈ',
        'Urdu': 'ایکسل / گوگل شیٹس کے لیے'
      });
  String get vcfContacts => _t({
        'English': 'VCF Contacts',
        'Gujarati': 'VCF સંપર્કો',
        'Hindi': 'VCF संपर्क',
        'Marathi': 'VCF સંપર્ક',
        'Punjabi': 'VCF ਸੰਪਰਕ',
        'Urdu': 'وی سی ایف روابط'
      });
  String get vcfSubtitle => _t({
        'English': 'Import to Phone Contacts',
        'Gujarati': 'ફોન સંપર્કોમાં આયાત કરો',
        'Hindi': 'फ़ोन संपर्कों में आयात करें',
        'Marathi': 'ફોન સંપર્કાત આયાત કરા',
        'Punjabi': 'ਫੋਨ ਸੰਪਰਕਾਂ ਵਿੱਚ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'فون روابط میں درآمد کریں'
      });
  String get pdfDocument => _t({
        'English': 'PDF Document',
        'Gujarati': 'PDF દસ્તાવેજ',
        'Hindi': 'PDF दस्तावेज़',
        'Marathi': 'PDF દસ્તાવેજ',
        'Punjabi': 'PDF ਦਸਤਾਵੇਜ਼',
        'Urdu': 'پی ڈی ایف دستاویز'
      });
  String get pdfSubtitle => _t({
        'English': 'For Printing / Sharing',
        'Gujarati': 'પ્રિન્ટિંગ / શેરિંગ માટે',
        'Hindi': 'प्रिंटिंग / शेयरિંગ के लिए',
        'Marathi': 'પ્રિન્ટિંગ / શેરિંગસાઠી',
        'Punjabi': 'ਪ੍ਰਿੰਟਿੰਗ / ਸ਼ੇਅਰਿੰਗ ਲਈ',
        'Urdu': 'پرنٹنگ / شیئرنگ کے لیے'
      });

  String deleteGuestConfirm(String name) => _t({
        'English': 'Are you sure you want to delete $name?',
        'Gujarati': 'શું તમે ખરેખર $name ને કાઢી નાખવા માંગો છો?',
        'Hindi': 'क्या आप वाकई $name को हटाना चाहते हैं?',
        'Marathi': 'કા તુમ્હાલા ખરોખર $name કાઢૂન ટાકાયચે આહે?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨੀ ਤੌਰ ਤੇ $name ਨੂੰ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی $name کو حذف کرنا چاہتے ہیں؟',
      });

  // ⭐ RATING DIALOG
  String get thanks => _t({
        'English': 'Thanks!',
        'Gujarati': 'આભાર!',
        'Hindi': 'धन्यवाद!',
        'Marathi': 'આભાર!',
        'Punjabi': 'ਧੰਨਵਾਦ!',
        'Urdu': 'شکریہ!'
      });

  String get submit => _t({
        'English': 'Submit',
        'Gujarati': 'સબમિટ કરો',
        'Hindi': 'सबमिट करें',
        'Marathi': 'સબમિટ કરા',
        'Punjabi': 'ਸਬਮਿਟ ਕਰੋ',
        'Urdu': 'جمع کروائیں'
      });
  String get noThanks => _t({
        'English': 'No, Thanks',
        'Gujarati': 'ના, આભાર',
        'Hindi': 'नहीं, धन्यवाद',
        'Marathi': 'નાહી, આભાર',
        'Punjabi': 'ਨਹੀਂ, ਧੰਨਵਾਦ',
        'Urdu': 'نہیں، شکریہ'
      });

  // 🎉 SUCCESS SCREEN
  String get finalizingDesign => _t({
        'English': 'Please wait, finalizing your design...',
        'Gujarati': 'તમારી ડિઝાઇનને આખરી ઓપ આપી રહ્યા છીએ...',
        'Hindi': 'आपकी डिझाइन को अंतिम रूप दे रहे हैं...',
        'Marathi': 'તુમચી ડિઝાઇન અંતિમ કરત આહોત...',
        'Punjabi': 'ਤੁਹਾਡੇ ਡਿਜ਼ਾਈਨ ਨੂੰ ਅੰਤਿਮ ਰੂਪ ਦਿੱਤਾ ਜਾ ਰਿਹਾ ਹੈ...',
        'Urdu': 'آپ کے ڈیزائن کو حتمی شکل دی جا رہی ہے...'
      });
  String get savedToDownloads => _t({
        'English': 'It will be saved to your Downloads folder',
        'Gujarati': 'ડાઉનલોડ્સમાં સાચવ્યું',
        'Hindi': 'डाउनलोड में सहेजा गया',
        'Marathi': 'ડાઉનલોડ્સમધ્યે જતન કેલે',
        'Punjabi': 'ਡਾਊਨਲੋਡਾਂ ਵਿੱਚ ਸੁਰੱਖਿਅਤ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'ڈاؤن لوڈز میں محفوظ کر لیا گیا'
      });
  String get openPdf => _t({
        'English': 'Open PDF',
        'Gujarati': 'PDF ખોલો',
        'Hindi': 'PDF खोलें',
        'Marathi': 'PDF ઉઘડા',
        'Punjabi': 'PDF ਖੋਲ੍ਹੋ',
        'Urdu': 'پی ڈی ایف کھولیں'
      });
  String get edit => _t({
        'English': 'Edit',
        'Gujarati': 'સંપાદિત કરો',
        'Hindi': 'एडिट करें',
        'Marathi': 'સંપાદિત કરા',
        'Punjabi': 'ਸੋਧੋ',
        'Urdu': 'ترمیم کریں'
      });
  String get shareWith => _t({
        'English': 'Share with',
        'Gujarati': 'શેર કરો',
        'Hindi': 'इसके साथ साझा करें',
        'Marathi': 'યાંચ્યાસોબત શેર કરા',
        'Punjabi': 'ਨਾਲ સਾਂਝਾ કરો',
        'Urdu': 'کے ساتھ شیئر کریں'
      });

  // 🚪 PROFILE & LOGOUT
  String get comingSoon => _t({
        'English': 'Coming Soon',
        'Gujarati': 'ટૂંક સમયમાં આવી રહ્યું છે',
        'Hindi': 'जल्द आ रहा है',
        'Marathi': 'લવકરચ યેત આહે',
        'Punjabi': 'ਜਲਦੀ ਆ ਰਿਹਾ ਹੈ',
        'Urdu': 'جلد آرہا ہے'
      });
  String get logoutConfirmation => _t({
        'English': 'Logout Confirmation',
        'Gujarati': 'લોગઆઉટ કન્ફર્મેશન',
        'Hindi': 'लॉगआउट पुष्टिकरण',
        'Marathi': 'લૉગઆઉટ પુષ્ટીકરણ',
        'Punjabi': 'ਲੌਗਆਊਟ ਪੁਸ਼ਟੀਕਰਨ',
        'Urdu': 'لاگ آؤٹ کی تصدیق'
      });
  String get logoutMessage => _t({
        'English': 'Are you sure you want to logout?',
        'Gujarati': 'શું તમે ખરેખર લોગઆઉટ કરવા માંગો છો?',
        'Hindi': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
        'Marathi': 'કા તુમ્હાલા ખરોખર લૉગઆઉટ કરાયચે આહે?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨੀ ਤੌਰ ਤੇ ਲੌਗਆਊਟ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
      });
  String get confirm => _t({
        'English': 'Confirm',
        'Gujarati': 'પુષ્ટિ કરો',
        'Hindi': 'पुष्टि करें',
        'Marathi': 'પુષ્ટી કરા',
        'Punjabi': 'ਪੁਸ਼ટી ਕਰੋ',
        'Urdu': 'تصدیق کریں'
      });

  // 📋 GUEST FILTERS & OPTIONS
  String get noGuestsYet => _t({
        'English': 'No guests yet',
        'Gujarati': 'હજુ કોઈ મહેમાન નથી',
        'Hindi': 'अभी तक कोई अतिथि नहीं',
        'Marathi': 'અજૂન પાહુણે નાહીત',
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
            'તુમચા લગ્ન નિમંત્રણાનચે કાર્યક્ષમપણે વ્યવસ્થાપન કરણ્યાસાઠી પાહુણે જોડણ્યાસ સુરુવાત કરા.',
        'Punjabi':
            'ਆਪਣੇ ਵਿਆਹ ਦੇ ਸੱਦੇ ਨੂੰ ਕੁਸ਼ਲਤਾ ਨਾਲ ਪ੍ਰਬੰਧਿਤ ਕਰਨ ਲਈ ਮਹਿਮਾਨਾਂ ਨੂੰ ਜੋੜਨਾ ਸ਼ੁਰੂ ਕਰੋ।',
        'Urdu':
            'اپنی شادی کے دعوت ناموں کو مؤثر طریقے سے منظم کرنے کے لیے مہمانوں کو شامل کرنا شروع کریں۔'
      });
  String get addGuest => _t({
        'English': 'Add Guest',
        'Gujarati': 'મહેમાન ઉમેરો',
        'Hindi': 'अतिथि जोड़ें',
        'Marathi': 'પાહુણે જોડા',
        'Punjabi': 'ਮਹਿਮਾਨ ਜੋੜੋ',
        'Urdu': 'مہمان شامل کریں'
      });
  String get searchGuests => _t({
        'English': 'Search Guests...',
        'Gujarati': 'મહેમાનો શોધો...',
        'Hindi': 'अतिथि खोजें...',
        'Marathi': 'પાહુણે શોધા...',
        'Punjabi': 'ਮਹਿਮਾਨ ਲੱਭੋ...',
        'Urdu': 'مہمان تلاش کریں...'
      });
  String get all => _t({
        'English': 'All',
        'Gujarati': 'બધા',
        'Hindi': 'सभी',
        'Marathi': 'સર્વ',
        'Punjabi': 'ਸਾਰੇ',
        'Urdu': 'تمام'
      });
  String get sent => _t({
        'English': 'Sent',
        'Gujarati': 'મોકલેલ',
        'Hindi': 'भेजा गया',
        'Marathi': 'પાઠવલેલે',
        'Punjabi': 'ਭੇਜਿਆ ਗਿਆ',
        'Urdu': 'بھیجا گیا'
      });
  String get pending => _t({
        'English': 'Pending',
        'Gujarati': 'બાકી',
        'Hindi': 'लंबित',
        'Marathi': 'બાકી',
        'Punjabi': 'ਬਾਕી',
        'Urdu': 'زیر التواء'
      });
  String get viewed => _t({
        'English': 'Viewed',
        'Gujarati': 'જોયેલ',
        'Hindi': 'देखा गया',
        'Marathi': 'પહિલેલે',
        'Punjabi': 'ਵੇખ્યા ગયા',
        'Urdu': 'دیکھا گیا'
      });
  String get noGuestsMatch => _t({
        'English': 'No guests match your search',
        'Gujarati': 'તમારી શોધ સાથે કોઈ મહેમાન મળતા નથી',
        'Hindi': 'आपकी खोज से कोई अतिथि मेल नहीं खाता',
        'Marathi': 'તુમચા શોધાશી કોણતેહી પાહુણે મિળત નાહીત',
        'Punjabi': 'ਤੁਹਾਡੀ ਖੋਜ ਨਾਲ કોઈ ਮਹਿਮਾਨ ਨਹੀਂ ਮਿਲਦਾ',
        'Urdu': 'آپ کی تلاش سے کوئی مہمان مطابقت نہیں رکھتا'
      });
  String get addManually => _t({
        'English': 'Add Manually',
        'Gujarati': 'જાતે ઉમેરો',
        'Hindi': 'स्वयं जोड़ें',
        'Marathi': 'વૈયક્તિક રિત્યા જોડા',
        'Punjabi': 'ਖੁਦ ਜੋੜੋ',
        'Urdu': 'دستی طور પર शामिल करें'
      });
  String get enterGuestDetail => _t({
        'English': 'Enter guest details manually',
        'Gujarati': 'મહેમાનની વિગતો જાતે દાખલ કરો',
        'Hindi': 'अतिथि विवरण स्वयं दर्ज करें',
        'Marathi': 'પાહુણ્યાંચા તપશીલ વૈયક્તિક રિત્યા ભરા',
        'Punjabi': 'ਮਹਿਮਾਨ ਦੇ ਵੇਰવે ਖੁਦ ਦਰਜ ਕਰੋ',
        'Urdu': 'مہمان کی تفصیلات دستی طور پر درج کریں'
      });
  String get importContacts => _t({
        'English': 'Import Contacts',
        'Gujarati': 'સંપર્કો આયાત કરો',
        'Hindi': 'संपर्क आयात करें',
        'Marathi': 'સંપર્ક આયાત કરા',
        'Punjabi': 'ਸੰਪਰਕ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'روابط درآمد کریں'
      });
  String get importFromContacts => _t({
        'English': 'Import from phone contacts',
        'Gujarati': 'ફોન સંપર્કોમાંથી આયાત કરો',
        'Hindi': 'फ़ोन संपर्कों से आयात करें',
        'Marathi': 'ફોન સંપર્કાંતૂન આયાત કરા',
        'Punjabi': 'ਫੋਨ ਸੰਪਰਕਾਂ ਤੋਂ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'فون روابط سے درآمد کریں'
      });
  String get importCsvVcf => _t({
        'English': 'Import CSV/VCF',
        'Gujarati': 'CSV/VCF આયાત કરો',
        'Hindi': 'CSV/VCF आयात करें',
        'Marathi': 'CSV/VCF આયાત કરા',
        'Punjabi': 'CSV/VCF ਆਯਾਤ ਕਰੋ',
        'Urdu': 'سی ایس وی / وی سی ایف درآمد کریں'
      });
  String get importFromFile => _t({
        'English': 'Import from CSV or VCF file',
        'Gujarati': 'CSV અથવા VCF ફાઇલમાંથી આયાત કરો',
        'Hindi': 'CSV या VCF फ़ाइल से आयात करें',
        'Marathi': 'CSV કિવા VCF ફાઇલમધૂન આયાત કરા',
        'Punjabi': 'CSV ਜਾਂ VCF ਫਾਈਲ ਤੋਂ ਆਯਾਤ ਕਰੋ',
        'Urdu': 'سی ایس وی یا وی سی ایف فائل سے درآمد کریں'
      });

  String guestsCount(int count) => _t({
        'English': '$count Guests',
        'Gujarati': '$count મહેમાનો',
        'Hindi': '$count अतिथि',
        'Marathi': '$count પાહુણે',
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
        'Marathi': '૫૦૦+ ટેમ્પ્લેટ્સ',
        'Punjabi': '500+ ਟੈਂਪਲੇਟਸ',
        'Urdu': '500+ ٹیمپلیٹس'
      });
  String get easyCustomize => _t({
        'English': 'Easy to Customize',
        'Gujarati': 'કસ્ટમાઇઝ કરવું સરળ',
        'Hindi': 'कस्टमाइज़ करना आसान',
        'Marathi': 'સાનુકૂલિત કરણ્યાસ સોપે',
        'Punjabi': 'ਅਨੁਕੂਲਿਤ ਕਰਨਾ ਆਸਾਨ',
        'Urdu': 'اپنی مرضی کے مطابق بنانا آسان ہے'
      });
  String get shareInstantly => _t({
        'English': 'Share Instantly',
        'Gujarati': 'તરત જ શેર કરો',
        'Hindi': 'तुरंत साझा करें',
        'Marathi': 'તરત શેર કરા',
        'Punjabi': 'ਤੁਰੰਤ ਸਾਂਝਾ ਕਰੋ',
        'Urdu': 'فوری شیئر کریں'
      });
  String get chooseAppLanguage => _t({
        'English': 'Choose App Language',
        'Gujarati': 'એપ ભાષા પસંદ કરો',
        'Hindi': 'ऐप भाषा चुनें',
        'Marathi': 'અપ્ ભાષા નિવડા',
        'Punjabi': 'ਐਪ ਭਾਸ਼ਾ ਚੁਣੋ',
        'Urdu': 'ایپ کی زبان منتخب کریں'
      });
  String get selectPreferredLanguage => _t({
        'English': 'Select your preferred language to use the app.',
        'Gujarati': 'એપનો ઉપયોગ કરવા માટે તમારી પસંદગીની ભાષા પસંદ કરો.',
        'Hindi': 'ऐप का उपयोग करने के लिए अपनी पसंदीदा भाषा चुनें.',
        'Marathi': 'અપ્ વાપરણ્યાસાઠી તુમચી આવડતી ભાષા નિવડા.',
        'Punjabi': 'ਐਪ ਦੀ ਵਰਤੋਂ ਕਰਨ ਲਈ ਆਪਣੀ ਪਸੰਦੀਦਾ ਭਾਸ਼ਾ ਚੁਣੋ।',
        'Urdu': 'ایپ استعمال کرنے کے لیے اپنی پسندیدہ زبان منتخب کریں۔'
      });
  String get customizeInvitationLanguages => _t({
        'English': 'Customize Invitation Languages',
        'Gujarati': 'આમંત્રણ ભાષાઓ કસ્ટમાઇઝ કરો',
        'Hindi': 'निमंत्रण भाषाएं कस्टमाइज़ करें',
        'Marathi': 'નિમંત્રણ ભાષા સાનુકૂલિત કરા',
        'Punjabi': 'ਸੱਦਾ ਭਾਸ਼ਾਵਾਂ ਨੂੰ ਅਨੁਕੂਲਿਤ ਕਰੋ',
        'Urdu': 'دعوت نامہ کی زبانیں اپنی مرضی کے مطابق بنائیں'
      });
  String get chooseInvitationLanguagesDescription => _t({
        'English': 'Select the languages you want to use for your invitations.',
        'Gujarati':
            'તમારા આમંત્રણો માટે તમે જે ભાષાઓ વાપરવા માંગો છો તે પસંદ કરો.',
        'Hindi':
            'उन भाषाओं को चुनें जिन्हें आप अपने निमंत्रणों के लिए उपयोग करना चाहते हैं.',
        'Marathi': 'તુમચા નિમંત્રણાસાઠી તુમ્હાલા વાપરચલેલ્યા ભાષા નિવડા.',
        'Punjabi': 'ਉਹ ਭਾਸ਼ਾਵਾਂ ਚੁਣੋ ਜੋ ਤੁਸੀਂ ਆਪਣੇ ਸੱਦੇ ਲਈ ਵਰਤਣਾ ਚਾਹੁੰਦੇ ਹੋ।',
        'Urdu':
            'وہ زبانیں منتخب کریں جو آپ اپنے دعوت ناموں کے لیے استعمال کرنا چاہتے ہیں۔'
      });
  String get createInvitationSteps => _t({
        'English': 'Create Invitation in 3 Steps',
        'Gujarati': '૩ સ્ટેપમાં આમંત્રણ બનાવો',
        'Hindi': '3 स्टेप में निमंत्रण बनाएं',
        'Marathi': '૩ પાયર્યાંત નિમંત્રણ બનાવા',
        'Punjabi': '3 ਕਦਮਾਂ ਵਿੱਚ ਸੱਦਾ ਬਣਾਓ',
        'Urdu': '3 مراحل میں دعوت نامہ بنائیں'
      });
  String get exploreCategoriesDescription => _t({
        'English': 'Explore various categories of invitations.',
        'Gujarati': 'આમંત્રણોની વિવિધ શ્રેણીઓ શોધો.',
        'Hindi': 'निमंत्रण की विभिन्न श्रेणियों का पता लगाएं.',
        'Marathi': 'નિમંત્રણાંચ્યા વિવિધ શ્રેણી પહા.',
        'Punjabi': 'ਸੱਦੇ ਦੀਆਂ ਵੱਖ-ਵੱਖ ਸ਼੍ਰੇਣੀਆਂ ਦੀ ਪੜਚੋਲ ਕਰੋ।',
        'Urdu': 'دعوت ناموں کے مختلف زمروں کو دریافت کریں۔'
      });
  String get chooseTemplate => _t({
        'English': 'Choose Template',
        'Gujarati': 'ટેમ્પ્લેટ પસંદ કરો',
        'Hindi': 'टेम्पलेट चुनें',
        'Marathi': 'ટેમ્પ્લેટ નિવડા',
        'Punjabi': 'ਟੈਂਪਲੇਟ ਚੁਣੋ',
        'Urdu': 'ٹیمپلیٹ منتخب کریں'
      });
  String get chooseTemplateDescription => _t({
        'English': 'Pick your favorite design from hundreds of templates.',
        'Gujarati': 'સેંકડો ટેમ્પ્લેટ્સમાંથી તમારી મનપસંદ ડિઝાઇન પસંદ કરો.',
        'Hindi': 'सैकड़ों टेम्पलेट्स में से अपना पसंदीदा डिझाइन चुनें.',
        'Marathi': 'શંકડો ટેમ્પ્લેટ્સમધૂન તુમચી આવડતી ડિઝાઇન નિવડા.',
        'Punjabi': 'ਸੈਂਕੜੇ ਟੈਂਪਲੇਟਾਂ ਵਿੱਚੋਂ ਆਪਣਾ ਮਨਪਸੰਦ ਡਿਜ਼ਾਈਨ ਚੁਣੋ।',
        'Urdu': 'سینکڑوں ٹیمپلیٹس میں سے اپنا پسندیدہ ڈیزائن منتخب کریں۔'
      });
  String get customizeCard => _t({
        'English': 'Customize Card',
        'Gujarati': 'કાર્ડ કસ્ટમાઇઝ કરો',
        'Hindi': 'कार्ड कस्टमाइज़ करें',
        'Marathi': 'કાર્ડ સાનુકૂલિત કરા',
        'Punjabi': 'ਕਾਰਡ ਨੂੰ ਅਨੁਕੂਲਿਤ ਕਰੋ',
        'Urdu': 'کارڈ کو اپنی مرضی کے مطابق بنائیں'
      });
  String get customizeCardDescription => _t({
        'English': 'Add your details and edit colors, fonts, and more.',
        'Gujarati': 'તમારી વિગતો ઉમેરો અને રંગો, ફોન્ટ્સ અને વધુ સંપાદિત કરો.',
        'Hindi': 'अपना विवरण जोड़ें और रंग, फ़ॉन्ट और बहुत कुछ संपादित करें.',
        'Marathi':
            'તુમચા તપશીલ જોડા આણિ રંગ, ફોન્ટ્સ આણિ ઘણું કાહી સંપાદિત કરા.',
        'Punjabi':
            'ਆਪਣੇ ਵੇਰਵੇ ਸ਼ਾਮਲ ਕਰੋ ਅਤੇ ਰੰਗ, ਫੋਂਟ ਅਤੇ ਹੋਰ ਬਹੁਤ ਕੁਝ ਸੰਪਾਦਿਤ ਕਰੋ।',
        'Urdu':
            'اپنی تفصیلات شامل کریں اور رنگ، فونٹ اور بہت کچھ میں ترمیم کریں۔'
      });
  String get downloadShareDescription => _t({
        'English': 'Download and share with your friends and family.',
        'Gujarati': 'ડાઉનલોડ કરો અને તમારા મિત્રો અને પરિવાર સાથે શેર કરો.',
        'Hindi': 'डाउनलोड करें और अपने दोस्तों और परिवार के साथ साझा करें.',
        'Marathi': 'ડાઉનલોડ કરા આણિ તુમચા મિત્ર આણિ કુટુંબા સોબત શેર કરા.',
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
        'Marathi': 'કોણતેહી ટેમ્પ્લેટ સાપડલે નાહી',
        'Punjabi': 'ਕੋਈ ਟੈਂਪਲੇਟ ਨਹੀਂ ਮਿਲਿਆ',
        'Urdu': 'کوئی ٹیمپلیٹ نہیں ملا'
      });
  String get searchResults => _t({
        'English': 'Search Results',
        'Gujarati': 'શોધ પરિણામો',
        'Hindi': 'खोज परिणाम',
        'Marathi': 'શોધ નિકાલ',
        'Punjabi': 'ਖੋਜ ਦੇ ਨਤੀਜੇ',
        'Urdu': 'تلاش کے نتائج'
      });
  String get deleteDesign => _t({
        'English': 'Delete Design',
        'Gujarati': 'ડિઝાઇન કાઢી નાખો',
        'Hindi': 'डिझाइन हटाएं',
        'Marathi': 'ડિઝાઇન કાઢા',
        'Punjabi': 'ਡਿਜ਼ਾਈਨ ਹਟਾਓ',
        'Urdu': 'ڈیزائن حذف کریں'
      });
  String get deleteDesignConfirm => _t({
        'English': 'Are you sure you want to delete this design?',
        'Gujarati': 'શું તમે ખરેખર આ ડિઝાઇન કાઢી નાખવા માંગો છો?',
        'Hindi': 'क्या आप वाकई इस डिझाइन को हटाना चाहते हैं?',
        'Marathi': 'કા તુમ્હાલા ખરોખર હી ડિઝાઇન કાઢાયચી આહે?',
        'Punjabi': 'ਕੀ ਤੁਸੀਂ ਯਕੀਨੀ ਤੌਰ ਤੇ ਇਸ ਡਿਜ਼ਾਈਨ ਨੂੰ ਹਟਾਉਣਾ ਚਾਹੁੰਦੇ ਹੋ?',
        'Urdu': 'کیا آپ واقعی اس ڈیزائن کو حذف کرنا چاہتے ہیں؟'
      });
  String get designDeleted => _t({
        'English': 'Design deleted successfully',
        'Gujarati': 'ડિઝાઇન સફળતાપૂર્વક કાઢી નાખવામાં આવી',
        'Hindi': 'डिझाइन सफलतापूर्वक हटा दी गई',
        'Marathi': 'ડિઝાઇન યશસ્વીપણે કાઢલી',
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
        'Marathi': 'મસુદા જતન કરા',
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
        'Marathi': 'કાઢૂન ટાકા',
        'Punjabi': 'ਰੱਦ ਕਰੋ',
        'Urdu': 'خارج کریں'
      });
  String get draftSaved => _t({
        'English': 'Draft saved successfully',
        'Gujarati': 'ડ્રાફ્ટ સફળતાપૂર્વક સાચવવામાં આવ્યો',
        'Hindi': 'ड्राफ्ट सफलतापूर्वक सहेजा गया',
        'Marathi': 'મસુદા યશસ્વીપણે જતન કેલા',
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
        'Marathi': 'તુમચ્યા રેટિંગસાઠી આભાર!',
        'Punjabi': 'ਤੁਹਾਡੀ ਰੇਟਿੰਗ ਲਈ ਧੰਨਵਾਦ!',
        'Urdu': 'آپ کی درجہ بندی کے لیے شکریہ!'
      });
  String get pleaseEnterName => _t({
        'English': 'Please enter your name',
        'Gujarati': 'મહેરબાની કરીને તમારું નામ દાખલ કરો',
        'Hindi': 'कृपया अपना नाम दर्ज करें',
        'Marathi': 'કૃપયા તુમચે નાવ ભરા',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਆਪਣਾ ਨਾਮ ਦਰਜ ਕਰੋ',
        'Urdu': 'براہ کرم اپنا نام درج کریں'
      });
  String get pleaseEnterPhone => _t({
        'English': 'Please enter a valid 10-digit phone number',
        'Gujarati': 'મહેરબાની કરીને માન્ય ૧૦-આંકડાનો ફોન નંબર દાખલ કરો',
        'Hindi': 'कृपया एक वैध 10-अंकीय फ़ोन नंबर दर्ज करें',
        'Marathi': 'કૃપયા ૧૦ અંકી વૈધ ફોન નંબર ભરા',
        'Punjabi': 'ਕਿਰਪਾ ਕਰਕੇ ਇੱਕ ਵੈਧ 10-ਅੰਕੀ ਫ਼ੋਨ ਨੰਬਰ ਦਰਜ ਕਰੋ',
        'Urdu': 'براہ کرم 10 ہندسوں کا درست فون نمبر درج کریں'
      });
  String get pleaseEnterEmail => _t({
        'English': 'Please enter a valid email address',
        'Gujarati': 'મહેરબાની કરીને માન્ય ઈમેલ એડ્રેસ દાખલ કરો',
        'Hindi': 'कृपया एक वैध ईमेल पता दर्ज करें',
        'Marathi': 'કૃપયા વૈધ ઈમેલ પત્તા ભરા',
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
        'Marathi': 'તારીખ',
        'Punjabi': 'ਤਾਰੀਖ',
        'Urdu': 'تاریخ'
      }, lang);
  String timeLabelFor(String lang) => _tFor({
        'English': 'Time',
        'Gujarati': 'સમય',
        'Hindi': 'समय',
        'Marathi': 'વેળ',
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
        'Marathi': 'આવડત્યાત જોડલે',
        'Punjabi': 'ਮਨਪਸੰਦ ਵਿੱਚ ਸ਼ਾਮਲ ਕੀਤਾ ਗਿਆ',
        'Urdu': 'پسندیدہ میں شامل کر دیا گیا'
      });
  String get removedFromFavorites => _t({
        'English': 'Removed from favorites',
        'Gujarati': 'પસંદગીમાંથી દૂર કર્યું',
        'Hindi': 'पसंदीदा से हटा दिया गया',
        'Marathi': 'આવડત્યાતૂન કાઢલે',
        'Punjabi': 'ਮਨਪਸੰਦ ਤੋਂ ਹਟਾ ਦਿੱਤਾ ਗਿਆ',
        'Urdu': 'پسندیدہ سے ہٹا دیا گیا'
      });
  String shareDesignText(String name) => _t({
        'English': 'Check out my design: $name',
        'Gujarati': 'મારી ડિઝાઇન જુઓ: $name',
        'Hindi': 'मेरी डिझाइन देखें: $name',
        'Marathi': 'માઝી ડિઝાઇન પહા: $name',
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
            'નિમંત્રણ પહા - સુંદર લગ્ન નિમંત્રણ બનાવા! આતાચ ડાઉનલોડ કરા.',
        'Punjabi': 'ਨਿਮੰਤਰਨ ਦੇਖੋ - ਸੁੰਦਰ ਵਿਆਹ ਦੇ ਸੱਦੇ ਬਣਾਓ! ਹੁਣੇ ਡਾਊਨਲੋਡ ਕਰੋ।',
        'Urdu':
            '!نمنترک دیکھیں - شادی کے خوبصورت دعوت نامے بنائیں! ابھی ڈاؤن لوڈ کریں',
      });
}
