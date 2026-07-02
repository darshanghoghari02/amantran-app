// GopikaConverter: Converts Unicode Gujarati text to legacy KAP/Gopika font encoding.
//
// Legacy KAP fonts (KAP011, KAP012, KAP020, KAP105, KAP149, KAP157, etc.) are
// ASCII-mapped fonts that use keyboard characters to represent Gujarati glyphs.
// They do NOT map Unicode Gujarati codepoints, so we must:
//   1. Pre-process: reorder vowels (especially િ - the short-i matra) and reph (ર્)
//   2. Substitute: replace each Unicode Gujarati sequence with the ASCII equivalent.


class GopikaConverter {
  // ─── SUBSTITUTION TABLE ───────────────────────────────────────────────────
  // Order matters: longer multi-char sequences must come before single-char ones.
  // This list mirrors the JS `array_one` in UnicodeToGopika().
  static const List<String> _pairs = [
    'ૐ', 'H',

    'ઈં', '#',
    'ઇં', '\$',
    'ઉં', 'ô',
    'ઊં', 'Ÿ',

    'અ', 'y',
    'આ', 'yt',
    'ઇ', 'R',
    'ઈ', 'E',
    'ઉ', 'W',
    'ઊ', 'Q',
    'ઋ', 'É',
    'ઝ્ર', 'C',
    'ઌ', 'Ý',
    'એ', 'yu',
    'ઐ', 'yi',
    'ઓ', 'ytu',
    'ઔ', 'yti',
    'ઍ', 'yì',
    'ઑ', 'ytì',

    'સ્ત્ર્', 'MºtT',
    'સ્ત્ર', 'Mºt',

    'ક્ષ્', 'ûtT',
    'ત્ર્', 'ºtT',
    'જ્ઞ્', '¿tT',

    'ક્ષ', 'ût',
    'ત્ર', 'ºt',
    'જ્ઞ', '¿t',

    'ટ્રુ', 'x›',
    'ટ્રૂ', 'x‰',
    'ટ્ર', 'xÙ',
    'ડ્રુ', 'z›',
    'ડ્રૂ', 'z‰',
    'ડ્ર', 'zÙ',
    'જ્રુ', '@w',
    'જ્રૂ', '@q',
    'જ્રા', '@t',
    'જ્ર', '@',

    'સ્ર્', '²tT',
    'સ્ર', '²t',
    'પ્ર', '«',

    'દ્ર', 'ÿ',
    'શ્ર્વ', '©Tð',
    'શ્ર', '©',
    'ક્ર', '¢',
    'ફ્ર', '£',
    'હ્ર', '´',

    '્ર', 'ú',

    'ક્ન', 'õ™',
    'ટ્ટ', 'è',
    'ટ્ઠ', 'a',
    'ડ્ડ', 'œ',
    'ત્ન', 'J',

    'દૃ', 'á',
    'ઢ્ઢ', 'ë',
    'ડ્ઢ', 'D',
    'હ્ન', 'ö',
    'હ્ય્', 'ÌtT',
    'હ્ય', 'Ìt',
    'શ્ન', '§',
    'ઙ્ક', 'Ñ',
    'ઙ્ખ', 'Ö',
    'ઙ્ગ', 'Ü',
    'ઙ્ઘ', 'd',
    'હ્ણ', 'nTý',
    'હ્મ', 'ñ',
    'હ્વ', 'b',
    'દ્ઘ', 'j',
    'દ્બ', 'm',
    'દ્ભ', 'K',
    'દ્મ', 'È',
    'દ્વ', 'î',
    'ઠ્ઠ', 'ê',
    'દ્ગ', 'N',
    'દ્ધ', 'Ø',
    'ન્ન્', 'ÒtT',
    'ન્ન', 'Òt',
    'પ્ત', 'ó',
    'પ્ન', '¡',
    'જી', 'S',
    'જા', 'ò',

    'ત્ત્', '¥tT',
    'ત્ત', '¥t',

    'ષ્ટ', 'ü',
    'ષ્ઠ', 'c',
    'શ્ચ', 'ù',
    'શ્વ', 'ï',
    'સ્ન્', 'M™T',
    'સ્ન', 'M™',
    'દ્દ', 'Æ',
    'હૃ', 'Ó',
    'ક્ક', '¬',
    'દ્ય', 'ã',

    'ક્', 'õ',
    'ખ્', 'Ï',
    'ગ્', 'ø',
    'ઘ્', 'Î',
    'ઝ઼', 'Í|',
    'ચ્', 'å',
    'જ્', 'ß',
    'ઞ્', 'Å',
    'ણ્', 'Û',
    'ત્', 'í',
    'થ્', 'Ú',
    'ધ્', 'æ',
    'ન્', 'L',
    'પ્', 'Ã',
    'ફ્', '^',
    'બ્', 'ç',
    'ભ્', 'Ç',
    'મ્', 'B',
    'ય્', 'G',
    'લ્', 'Õ',
    'વ્', 'Ô',
    'શ્', '~',
    'સ્', 'M',
    'ષ્', '»',
    'હ્', 'nT',
    'ળ્', 'é',

    'ણુ', 'ýw',
    'ણૂ', 'ýq',
    'ફુ', 'Vw',
    'ફૂ', 'Vq',
    'રુ', 'Á',
    'રૂ', 'Y',

    'ફ઼', 'V|',

    'ક', 'f',
    'ખ', '¾',
    'ગ', '„',
    'ઘ', '½',
    'ઙ', 'Ê',
    'ચ', '[',
    'છ', 'A',
    'જ', 's',
    'ઝ્', 'ÍT',
    'ઝ', 'Í',
    'ઞ', 'Åt',

    'ટ', 'x',
    'ઠ', 'X',
    'ડ', 'z',
    'ઢ', 'Z',
    'ણ', 'ý',
    'ત', '‚',
    'થ', 'Út',
    'દ', 'Œ',
    'ધ', 'Ä',
    'ન', '™',

    'પ', '…',
    'ફ', 'V',
    'બ', 'ƒ',
    'ભ', '¼',
    'મ', '{',

    'ય', 'Þ',
    'ર', 'h',
    'લ', '÷',
    'વ', 'ð',
    'શ', 'þ',
    'ષ', '»t',
    'સ', 'Ë',
    'હ', 'n',
    'ળ', '¤',

    '઼', '|',
    'ૅં', 'ìk',

    'ા', 't',
    'ૅ', 'ì',
    'ૉ', 'tì',
    'ીં', 'ª',
    'ી', 'e',
    'ુ', 'w',
    'ૂ', 'q',
    'ૃ', ']',
    'ે', 'u',
    'ૈ', 'i',
    'ો', 'tu',
    'ૌ', 'ti',
    'ઁ', 'P',
    'ં', 'k',
    'ઃ', ':',
    'ઽ', 'à',
    '્', 'T',
    'ëm', 'ëm',

    '।', '>',
    '\u2018', '\u2018',  // '
    '\u2019', '\u2019',  // '

    '૦', '0',
    '૧', '1',
    '૨', '2',
    '૩', '3',
    '૪', '4',
    '૫', '5',
    '૬', '6',
    '૭', '7',
    '૮', '8',
    '૯', '9',
  ];

