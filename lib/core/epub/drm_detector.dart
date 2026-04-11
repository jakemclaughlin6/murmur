/// DRM detection for imported EPUBs (LIB-04).
///
/// The parser (`epub_parser.dart`) calls [detectDrm] immediately after
/// decoding the zip archive and BEFORE doing any XHTML work — if the
/// EPUB carries a DRM marker the parser throws [DrmDetectedException]
/// and no content is ever walked.
///
/// Threat T-02-04-02 (DRM bypass via malformed META-INF): we do an
/// exact-path match against the archive's file list. The EPUB spec
/// mandates exact paths ("META-INF/encryption.xml", "META-INF/rights.xml")
/// so case-insensitive matching is not required and would be strictly
/// more permissive than the spec.
///
/// This file is pure Dart: no Flutter imports. It runs inside
/// `Isolate.run` alongside the parser per D-13.
library;

import 'package:archive/archive.dart';

/// Thrown by the parser when [detectDrm] returns true for an EPUB.
/// The import service (Plan 02-05) catches this and surfaces the
/// "file may be DRM-protected or corrupt" snackbar per D-12.
class DrmDetectedException implements Exception {
  final String reason;
  const DrmDetectedException(this.reason);

  @override
  String toString() => 'DrmDetectedException: $reason';
}

/// Canonical EPUB paths that signal DRM protection.
///
/// - `META-INF/encryption.xml` — standard OCF encryption descriptor.
///   Present in Adobe ADEPT, Apple FairPlay, B&N LCP, and most other
///   commercial DRM schemes.
/// - `META-INF/rights.xml`     — Adobe-specific rights descriptor.
///   Present in older Adobe DRM EPUBs.
///
/// Research assumption A5 in 02-RESEARCH.md: ≥99% of DRM EPUBs declare
/// protection via one of these markers. False negatives are benign
/// because the import pipeline's downstream XHTML parser will fail
/// on the encrypted content and surface the same "DRM-protected or
/// corrupt" snackbar via the generic error path.
const List<String> _drmMarkerPaths = <String>[
  'META-INF/encryption.xml',
  'META-INF/rights.xml',
];

/// Returns `true` if [archive] contains any EPUB DRM marker file.
///
/// Does NOT throw on a missing `META-INF` directory or an otherwise
/// incomplete archive — the parser will surface those conditions via
/// [EpubParseException]. This function's single job is DRM detection.
bool detectDrm(Archive archive) {
  for (final file in archive.files) {
    if (_drmMarkerPaths.contains(file.name)) {
      return true;
    }
  }
  return false;
}
