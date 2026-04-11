/// DRM detector tests (LIB-04).
///
/// Covers the three behaviors from Plan 02-04 Task 1:
///   1. clean EPUB → false
///   2. EPUB with `META-INF/encryption.xml` → true
///   3. empty Archive (no META-INF at all) → false (does not throw)
///
/// Fixtures are built by `test/fixtures/epub/_build_fixtures.dart`.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/epub/drm_detector.dart';

Archive _decodeFixture(String name) {
  final path = 'test/fixtures/epub/$name';
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'fixture missing: $path');
  final bytes = file.readAsBytesSync();
  return ZipDecoder().decodeBytes(bytes);
}

void main() {
  group('detectDrm', () {
    test('returns false for a clean EPUB with no DRM markers', () {
      final archive = _decodeFixture('minimal.epub');
      expect(detectDrm(archive), isFalse);
    });

    test('returns true when META-INF/encryption.xml is present', () {
      final archive = _decodeFixture('drm_encrypted.epub');
      expect(detectDrm(archive), isTrue);
    });

    test('returns false for an empty Archive (no META-INF at all)', () {
      // Threat T-02-04-02 corollary: an archive missing META-INF entirely
      // is not "DRM-protected", it's "corrupt". The parser handles the
      // corrupt case via EpubParseException; detectDrm must NOT throw.
      final empty = Archive();
      expect(() => detectDrm(empty), returnsNormally);
      expect(detectDrm(empty), isFalse);
    });

    test('DrmDetectedException carries the reason string', () {
      const ex = DrmDetectedException('EPUB is DRM-protected');
      expect(ex.reason, 'EPUB is DRM-protected');
      expect(ex.toString(), contains('DRM-protected'));
    });
  });
}