  /// Convert Unicode Gujarati text → Gopika/KAP legacy ASCII encoding.
  /// Call this only when the active fontFamily is a legacy KAP font.
  static String convert(String text) {
    if (text.isEmpty) return text;

    String s = text;

    // ── Step 1: Protect ત્ર્ and શ્ર્ from reph substitution ───────────────
    s = s.replaceAll('ત્ર્', 'ºtT');
    s = s.replaceAll('શ્ર્', '©T');

    // ── Step 2: Convert ર્ → hT (placeholder for reph position logic) ──────
    s = s.replaceAll('ર્', 'hT');

    // ── Step 3: Restore protected sequences ─────────────────────────────────
    s = s.replaceAll('ºtT', 'ત્ર્');
    s = s.replaceAll('©T', 'શ્ર્');

    // ── Step 4: Handle short-i matra (િ) reordering ─────────────────────────
    // Step 4a: Replace િં with the combined placeholder ®
    s = s.replaceAll('િં', '®');

    // Step 4b: Replace remaining standalone િ with r
    s = s.replaceAll('િ', 'r');

    // Step 4c: Fix ર્ + િ → Š
    s = s.replaceAll('hTr', 'Šhacked');  // temp, undo below
    // Actually the JS does: ર્િ → Š then replaces ® → ®
    // Let's re-do properly:
    s = s.replaceAll('Šhacked', 'rhT');

    // ── Step 4 (redo, correct approach matching JS): ─────────────────────────
    // We need to reorder 'r' (translated િ) to before its consonant cluster.
    // The JS regex moves 'r' to before the entire preceding consonant+halant group.
    // We replicate this with a targeted multi-pass approach:
    s = _reorderShortI(s);

    // ── Step 5: Reph (ó) positioning ────────────────────────────────────────
    // hT before consonant+halant → move reph after vowel signs
    s = _repositionReph(s);

    // ── Step 6: Fix special hT+vowel cases ──────────────────────────────────
    s = s.replaceAll('ીંhT', '`');
    s = s.replaceAll('ીhT', 'hTe');
    s = s.replaceAll('ંhT', 'hTk');

    // ── Step 7: Halanta before non-consonant (space, punctuation) ───────────
    s = s.replaceAll(RegExp(r'[્]([ ,;.।\n\-:])'), 'T\$1');

    // ── Step 8: ્ + ય special cases ──────────────────────────────────────────
    s = s.replaceAll(RegExp(r'([કછટઢફ])્ય'), '\$1â');

    // ── Step 9: Apply the substitution table ────────────────────────────────
    s = _applySubstitutions(s);

    // ── Step 10: Fix rÿ → ÿr (edge case for દ્ર after reph) ────────────────
    s = s.replaceAll('rÿ', 'ÿr');

    return s;
  }

