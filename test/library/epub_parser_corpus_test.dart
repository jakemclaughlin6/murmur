/// Wave 0 stub — 15-EPUB corpus validation.
///
/// Covers LIB-03 per 02-VALIDATION.md. The 15-EPUB corpus exercises edge
/// cases the minimal spike fixture does not (no cover, non-ASCII titles,
/// very long books, malformed XHTML, EPUB 2 spec, DRM, corrupt ZIP — see
/// 02-VALIDATION.md §15-EPUB Test Corpus for the full list). Real tests
/// land in Plan 02-08.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EPUB parser corpus', () {
    test(
      'TODO: parse all 15 corpus EPUBs; each yields chapters with valid Block IR, DRM-protected and corrupt entries rejected',
      () {},
      skip: 'Wave 0 stub — implemented by Plan 08',
    );
  });
}
