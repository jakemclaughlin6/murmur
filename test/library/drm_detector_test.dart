/// Wave 0 stub — DRM detector.
///
/// Covers LIB-04 per 02-VALIDATION.md. Rejects EPUBs carrying an
/// `META-INF/encryption.xml` entry before any parsing work runs. Secure
/// behavior: corrupt/DRM EPUB surfaces a snackbar, never a crash. Real
/// tests land in Plan 02-04.
library;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DRM detector', () {
    test(
      'TODO: rejects EPUB with META-INF/encryption.xml as DRM-protected',
      () {},
      skip: 'Wave 0 stub — implemented by Plan 04',
    );
  });
}