  /// Returns true if the given fontFamily is a legacy KAP-style font that
  /// requires Gopika transliteration before rendering.
  static bool isLegacyFont(String fontFamily) {
    final lower = fontFamily.toLowerCase();
    return lower.startsWith('kap') || lower == 'gopika' || lower == 'gopika2';
  }

  // ─── PRIVATE HELPERS ─────────────────────────────────────────────────────

  /// Reorder short-i matra 'r' (and '®') to appear *before* the consonant cluster.
  /// Mirrors the JS regex logic for moving િ before its consonant group.
  static String _reorderShortI(String s) {
    // All Gujarati consonants as a single string for matching
    const String cons = 'કખગઘઙચછજઝઞટઠડઢણતથદધનપફબભમયરલવશષસહળ';

    // Pattern: (cons)(cons+halant groups)(cons)(r)  → r + first groups + last cons
    // We do multiple passes because the regex engine can only match non-overlapping.
    // Pass 1: CON CON_HALANT* CON r → r CON CON_HALANT* CON
    s = _reorderPattern3(s, cons);
    // Pass 2: single consonant + r → r + consonant
    s = _reorderPattern1(s, cons);
    // Pass 3: consonant + ® → ® + consonant
    s = _reorderPattern2(s, cons);
    // Pass 4: consonant + halant + ® → ® + consonant + halant
    s = _reorderPattern4(s, cons);
    // Pass 5 (repeat for nested clusters):
    s = _reorderPattern4(s, cons);

    return s;
  }

  static String _reorderPattern1(String s, String cons) {
    // ([cons])([r]) → $2$1
    final sb = StringBuffer();
    int i = 0;
    while (i < s.length) {
      if (i + 1 < s.length) {
        final c1 = s[i];
        final c2 = s[i + 1];
        if (cons.contains(c1) && c2 == 'r') {
          sb.write('r');
          sb.write(c1);
          i += 2;
          continue;
        }
      }
      sb.write(s[i]);
      i++;
    }
    return sb.toString();
  }

