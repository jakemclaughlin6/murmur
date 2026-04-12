import 'sentence.dart';

/// Splits English text into [Sentence] objects at sentence boundaries.
///
/// Handles common abbreviations (Mr., Dr., etc.), decimal numbers,
/// ellipses, and trailing quotes. This is the Phase 3 basic implementation;
/// Phase 4 (TTS-06) hardens it with 500+ regression fixtures.
///
/// The splitter performs a character-by-character scan, which is O(n) and
/// avoids pathological regex backtracking.
///
/// See: CONTEXT.md D-02, REQUIREMENTS.md RDR-04
class SentenceSplitter {
  const SentenceSplitter();

  /// Known abbreviations that should not trigger a sentence split.
  ///
  /// Checked case-insensitively against the word immediately before a period.
  static const _abbreviations = <String>{
    'mr', 'mrs', 'ms', 'dr', 'prof', 'rev', 'sr', 'jr',
    'st', 'ave', 'blvd',
    'gen', 'gov', 'sgt', 'cpl', 'pvt', 'capt', 'lt', 'col', 'maj',
    'vs', 'etc', 'approx', 'dept', 'est', 'vol',
    'jan', 'feb', 'mar', 'apr', 'jun', 'jul', 'aug', 'sep', 'oct',
    'nov', 'dec',
  };

  /// Splits [text] into a list of [Sentence] objects.
  ///
  /// Returns an empty list if [text] is empty or whitespace-only.
  /// Trailing whitespace on the input is trimmed. Whitespace between
  /// sentences is attached to the preceding sentence (collapsed to a
  /// single space).
  List<Sentence> split(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final sentences = <Sentence>[];
    var start = 0;
    var i = 0;

    while (i < trimmed.length) {
      final char = trimmed[i];

      if (char == '.') {
        // Check for ellipsis (... or more dots).
        if (i + 1 < trimmed.length && trimmed[i + 1] == '.') {
          // Skip the entire dot sequence.
          while (i < trimmed.length && trimmed[i] == '.') {
            i++;
          }
          continue;
        }

        // Check for decimal number: digit before and digit after the dot.
        if (_isDecimalDot(trimmed, i)) {
          i++;
          continue;
        }

        // Check for abbreviation.
        if (_isAbbreviation(trimmed, i)) {
          i++;
          continue;
        }

        // It's a sentence boundary on period.
        i++;
        i = _consumeClosingQuotes(trimmed, i);
        i = _consumeTrailingWhitespace(trimmed, i);
        sentences.add(Sentence(_trimTrailing(trimmed.substring(start, i))));
        start = i;
        continue;
      }

      if (char == '!' || char == '?') {
        // Always a sentence boundary.
        i++;
        i = _consumeClosingQuotes(trimmed, i);
        i = _consumeTrailingWhitespace(trimmed, i);
        sentences.add(Sentence(_trimTrailing(trimmed.substring(start, i))));
        start = i;
        continue;
      }

      i++;
    }

    // Remaining text after the last boundary.
    if (start < trimmed.length) {
      sentences.add(Sentence(trimmed.substring(start)));
    }

    return sentences;
  }

  /// Returns true if the dot at [dotIndex] is between two digits (decimal).
  bool _isDecimalDot(String text, int dotIndex) {
    if (dotIndex == 0 || dotIndex + 1 >= text.length) return false;
    final before = text.codeUnitAt(dotIndex - 1);
    final after = text.codeUnitAt(dotIndex + 1);
    return _isDigit(before) && _isDigit(after);
  }

  /// Returns true if the dot at [dotIndex] follows a known abbreviation
  /// or a single uppercase letter (initial like J. or K.).
  bool _isAbbreviation(String text, int dotIndex) {
    // Extract the word immediately before the dot.
    var wordEnd = dotIndex;
    var wordStart = dotIndex - 1;

    // Scan backward to find the start of the word (stop at space,
    // start of string, or another period for chained initials like U.S.)
    while (wordStart > 0 &&
        text[wordStart - 1] != ' ' &&
        text[wordStart - 1] != '.') {
      wordStart--;
    }

    if (wordStart >= wordEnd) return false;

    final word = text.substring(wordStart, wordEnd);

    // Single uppercase letter -> initial (J., K., etc.)
    if (word.length == 1 && _isUpperCase(word.codeUnitAt(0))) {
      return true;
    }

    // Check against abbreviation set (case-insensitive).
    return _abbreviations.contains(word.toLowerCase());
  }

  /// Advances past any closing quote characters at [index].
  int _consumeClosingQuotes(String text, int index) {
    while (index < text.length) {
      final c = text[index];
      if (c == '"' || c == '\u201D' || // right double quote
          c == "'" ||
          c == '\u2019' || // right single quote
          c == ')') {
        index++;
      } else {
        break;
      }
    }
    return index;
  }

  /// Advances past whitespace at [index], collapsing multiple spaces.
  int _consumeTrailingWhitespace(String text, int index) {
    while (index < text.length && text[index] == ' ') {
      index++;
    }
    return index;
  }

  /// Trims trailing whitespace down to at most one space.
  /// If the sentence is at the end of the input, strips all trailing space.
  String _trimTrailing(String s) {
    if (s.isEmpty) return s;

    var end = s.length;
    while (end > 0 && s[end - 1] == ' ') {
      end--;
    }

    // No trailing spaces -> return as-is.
    if (end == s.length) return s;

    // Has trailing spaces -> keep exactly one.
    return '${s.substring(0, end)} ';
  }

  bool _isDigit(int codeUnit) =>
      codeUnit >= 0x30 && codeUnit <= 0x39; // '0'-'9'

  bool _isUpperCase(int codeUnit) =>
      codeUnit >= 0x41 && codeUnit <= 0x5A; // 'A'-'Z'
}
