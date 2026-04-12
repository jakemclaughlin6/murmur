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

  group('Relative path normalization', () {
    test('p.normalize collapses ./ segments and internal ../ for image resolution', () {
      // p.normalize cleans up redundant separators and ./ prefixes.
      expect(p.normalize('./images/photo.png'), 'images/photo.png');
      // Leading ../ is preserved on POSIX (no base to resolve against),
      // but internal ../ within an absolute-ish EPUB content path collapses:
      expect(p.normalize('OEBPS/text/../images/fig.png'), 'OEBPS/images/fig.png');
      // Already clean paths are unchanged.
      expect(p.normalize('images/fig.png'), 'images/fig.png');
      expect(p.normalize('OEBPS/images/fig.png'), 'OEBPS/images/fig.png');
    });

    test('multi-level sub-path stripping covers deeply nested hrefs', () {
      // Simulates the multi-level stripping loop in extractImages.
      const epubHref = 'OEBPS/content/images/fig1.png';
      final segments = p.split(epubHref);
      // segments: ['OEBPS', 'content', 'images', 'fig1.png']
      expect(segments.length, 4);

      // sublist(1) -> content/images/fig1.png (existing code)
      expect(p.joinAll(segments.sublist(1)), 'content/images/fig1.png');
      // sublist(2) -> images/fig1.png (new loop)
      expect(p.joinAll(segments.sublist(2)), 'images/fig1.png');
      // sublist(3) -> fig1.png (new loop, same as basename)
      expect(p.joinAll(segments.sublist(3)), 'fig1.png');
    });

    test('basename fallback resolves when only filename matches', () {
      // Verifies the basename fallback used in _ImageBlockWidget.
      const href = '../images/test.png';
      expect(p.basename(href), 'test.png');
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
