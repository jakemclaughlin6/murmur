import 'package:murmur/core/text/sentence.dart';
import 'package:test/test.dart';

void main() {
  group('Sentence', () {
    test('creates a Sentence with text', () {
      final sentence = Sentence('Hello.');
      expect(sentence.text, 'Hello.');
    });

    test('two Sentences with the same text are equal', () {
      const a = Sentence('Hello.');
      const b = Sentence('Hello.');
      expect(a, equals(b));
    });

    test('two Sentences with different text are not equal', () {
      const a = Sentence('Hello.');
      const b = Sentence('Goodbye.');
      expect(a, isNot(equals(b)));
    });

    test('two Sentences with the same text have the same hashCode', () {
      const a = Sentence('Hello.');
      const b = Sentence('Hello.');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString returns Sentence(text)', () {
      const sentence = Sentence('Hello.');
      expect(sentence.toString(), 'Sentence(Hello.)');
    });

    test('const constructor compiles', () {
      // This test verifies const constructor works at compile time.
      const sentence = Sentence('x');
      expect(sentence.text, 'x');
    });

    test('works in a Set (deduplicates equal Sentences)', () {
      const a = Sentence('Hello.');
      const b = Sentence('Hello.');
      const c = Sentence('World.');
      final set = {a, b, c};
      expect(set.length, 2);
    });
  });
}
