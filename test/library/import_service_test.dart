/// Wave 0 stub — import service.
///
/// Covers LIB-01, LIB-04 per 02-VALIDATION.md. D-11: optimistic insert with
/// shimmer placeholder; D-12: one snackbar per failed book; D-13: background
/// isolate parsing; D-14: same pipeline as share-intent. Real tests land in
/// Plan 02-05.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Import service', () {
    test(
      'TODO: optimistic insert + background parse completes and resolves card to real metadata',
      () {},
      skip: 'Wave 0 stub — implemented by Plan 05',
    );

    test(
      'TODO: corrupt/DRM EPUB surfaces a single snackbar per failed book and leaves library unchanged',
      () {},
      skip: 'Wave 0 stub — implemented by Plan 05',
    );
  });
}
