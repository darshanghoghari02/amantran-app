import '../models/language_model.dart';

class LanguagePickerItem {
  final String name;
  final String code;
  final String script;

  const LanguagePickerItem({
    required this.name,
    required this.code,
    required this.script,
  });
}

/// Central registry for invitation languages (CMS + fallbacks).
class LanguageRegistry {
  LanguageRegistry._();
  static final LanguageRegistry instance = LanguageRegistry._();

  static const Set<String> _rtlCodes = {'ur', 'ar', 'fa', 'he', 'ps', 'sd', 'ks'};
  static const Set<String> _offlineConvertNames = {
    'hindi',
    'marathi',
    'punjabi',
    'urdu',
  };

  static const Map<String, String> _scriptByCode = {
    'en': 'A B C',
    'gu': 'ક ખ ગ',
    'hi': 'क ख ग',
    'mr': 'क ख ग',
    'pa': 'ਕ ਖ ગ',
    'ur': 'ا ب ت',
    'ks': 'ا ب ت',
    'ta': 'அ ஆ இ',
    'bn': 'অ আ ই',
    'te': 'అ ఆ ఇ',
    'kn': 'ಅ ಆ ಇ',
    'ml': 'അ ആ ഇ',
    'sa': 'अ आ इ',
    'or': 'ଅ ଆ ଇ',
    'as': 'অ আ ই',
    'ne': 'अ आ इ',
  };

  /// Maps admin-entered names/codes to Google Translate ISO codes.
  static const Map<String, String> _nameToIso = {
    'english': 'en',
    'gujarati': 'gu',
    'hindi': 'hi',
    'marathi': 'mr',
    'punjabi': 'pa',
    'urdu': 'ur',
    'kashmiri': 'ks',
    'tamil': 'ta',
    'bengali': 'bn',
    'bangla': 'bn',
    'telugu': 'te',
    'kannada': 'kn',
    'malayalam': 'ml',
    'sanskrit': 'sa',
    'odia': 'or',
    'oriya': 'or',
    'assamese': 'as',
    'nepali': 'ne',
  };

  static const List<LanguagePickerItem> _defaults = [
    LanguagePickerItem(name: 'English', code: 'en', script: 'A B C'),
    LanguagePickerItem(name: 'Gujarati', code: 'gu', script: 'ક ખ ગ'),
    LanguagePickerItem(name: 'Hindi', code: 'hi', script: 'क ख ग'),
    LanguagePickerItem(name: 'Marathi', code: 'mr', script: 'क ख ग'),
    LanguagePickerItem(name: 'Punjabi', code: 'pa', script: 'ਕ ਖ ਗ'),
    LanguagePickerItem(name: 'Urdu', code: 'ur', script: 'ا ب ت'),
  ];

  final Map<String, LanguagePickerItem> _byNameLower = {};
  final Map<String, String> _nameByCode = {};

  void updateFromBackend(List<LanguageModel> models) {
    _byNameLower.clear();
    _nameByCode.clear();

    final active = models.where((m) => m.isActive && m.name.isNotEmpty).toList();
    if (active.isEmpty) {
      _seedDefaults();
      return;
    }

    for (final model in active) {
      final item = _itemFromModel(model);
      _byNameLower[item.name.toLowerCase()] = item;
      _nameByCode[item.code.toLowerCase()] = item.name;
    }
  }

  void _seedDefaults() {
    for (final item in _defaults) {
      _byNameLower[item.name.toLowerCase()] = item;
      _nameByCode[item.code.toLowerCase()] = item.name;
    }
  }

  LanguagePickerItem _itemFromModel(LanguageModel model) {
    final name = _formatDisplayName(model.name);
    final code = _normalizeCode(model.code, name);
    final script = (model.scriptSample?.trim().isNotEmpty ?? false)
        ? model.scriptSample!.trim()
        : (_scriptByCode[code] ?? _scriptByCode[_nameToIso[name.toLowerCase()] ?? ''] ?? 'अ आ इ');
    return LanguagePickerItem(name: name, code: code, script: script);
  }

  static String _formatDisplayName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _normalizeCode(String rawCode, String displayName) {
    final code = rawCode.trim().toLowerCase();
    final nameKey = displayName.trim().toLowerCase();

    if (code.length == 2 && RegExp(r'^[a-z]{2}$').hasMatch(code)) {
      return code;
    }
    if (_nameToIso.containsKey(code)) return _nameToIso[code]!;
    if (_nameToIso.containsKey(nameKey)) return _nameToIso[nameKey]!;
    if (code.length == 2) return code;
    return 'en';
  }

  List<LanguagePickerItem> get activeLanguages {
    if (_byNameLower.isEmpty) _seedDefaults();
    final items = _byNameLower.values.toList();
    items.sort((a, b) {
      if (a.code == 'en') return -1;
      if (b.code == 'en') return 1;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  Set<String> get languageNames =>
      activeLanguages.map((l) => l.name).toSet();

  String codeFor(String languageNameOrCode) {
    if (_byNameLower.isEmpty) _seedDefaults();
    final key = languageNameOrCode.trim().toLowerCase();
    final byName = _byNameLower[key];
    if (byName != null) return byName.code;
    if (_nameByCode.containsKey(key)) return key;
    return _legacyCodeFor(key);
  }

  String isoCodeFor(String languageNameOrCode) => codeFor(languageNameOrCode);

  String? nameForCode(String code) {
    if (_byNameLower.isEmpty) _seedDefaults();
    return _nameByCode[code.trim().toLowerCase()];
  }

  String scriptFor(String languageName) {
    if (_byNameLower.isEmpty) _seedDefaults();
    return _byNameLower[languageName.trim().toLowerCase()]?.script ??
        _scriptByCode[codeFor(languageName)] ??
        'अ आ इ';
  }

  bool isRtl(String languageNameOrCode) =>
      _rtlCodes.contains(codeFor(languageNameOrCode));

  bool hasOfflineConversion(String languageName) =>
      _offlineConvertNames.contains(languageName.trim().toLowerCase());

  bool usesDevanagari(String languageNameOrCode) {
    final code = codeFor(languageNameOrCode);
    return {'hi', 'mr', 'sa', 'ne', 'mai', 'bho'}.contains(code);
  }

  List<LanguagePickerItem> filterLanguages({
    Set<String>? allowedNames,
    List<String>? supportedLanguageRefs,
  }) {
    var items = activeLanguages;
    if (allowedNames != null && allowedNames.isNotEmpty) {
      final allowed = allowedNames.map((n) => n.toLowerCase()).toSet();
      items = items
          .where((l) =>
              allowed.contains(l.name.toLowerCase()) ||
              allowed.contains(l.code.toLowerCase()))
          .toList();
    }
    if (supportedLanguageRefs != null && supportedLanguageRefs.isNotEmpty) {
      final refs = supportedLanguageRefs.map((r) => r.toLowerCase()).toSet();
      items = items
          .where((l) =>
              refs.contains(l.name.toLowerCase()) ||
              refs.contains(l.code.toLowerCase()))
          .toList();
    }
    return items;
  }

  String _legacyCodeFor(String key) {
    if (_nameToIso.containsKey(key)) return _nameToIso[key]!;
    return key.length == 2 ? key : 'en';
  }
}
