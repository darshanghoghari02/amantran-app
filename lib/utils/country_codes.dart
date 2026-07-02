class Country {
  final String name;
  final String flag;
  final String code;
  final String dialCode;
  final List<int> validLengths;

  const Country({
    required this.name,
    required this.flag,
    required this.code,
    required this.dialCode,
    required this.validLengths,
  });
}

const List<Country> countries = [
  Country(name: 'India', flag: '🇮🇳', code: 'IN', dialCode: '+91', validLengths: [10]),
  Country(name: 'United States', flag: '🇺🇸', code: 'US', dialCode: '+1', validLengths: [10]),
  Country(name: 'United Kingdom', flag: '🇬🇧', code: 'GB', dialCode: '+44', validLengths: [10]),
  Country(name: 'Canada', flag: '🇨🇦', code: 'CA', dialCode: '+1', validLengths: [10]),
  Country(name: 'Australia', flag: '🇦🇺', code: 'AU', dialCode: '+61', validLengths: [9]),
  Country(name: 'United Arab Emirates', flag: '🇦🇪', code: 'AE', dialCode: '+971', validLengths: [9]),
  Country(name: 'Saudi Arabia', flag: '🇸🇦', code: 'SA', dialCode: '+966', validLengths: [9]),
  Country(name: 'Singapore', flag: '🇸🇬', code: 'SG', dialCode: '+65', validLengths: [8]),
  Country(name: 'Oman', flag: '🇴🇲', code: 'OM', dialCode: '+968', validLengths: [8]),
  Country(name: 'Qatar', flag: '🇶🇦', code: 'QA', dialCode: '+974', validLengths: [8]),
  Country(name: 'Kuwait', flag: '🇰🇼', code: 'KW', dialCode: '+965', validLengths: [8]),
  Country(name: 'Bahrain', flag: '🇧🇭', code: 'BH', dialCode: '+973', validLengths: [8]),
  Country(name: 'Nepal', flag: '🇳🇵', code: 'NP', dialCode: '+977', validLengths: [10]),
  Country(name: 'Bangladesh', flag: '🇧🇩', code: 'BD', dialCode: '+880', validLengths: [10]),
  Country(name: 'Sri Lanka', flag: '🇱🇰', code: 'LK', dialCode: '+94', validLengths: [9]),
  Country(name: 'Pakistan', flag: '🇵🇰', code: 'PK', dialCode: '+92', validLengths: [10]),
  Country(name: 'Germany', flag: '🇩🇪', code: 'DE', dialCode: '+49', validLengths: [10, 11]),
  Country(name: 'France', flag: '🇫🇷', code: 'FR', dialCode: '+33', validLengths: [9]),
  Country(name: 'Italy', flag: '🇮🇹', code: 'IT', dialCode: '+39', validLengths: [10]),
  Country(name: 'Spain', flag: '🇪🇸', code: 'ES', dialCode: '+34', validLengths: [9]),
  Country(name: 'Netherlands', flag: '🇳🇱', code: 'NL', dialCode: '+31', validLengths: [9]),
  Country(name: 'Malaysia', flag: '🇲🇾', code: 'MY', dialCode: '+60', validLengths: [9, 10]),
  Country(name: 'Indonesia', flag: '🇮🇩', code: 'ID', dialCode: '+62', validLengths: [9, 10, 11]),
  Country(name: 'Thailand', flag: '🇹🇭', code: 'TH', dialCode: '+66', validLengths: [9]),
  Country(name: 'Vietnam', flag: '🇻🇳', code: 'VN', dialCode: '+84', validLengths: [9]),
  Country(name: 'Philippines', flag: '🇵🇭', code: 'PH', dialCode: '+63', validLengths: [10]),
  Country(name: 'Hong Kong', flag: '🇭🇰', code: 'HK', dialCode: '+852', validLengths: [8]),
  Country(name: 'Japan', flag: '🇯🇵', code: 'JP', dialCode: '+81', validLengths: [10]),
  Country(name: 'South Korea', flag: '🇰🇷', code: 'KR', dialCode: '+82', validLengths: [9, 10]),
  Country(name: 'New Zealand', flag: '🇳🇿', code: 'NZ', dialCode: '+64', validLengths: [8, 9]),
  Country(name: 'Turkey', flag: '🇹🇷', code: 'TR', dialCode: '+90', validLengths: [10]),
  Country(name: 'South Africa', flag: '🇿🇦', code: 'ZA', dialCode: '+27', validLengths: [9]),
  Country(name: 'Brazil', flag: '🇧🇷', code: 'BR', dialCode: '+55', validLengths: [11]),
  Country(name: 'Egypt', flag: '🇪🇬', code: 'EG', dialCode: '+20', validLengths: [10]),
  Country(name: 'Kenya', flag: '🇰🇪', code: 'KE', dialCode: '+254', validLengths: [9]),
  Country(name: 'Nigeria', flag: '🇳🇬', code: 'NG', dialCode: '+234', validLengths: [10]),
  Country(name: 'Switzerland', flag: '🇨🇭', code: 'CH', dialCode: '+41', validLengths: [9]),
  Country(name: 'Sweden', flag: '🇸🇪', code: 'SE', dialCode: '+46', validLengths: [9]),
  Country(name: 'Norway', flag: '🇳🇴', code: 'NO', dialCode: '+47', validLengths: [8]),
  Country(name: 'Denmark', flag: '🇩🇰', code: 'DK', dialCode: '+45', validLengths: [8]),
  Country(name: 'Ireland', flag: '🇮🇪', code: 'IE', dialCode: '+353', validLengths: [9]),
  Country(name: 'Russia', flag: '🇷🇺', code: 'RU', dialCode: '+7', validLengths: [10]),
  Country(name: 'Mexico', flag: '🇲🇽', code: 'MX', dialCode: '+52', validLengths: [10]),
];

