import 'package:murmur/core/text/sentence.dart';
import 'package:murmur/core/text/sentence_splitter.dart';
import 'package:test/test.dart';

void main() {
  late SentenceSplitter splitter;

  setUp(() {
    splitter = const SentenceSplitter();
  });

  group('SentenceSplitter', () {
    group('basic splitting', () {
      test('splits on period', () {
        expect(
          splitter.split('Hello. World.'),
          [const Sentence('Hello. '), const Sentence('World.')],
        );
      });

      test('splits on exclamation and question mark', () {
        expect(
          splitter.split('Hello! World?'),
          [const Sentence('Hello! '), const Sentence('World?')],
        );
      });

      test('single sentence', () {
        expect(
          splitter.split('Single sentence.'),
          [const Sentence('Single sentence.')],
        );
      });

      test('empty string returns empty list', () {
        expect(splitter.split(''), isEmpty);
      });

      test('whitespace-only string returns empty list', () {
        expect(splitter.split('   '), isEmpty);
      });

      test('no trailing punctuation', () {
        expect(
          splitter.split('No trailing punctuation'),
          [const Sentence('No trailing punctuation')],
        );
      });

      test('multiple sentences with mixed punctuation', () {
        expect(
          splitter.split('First. Second! Third?'),
          [
            const Sentence('First. '),
            const Sentence('Second! '),
            const Sentence('Third?'),
          ],
        );
      });
    });

    group('abbreviations preserved', () {
      test('Mr. does not split', () {
        expect(
          splitter.split('Mr. Smith went home. He rested.'),
          [
            const Sentence('Mr. Smith went home. '),
            const Sentence('He rested.'),
          ],
        );
      });

      test('Dr. and Mrs. do not split', () {
        expect(
          splitter.split('Dr. Jones and Mrs. Smith met.'),
          [const Sentence('Dr. Jones and Mrs. Smith met.')],
        );
      });

      test('St. does not split', () {
        expect(
          splitter.split('St. Louis is nice. I agree.'),
          [
            const Sentence('St. Louis is nice. '),
            const Sentence('I agree.'),
          ],
        );
      });

      test('U.S. does not split', () {
        expect(
          splitter.split('The U.S. is large. Very large.'),
          [
            const Sentence('The U.S. is large. '),
            const Sentence('Very large.'),
          ],
        );
      });

      test('single-letter initial does not split', () {
        expect(
          splitter.split('J. K. Rowling wrote books. Great books.'),
          [
            const Sentence('J. K. Rowling wrote books. '),
            const Sentence('Great books.'),
          ],
        );
      });
    });

    group('decimal numbers preserved', () {
      test('dollar amount does not split', () {
        expect(
          splitter.split('It cost \$3.50 total.'),
          [const Sentence('It cost \$3.50 total.')],
        );
      });

      test('pi does not split', () {
        expect(
          splitter.split('Pi is 3.14 approximately.'),
          [const Sentence('Pi is 3.14 approximately.')],
        );
      });
    });

    group('ellipsis preserved', () {
      test('ellipsis mid-sentence does not split', () {
        expect(
          splitter.split('He waited... then left.'),
          [const Sentence('He waited... then left.')],
        );
      });

      test('question mark before ellipsis splits on question mark', () {
        expect(
          splitter.split('Really?... Yes.'),
          [const Sentence('Really?'), const Sentence('... Yes.')],
        );
      });
    });

    group('trailing quotes included', () {
      test('quoted dialogue splits correctly', () {
        expect(
          splitter.split('"Hello," she said. "Goodbye."'),
          [
            const Sentence('"Hello," she said. '),
            const Sentence('"Goodbye."'),
          ],
        );
      });

      test('question in quotes splits correctly', () {
        expect(
          splitter.split('She asked, "Why?" He shrugged.'),
          [
            const Sentence('She asked, "Why?" '),
            const Sentence('He shrugged.'),
          ],
        );
      });
    });

    group('whitespace handling', () {
      test('leading and trailing whitespace in input is trimmed', () {
        expect(
          splitter.split('  Hello.  '),
          [const Sentence('Hello.')],
        );
      });

      test('multiple spaces between sentences collapse', () {
        expect(
          splitter.split('Hello.   World.'),
          [const Sentence('Hello. '), const Sentence('World.')],
        );
      });

      test('trailing whitespace after last sentence is trimmed', () {
        expect(
          splitter.split('Hello.   '),
          [const Sentence('Hello.')],
        );
      });
    });
  });
}
