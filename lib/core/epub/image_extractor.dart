/// EPUB inline image extraction utility (Phase 3, Plan 02).
///
/// Resolves EPUB-internal image hrefs (from [ImageBlock.href]) to local
/// filesystem paths by extracting images from the EPUB archive into
/// `${bookDir}/images/`.
///
/// Path traversal mitigation (T-03-03): every output path is canonicalized
/// and verified to start with the expected images directory. Malicious hrefs
/// containing `../../` are silently skipped.
library;

import 'dart:io';

import 'package:epubx/epubx.dart';
import 'package:path/path.dart' as p;

/// Extracts and resolves EPUB inline images to local file paths.
class ImageExtractor {
  /// Extracts all images from an EPUB file to the local filesystem.
  ///
  /// Returns a `Map<String, String>` mapping EPUB-internal href variants
  /// to local file paths. Multiple href forms are mapped for the same
  /// image so that [ImageBlock.href] (which may be relative to the chapter
  /// XHTML) can be resolved regardless of path depth:
  ///
  /// - Full content path (e.g. `OEBPS/images/cover.jpg`)
  /// - Basename only (e.g. `cover.jpg`)
  /// - Without leading directory (e.g. `images/cover.jpg`)
  ///
  /// Images are written to `${outputDir}/images/` with their original
  /// filenames.
  static Future<Map<String, String>> extractImages({
    required String epubFilePath,
    required String outputDir,
  }) async {
    final mapping = <String, String>{};
    final imagesDir = Directory(p.join(outputDir, 'images'));

    final epubBytes = await File(epubFilePath).readAsBytes();
    final book = await EpubReader.readBook(epubBytes);

    final images = book.Content?.Images;
    if (images == null || images.isEmpty) return mapping;

    await imagesDir.create(recursive: true);

    for (final entry in images.entries) {
      final epubHref = entry.key;
      final imageContent = entry.value;
      if (imageContent.Content == null) continue;

      final filename = p.basename(epubHref);
      final outputPath = p.join(imagesDir.path, filename);

      // T-03-03 path traversal: verify resolved path is within imagesDir.
      final resolvedOutput = p.canonicalize(outputPath);
      final resolvedImagesDir = p.canonicalize(imagesDir.path);
      if (!resolvedOutput.startsWith(resolvedImagesDir)) continue;

      await File(outputPath).writeAsBytes(imageContent.Content!);

      // Map multiple possible href forms to the same local path.
      // Block IR stores href relative to chapter XHTML; epubx keys by
      // full content path.
      mapping[epubHref] = outputPath;
      mapping[filename] = outputPath; // short form fallback
      // Also map without leading directory (e.g., 'images/fig1.png' -> path)
      final segments = p.split(epubHref);
      if (segments.length > 1) {
        mapping[p.joinAll(segments.sublist(1))] = outputPath;
      }
    }

    return mapping;
  }

  /// Checks if images have already been extracted for a book directory.
  static bool hasExtractedImages(String bookDir) {
    final imagesDir = Directory(p.join(bookDir, 'images'));
    return imagesDir.existsSync() && imagesDir.listSync().isNotEmpty;
  }
}
