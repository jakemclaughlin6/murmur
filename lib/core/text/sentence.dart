/// A single sentence extracted from EPUB text content.
///
/// Sentences are the first-class data structure of murmur's reader
/// architecture. Each paragraph is split into [Sentence] objects that
/// become individual [TextSpan] children in [RichText] widgets. Phase 5
/// adds per-sentence highlight state for TTS tracking.
///
/// See: CONTEXT.md D-03, REQUIREMENTS.md RDR-04
class Sentence {
  /// The raw text of the sentence, including trailing whitespace if it
  /// precedes another sentence in the same paragraph.
  final String text;

  /// Creates a [Sentence] with the given [text].
  const Sentence(this.text);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Sentence &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Sentence($text)';
}