  static String _reorderPattern2(String s, String cons) {
    // ([cons])([®]) → $2$1
    final sb = StringBuffer();
    int i = 0;
    while (i < s.length) {
      if (i + 1 < s.length) {
        final c1 = s[i];
        final c2 = s[i + 1];
        if (cons.contains(c1) && c2 == '®') {
          sb.write('®');
          sb.write(c1);
          i += 2;
          continue;
        }
      }
      sb.write(s[i]);
      i++;
    }
    return sb.toString();
  }

  static String _reorderPattern3(String s, String cons) {
    // ([cons])([cons+halant]*)([cons])([r]) → r + $1$2$3
    // We handle: CON1 CON2 ્ CON3 r → r CON1 CON2 ્ CON3
    final sb = StringBuffer();
    int i = 0;
    while (i < s.length) {
      // Try to find CON ્ CON r
      if (i + 3 < s.length &&
          cons.contains(s[i]) &&
          s[i + 1] == '્' &&
          cons.contains(s[i + 2]) &&
          s[i + 3] == 'r') {
        sb.write('r');
        sb.write(s[i]);
        sb.write('્');
        sb.write(s[i + 2]);
        i += 4;
        continue;
      }
      sb.write(s[i]);
      i++;
    }
    return sb.toString();
  }

  static String _reorderPattern4(String s, String cons) {
    // ([cons])(્)([®]) → $3$1$2
    final sb = StringBuffer();
    int i = 0;
    while (i < s.length) {
      if (i + 2 < s.length &&
          cons.contains(s[i]) &&
          s[i + 1] == '્' &&
          s[i + 2] == '®') {
        sb.write('®');
        sb.write(s[i]);
        sb.write('્');
        i += 3;
        continue;
      }
      sb.write(s[i]);
      i++;
    }
    return sb.toString();
  }

  /// Place reph (ó) at correct position.
  /// Mirrors JS: hT([cons])(halant) → $1$2 + 'o'
  ///             hT([cons])([vowel signs]*) → $1$2 + 'o'
  static String _repositionReph(String s) {
    const String cons = 'કખગઘઙચછજઝઞટઠડઢણતથદધનપફબભમયરલવશષસહળ';
    const String vowSigns = 'ાીુૂૃેૈોૌંઁૅૉ઼';

    // hT + r case
    s = s.replaceAll('hTr', 'rhT');

    // hT + CON + halant → CON + halant + o
    final sb1 = StringBuffer();
    int i = 0;
    while (i < s.length) {
      if (i + 2 < s.length &&
          s.substring(i, i + 2) == 'hT' &&
          cons.contains(s[i + 2])) {
        // Check if next after CON is ્
        final int nextIdx = i + 3;
        if (nextIdx < s.length && s[nextIdx] == '્') {
          sb1.write(s[i + 2]);
          sb1.write('્');
          sb1.write('o');
          i += 4;
          continue;
        }
        // Otherwise: hT + CON + (optional vowel signs) + o
        sb1.write(s[i + 2]); // the CON
        i += 3;
        while (i < s.length && vowSigns.contains(s[i])) {
          sb1.write(s[i]);
          i++;
        }
        sb1.write('o');
        continue;
      }
      sb1.write(s[i]);
      i++;
    }

    return sb1.toString();
  }

  /// Apply the substitution table sequentially.
  /// Processes pairs from _pairs list (longest-match first since table is ordered).
  static String _applySubstitutions(String s) {
    for (int k = 0; k < _pairs.length - 1; k += 2) {
      final String from = _pairs[k];
      final String to = _pairs[k + 1];
      if (from.isEmpty) continue;
      s = s.replaceAll(from, to);
    }
    return s;
  }
}