class CountryParser {
  /// Detect country based on device locale ISO code (e.g. 'US', 'IN')
  static Country detectCountry(String? localeCode) {
    if (localeCode == null || localeCode.trim().isEmpty) {
      return countries.firstWhere((c) => c.code == 'IN');
    }
    final target = localeCode.trim().toUpperCase();
    return countries.firstWhere(
      (c) => c.code == target,
      orElse: () => countries.firstWhere((c) => c.code == 'IN'),
    );
  }

  /// Parse user's full phone number to match the correct Country details.
  /// If it finds a matching dial code prefix, returns that Country.
  static Country parsePhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    // Sort country codes by dial code length descending so longer dial codes (like +971)
    // are checked before shorter ones (like +9)
    final sortedCountries = List<Country>.from(countries)
      ..sort((a, b) => b.dialCode.replaceAll(RegExp(r'\D'), '').length.compareTo(
          a.dialCode.replaceAll(RegExp(r'\D'), '').length));

    for (var country in sortedCountries) {
      final dialDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
      if (cleaned.startsWith(dialDigits)) {
        return country;
      }
    }

    // Default fallback
    return countries.firstWhere((c) => c.code == 'IN');
  }

  /// Strip dial code prefix from a full phone number
  static String getLocalNumber(String phone) {
    final country = parsePhone(phone);
    final dialDigits = country.dialCode.replaceAll(RegExp(r'\D'), '');
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith(dialDigits)) {
      return cleaned.substring(dialDigits.length);
    }
    return cleaned;
  }

  /// Check if dial code and local phone number mismatch
  static String? checkPhoneMismatch(String dialCode, String localPhone) {
    final digits = localPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    final country = countries.firstWhere(
      (c) => c.dialCode == dialCode,
      orElse: () => countries.firstWhere((c) => c.code == 'IN'),
    );
    
    // Validate if length of digits matches the allowed lengths for the selected country
    if (!country.validLengths.contains(digits.length)) {
      return "Phone number does not match the selected country code.";
    }

    return null;
  }
}
