/// Wave 0 stub — EPUB parser isolate offload.
///
/// Covers LIB-01 per 02-VALIDATION.md. D-13: parsing runs on a background
/// Isolate (via compute()) so batch import keeps the UI at 60fps. Real
/// tests land in Plan 02-04.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EPUB parser isolate offload', () {
    test(
      'TODO: parser runs on background isolate via compute() and does not block the UI thread',
      () {},
      skip: 'Wave 0 stub — implemented by Plan 04',
    );
  });
}
