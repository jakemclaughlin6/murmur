import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/core/epub/image_extractor.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageExtractor.hasExtractedImages', () {
    test('returns false for nonexistent directory', () {
      final tmpDir = Directory.systemTemp.createTempSync('img_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final bookDir = p.join(tmpDir.path, 'nonexistent');
      expect(ImageExtractor.hasExtractedImages(bookDir), isFalse);
    });

    test('returns false for empty images directory', () {
      final tmpDir = Directory.systemTemp.createTempSync('img_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      // Create images/ but leave it empty.
      Directory(p.join(tmpDir.path, 'images')).createSync();
      expect(ImageExtractor.hasExtractedImages(tmpDir.path), isFalse);
    });

    test('returns true when images directory has files', () {
      final tmpDir = Directory.systemTemp.createTempSync('img_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final imagesDir = Directory(p.join(tmpDir.path, 'images'));
      imagesDir.createSync();
      File(p.join(imagesDir.path, 'cover.jpg')).writeAsBytesSync([0xFF, 0xD8]);

      expect(ImageExtractor.hasExtractedImages(tmpDir.path), isTrue);
    });
  });

  group('Path traversal protection', () {
    test('p.basename strips directory traversal components', () {
      // Verifies the sanitization logic used in extractImages.
      expect(p.basename('../../etc/passwd'), 'passwd');
      expect(p.basename('../../../secret.txt'), 'secret.txt');
      expect(p.basename('images/cover.jpg'), 'cover.jpg');
      expect(p.basename('OEBPS/images/fig1.png'), 'fig1.png');
    });

    test('canonicalize detects traversal outside target directory', () {
      final tmpDir = Directory.systemTemp.createTempSync('img_test_');
      addTearDown(() => tmpDir.deleteSync(recursive: true));

      final imagesDir = p.join(tmpDir.path, 'images');
      // Simulate what extractImages does: basename + join + canonicalize.
      final maliciousHref = '../../etc/passwd';
      final filename = p.basename(maliciousHref); // 'passwd'
      final outputPath = p.join(imagesDir, filename);
      final resolvedOutput = p.canonicalize(outputPath);
      final resolvedImagesDir = p.canonicalize(imagesDir);

      // basename strips the traversal, so 'passwd' lands INSIDE imagesDir.
      expect(resolvedOutput.startsWith(resolvedImagesDir), isTrue);

      // But a direct join WITHOUT basename would escape:
      final unsafePath = p.join(imagesDir, maliciousHref);
      final resolvedUnsafe = p.canonicalize(unsafePath);
      expect(resolvedUnsafe.startsWith(resolvedImagesDir), isFalse);
    });
  });
}
