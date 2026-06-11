import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/template_element.dart';
import 'language_registry.dart';

/// Invitation card translation engine.
///
/// PRIMARY: Google Translate (any admin-added language via ISO code).
/// FALLBACK: Offline transliteration for Gujarati typing in the editor.
class TransliterationEngine {
  // 🔴 SINGLETON
  static final TransliterationEngine _instance = TransliterationEngine._();
  factory TransliterationEngine() => _instance;
  TransliterationEngine._();

  final Map<String, String> _cache = {};

  Future<String> translateAsync(String text, String targetLang) async {
    if (text.isEmpty) return '';

    final String targetCode = _getIsoCode(targetLang);
    final cacheKey = 'trans_${targetCode}_$text';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final sourceCode = _detectSourceCode(text, targetLang);
    final direct = await _googleTranslate(text, sourceCode, targetCode);
    if (_isValidResult(direct, targetLang, text)) {
      _cache[cacheKey] = direct!;
      return direct;
    }

    // Gujarati → target (works for Sanskrit, Tamil, Bengali, etc.)
    if (TemplateElement.hasGujaratiScript(text) && sourceCode != targetCode) {
      final guResult = await _googleTranslate(text, 'gu', targetCode);
      if (_isValidResult(guResult, targetLang, text)) {
        _cache[cacheKey] = guResult!;
        return guResult;
      }

      final hindi = translateGujaratiToHindi(text);
      final hiResult = await _googleTranslate(hindi, 'hi', targetCode);
      if (_isValidResult(hiResult, targetLang, text)) {
        _cache[cacheKey] = hiResult!;
        return hiResult;
      }
    }

    // English → target for label strings
    if (sourceCode == 'en' && targetCode != 'en') {
      final enResult = await _googleTranslate(text, 'en', targetCode);
      if (_isValidResult(enResult, targetLang, text)) {
        _cache[cacheKey] = enResult!;
        return enResult;
      }
    }

    final transliterated = await transliterateAsync(text, lang: targetLang);
    if (_isValidResult(transliterated, targetLang, text)) {
      _cache[cacheKey] = transliterated;
      return transliterated;
    }
    return '';
  }

  bool _isValidResult(String? result, String targetLang, String source) =>
      result != null &&
      result.isNotEmpty &&
      result.trim() != source.trim() &&
      TemplateElement.isTranslationValid(result, targetLang, source);

  String _detectSourceCode(String text, String targetLang) {
    if (TemplateElement.hasGujaratiScript(text)) return 'gu';
    if (TemplateElement.hasDevanagariScript(text)) return 'hi';
    if (TemplateElement.hasArabicScript(text)) return 'ur';
    return 'en';
  }

