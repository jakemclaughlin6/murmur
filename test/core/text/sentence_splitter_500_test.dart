import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/text/sentence_splitter.dart';

import '../../fixtures/sentence_splitter/fiction_corpus.dart';

void main() {
  const splitter = SentenceSplitter();

  group('SentenceSplitter 500+ corpus', () {
    test('corpus size >= 500', () {
      expect(fictionCorpus.length, greaterThanOrEqualTo(500),
          reason: 'TTS-06 requires >=500 fixtures');
    });

    for (final c in fictionCorpus) {
      final preview =
          c.input.length > 60 ? '${c.input.substring(0, 60)}...' : c.input;
      test('[${c.category}] $preview', () {
        final got = splitter.split(c.input).map((s) => s.text).toList();
        expect(
          got,
          equals(c.expected),
          reason: 'Category=${c.category}  Source=${c.source}',
        );
      });
    }
  });
}