  Future<String?> _googleTranslate(
      String text, String sourceCode, String targetCode) async {
    try {
      final url = Uri.parse(
          'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceCode&tl=$targetCode&dt=t&q=${Uri.encodeComponent(text)}');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (data.isNotEmpty && data[0] is List) {
          final StringBuffer sb = StringBuffer();
          for (var part in data[0]) {
            if (part is List && part.isNotEmpty) {
              sb.write(part[0]);
            }
          }
          final result = sb.toString().trim();
          if (result.isNotEmpty) return result;
        }
      }
    } catch (e) {
      print("Translation error: $e");
    }
    return null;
  }

  String _getIsoCode(String lang) =>
      LanguageRegistry.instance.isoCodeFor(lang);

  static const Map<String, String> _dictionary = {
    // Surnames
    'patel': 'પટેલ', 'shah': 'શાહ', 'modi': 'મોદી', 'desai': 'દેસાઈ',
    'mehta': 'મહેતા', 'joshi': 'જોશી', 'dave': 'દવે', 'trivedi': 'ત્રિવેદી',
    'pandya': 'પંડ્યા', 'bhatt': 'ભટ્ટ', 'vyas': 'વ્યાસ', 'raval': 'રાવલ',
    'parikh': 'પારીખ', 'thakkar': 'ઠક્કર', 'chauhan': 'ચૌહાણ',
    'solanki': 'સોલંકી',
    'rathod': 'રાઠોડ', 'parmar': 'પરમાર', 'chaudhary': 'ચૌધરી',
    'sharma': 'શર્મા',
    'acharya': 'આચાર્ય', 'amin': 'અમીન', 'barot': 'બારોટ', 'gajjar': 'ગજ્જર',
    'kanani': 'કાનાણી', 'mistry': 'મિસ્ત્રી', 'nagar': 'નાગર', 'rana': 'રાણા',
    'thakor': 'ઠાકોર', 'vaghela': 'વાઘેલા', 'jadeja': 'જાડેજા',
    'makwana': 'મકવાણા',
    'gohel': 'ગોહેલ', 'darji': 'દરજી', 'suthar': 'સુથાર',
    'prajapati': 'પ્રજાપતિ',
    'luhar': 'લુહાર', 'rabari': 'રબારી', 'koli': 'કોળી', 'thakar': 'ઠાકર',
    'soni': 'સોની', 'panchal': 'પંચાલ', 'narola': 'નરોલા',
    'khokhariya': 'ખોખરિયા',
    'savani': 'સવાણી', 'vaghani': 'વાઘાણી', 'kathiriya': 'કથીરિયા',
    'italiya': 'ઈટાલિયા',

    // Names (Male)
    'darshit': 'દર્શિત', 'harsh': 'હર્ષ', 'jay': 'જય', 'raj': 'રાજ',
    'amit': 'અમિત', 'nirav': 'નિરવ', 'kiran': 'કિરણ', 'vishal': 'વિશાલ',
    'deep': 'દીપ', 'ravi': 'રવિ', 'suresh': 'સુરેશ', 'ramesh': 'રમેશ',
    'mahesh': 'મહેશ', 'mukesh': 'મુકેશ', 'rakesh': 'રાકેશ', 'hitesh': 'હિતેશ',
    'jignesh': 'જિગ્નેશ', 'chirag': 'ચિરાગ', 'sagar': 'સાગર', 'viral': 'વિરલ',
    'maulik': 'મૌલિક', 'yash': 'યશ', 'dev': 'દેવ', 'krishna': 'કૃષ્ણા',
    'gopal': 'ગોપાલ', 'mohan': 'મોહન', 'vijay': 'વિજય', 'ajay': 'અજય',
    'sanjay': 'સંજય', 'dhruv': 'ધ્રુવ', 'parth': 'પાર્થ', 'arjun': 'અર્જુન',
    'rohan': 'રોહન', 'sahil': 'સાહિલ', 'kunal': 'કુનાલ', 'manthan': 'મંથન',
    'meet': 'મીત', 'het': 'હેત', 'shailesh': 'શૈલેષ', 'bhavesh': 'ભાવેશ',
    'paresh': 'પરેશ',

    // Names (Female)
    'darmi': 'દર્મી', 'priya': 'પ્રિયા', 'neha': 'નેહા', 'pooja': 'પૂજા',
    'nisha': 'નિશા', 'riya': 'રિયા', 'meera': 'મીરા', 'kavita': 'કવિતા',
    'hetal': 'હેતલ', 'komal': 'કોમલ', 'dipti': 'દિપ્તી', 'kruti': 'ક્રુતિ',
    'janki': 'જાનકી', 'radha': 'રાધા', 'sita': 'સીતા', 'anjali': 'અંજલી',
    'sneha': 'સ્નેહા', 'payal': 'પાયલ', 'dhara': 'ધારા', 'riddhi': 'રિદ્ધિ',
    'siddhi': 'સિદ્ધિ', 'mansi': 'માનસી', 'jinal': 'જીનલ', 'foram': 'ફોરમ',
    'kajal': 'કાજલ', 'mital': 'મિતલ', 'vaishali': 'વૈશાલી', 'kinjal': 'કિંજલ',
    'geeta': 'ગીતા', 'seema': 'સીમા',

    // Contextual
    'shri': 'શ્રી', 'smt': 'શ્રીમતી', 'chi': 'ચિ', 'kumar': 'કુમાર',
    'kumari': 'કુમારી', 'ben': 'બેન', 'bhai': 'ભાઈ', 'dada': 'દાદા',
    'dadi': 'દાદી', 'nana': 'નાના', 'nani': 'નાની', 'mama': 'મામા',
    'mami': 'મામી', 'kaka': 'કાકા', 'kaki': 'કાકી', 'fai': 'ફઈ',
    'fuva': 'ફુવા', 'masa': 'માસા', 'masi': 'માસી', 'bahen': 'બહેન',
    'parivar': 'પરિવાર', 'gam': 'ગામ', 'taluka': 'તાલુકા', 'jilla': 'જિલ્લા',
    'lagn': 'લગ્ન', 'lagna': 'લગ્ન', 'vidhhi': 'વિધિ', 'vidhi': 'વિધિ',
    'mandap': 'મંડપ', 'mangal': 'મંગળ', 'shubh': 'શુભ', 'nimantran': 'નિમંત્રણ',
    'kankotri': 'કંકોત્રી', 'aashirwad': 'આશીર્વાદ', 'swagat': 'સ્વાગત',
    'abhinandan': 'અભિનંદન', 'samaiyo': 'સમૈયો', 'bhojan': 'ભોજન',
    'rasotsav': 'રાસોત્સવ', 'haldi': 'હલ્દી', 'mehendi': 'મહેંદી',
    'sangeet': 'સંગીત', 'shobhayatra': 'શોભાયાત્રા',

    // Places
    'ahmedabad': 'અમદાવાદ', 'surat': 'સુરત', 'vadodara': 'વડોદરા',
    'rajkot': 'રાજકોટ', 'bhavnagar': 'ભાવનગર', 'jamnagar': 'જામનગર',
    'junagadh': 'જૂનાગઢ', 'gandhinagar': 'ગાંધીનગર', 'anand': 'આણંદ',
    'nadiad': 'નડિયાદ', 'bharuch': 'ભરૂચ', 'navsari': 'નવસારી',
    'valsad': 'વલસાડ', 'mehsana': 'મહેસાણા', 'palanpur': 'પાલનપુર',
    'morbi': 'મોરબી', 'porbandar': 'પોરબંદર', 'dwarka': 'દ્વારકા',
    'kutch': 'કચ્છ', 'bhuj': 'ભુજ', 'gujarat': 'ગુજરાત', 'india': 'ભારત',
  };

  /// Main transliteration (Synchronous)
  String transliterate(String input, {String lang = 'Gujarati'}) {
    if (input.isEmpty) return '';
    final words = input.split(' ');
    return words.map((w) => _transliterateWordSync(w, lang)).join(' ');
  }

  /// Async transliteration (Google API)
  Future<String> transliterateAsync(String input, {String lang = 'Gujarati'}) async {
    if (input.isEmpty) return '';

    // 🔥 OPTIMIZATION: For non-Gujarati languages, transliterate the entire string in one single request!
    if (lang != 'Gujarati') {
      final cacheKey = '${lang}_$input';
      if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

      final apiResult = await _googleTransliterate(input, lang);
      if (apiResult != null && apiResult.isNotEmpty) {
        _cache[cacheKey] = apiResult;
        return apiResult;
      }
      return input; // Fallback to original text if API fails
    }

    final words = input.split(' ');
    final results = <String>[];
    for (final word in words) {
      results.add(await _transliterateWordAsync(word, lang));
    }
    return results.join(' ');
  }

  String _transliterateWordSync(String word, String lang) {
    if (word.isEmpty) return '';
    final pb = _leadingPunct(word);
    if (pb.length == word.length) return word;

    final pa = _trailingPunct(word);
    final start = pb.length;
    final end = word.length - pa.length;

    if (start >= end) return word;

    final clean = word.substring(start, end);
    if (clean.isEmpty) return word;

    final lower = clean.toLowerCase();
    final cacheKey = '${lang}_$lower';
    if (_cache.containsKey(cacheKey)) return '$pb${_cache[cacheKey]}$pa';
    
    // Dictionary is only for Gujarati for now
    if (lang == 'Gujarati' && _dictionary.containsKey(lower)) {
      return '$pb${_dictionary[lower]}$pa';
    }

    // Default to phonetic only for Gujarati for now
    if (lang == 'Gujarati') {
      return '$pb${_phoneticTransliterate(clean)}$pa';
    }
    
    return word; // For other languages, we rely on async API
  }

  Future<String> _transliterateWordAsync(String word, String lang) async {
    if (word.isEmpty) return '';
    final pb = _leadingPunct(word);
    if (pb.length == word.length) return word;

    final pa = _trailingPunct(word);
    final end = word.length - pa.length;
    final start = pb.length;

    if (start >= end) return word;

    final clean = word.substring(start, end);
    if (clean.isEmpty) return word;

    final lower = clean.toLowerCase();
    final cacheKey = '${lang}_$lower';
    if (_cache.containsKey(cacheKey)) return '$pb${_cache[cacheKey]}$pa';
    
    if (lang == 'Gujarati' && _dictionary.containsKey(lower)) {
      return '$pb${_dictionary[lower]}$pa';
    }

    final api = await _googleTransliterate(clean, lang);
    if (api != null) {
      _cache[cacheKey] = api;
      return '$pb$api$pa';
    }

    if (lang == 'Gujarati') {
      final phonetic = _phoneticTransliterate(clean);
      _cache[cacheKey] = phonetic;
      return '$pb$phonetic$pa';
    }

    return word;
  }

  String _getItcCode(String lang) {
    switch (lang) {
      case 'Gujarati': return 'gu-t-i0-und';
      case 'Hindi': return 'hi-t-i0-und';
      case 'Marathi': return 'mr-t-i0-und';
      case 'Punjabi': return 'pa-t-i0-und';
      case 'Urdu': return 'ur-t-i0-und';
      default: return 'gu-t-i0-und';
    }
  }

  Future<String?> _googleTransliterate(String word, String lang) async {
    try {
      final itc = _getItcCode(lang);
      final url = Uri.parse(
          'https://inputtools.google.com/request?text=${Uri.encodeComponent(word)}&itc=$itc&num=1');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data[0] == 'SUCCESS') return data[1][0][1][0] as String;
      }
    } catch (_) {}
    return null;
  }

  String _leadingPunct(String s) {
    int i = 0;
    while (i < s.length && _isPunct(s[i])) {
      i++;
    }
    return s.substring(0, i);
  }

  String _trailingPunct(String s) {
    int i = s.length - 1;
    while (i >= 0 && _isPunct(s[i])) {
      i--;
    }
    return s.substring(i + 1);
  }

  bool _isPunct(String c) => '.,:;!?()[]{}"\'-/\\'.contains(c);

  // ─────────────────────────────────────────────────
  // 🔤 PHONETIC ENGINE
  // ─────────────────────────────────────────────────
  static const Map<String, String> _consonants = {
    'kh': 'ખ',
    'gh': 'ઘ',
    'chh': 'છ',
    'jh': 'ઝ',
    'Th': 'ઠ',
    'Dh': 'ઢ',
    'th': 'થ',
    'dh': 'ધ',
    'ph': 'ફ',
    'bh': 'ભ',
    'sh': 'શ',
    'Sh': 'ષ',
    'gn': 'જ્ઞ',
    'k': 'ક',
    'g': 'ગ',
    'ch': 'ચ',
    'j': 'જ',
    'T': 'ટ',
    'D': 'ડ',
    'N': 'ણ',
    't': 'ત',
    'd': 'દ',
    'n': 'ન',
    'p': 'પ',
    'b': 'બ',
    'm': 'મ',
    'y': 'ય',
    'r': 'ર',
    'l': 'લ',
    'v': 'વ',
    'w': 'વ',
    's': 'સ',
    'h': 'હ',
    'L': 'ળ',
    'f': 'ફ',
    'x': 'ક્ષ',
  };
  static const Map<String, String> _vowels = {
    'aa': 'આ',
    'ai': 'ઐ',
    'au': 'ઔ',
    'ee': 'ઈ',
    'oo': 'ઊ',
    'ou': 'ઔ',
    'a': 'અ',
    'i': 'ઇ',
    'u': 'ઉ',
    'e': 'એ',
    'o': 'ઓ',
    'Ri': 'ઋ',
  };
  static const Map<String, String> _matras = {
    'aa': 'ા',
    'ai': 'ૈ',
    'au': 'ૌ',
    'ee': 'ી',
    'oo': 'ૂ',
    'ou': 'ૌ',
    'a': '',
    'i': 'િ',
    'u': 'ુ',
    'e': 'ે',
    'o': 'ો',
    'Ri': 'ૃ',
  };

  String _phoneticTransliterate(String input) {
    final buffer = StringBuffer();
    final normalized = _normalize(input);
    int i = 0;
    bool lastCons = false;

    while (i < normalized.length) {
      final c = normalized[i];
      if ('0123456789'.contains(c)) {
        buffer.write('૦૧૨૩૪૫૬૭૮૯'['0123456789'.indexOf(c)]);
        i++;
        lastCons = false;
        continue;
      }

      bool match = false;
      // 2-char cons
      if (i + 1 < normalized.length) {
        final two = normalized.substring(i, i + 2);
        if (_consonants.containsKey(two)) {
          if (lastCons) buffer.write('્');
          buffer.write(_consonants[two]);
          i += 2;
          lastCons = true;
          match = true;
        }
      }
      // 1-char cons
      if (!match && _consonants.containsKey(c)) {
        if (lastCons) buffer.write('્');
        buffer.write(_consonants[c]);
        i++;
        lastCons = true;
        match = true;
      }
      // Vowels/Matras
      if (!match) {
        String? v;
        int len = 0;
        if (i + 1 < normalized.length &&
            _vowels.containsKey(normalized.substring(i, i + 2))) {
          v = normalized.substring(i, i + 2);
          len = 2;
        } else if (_vowels.containsKey(c)) {
          v = c;
          len = 1;
        }
        if (v != null) {
          buffer.write(lastCons ? _matras[v] ?? '' : _vowels[v] ?? '');
          i += len;
          lastCons = false;
          match = true;
        }
      }
      if (!match) {
        buffer.write(c);
        i++;
        lastCons = false;
      }
    }
    return buffer.toString();
  }

  String _normalize(String s) {
    final b = StringBuffer();
    final spec = {'T', 'D', 'N', 'L', 'S', 'R'};
    for (int i = 0; i < s.length; i++) {
      final c = s[i];
      b.write(spec.contains(c) ? c : c.toLowerCase());
    }
    return b.toString();
  }
}
