// test/architecture/feature_boundary_test.dart
//
// Enforces PBK-08: reader and tts features never import each other.
// Both depend on lib/core/playback_state.dart as the coordination seam.
// Also enforces that lib/core/** is feature-free.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<File>> _dartFiles(String dir) async {
  final result = <File>[];
  final d = Directory(dir);
  if (!d.existsSync()) return result;
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File &&
        e.path.endsWith('.dart') &&
        !e.path.endsWith('.g.dart') &&
        !e.path.endsWith('.freezed.dart')) {
      result.add(e);
    }
  }
  return result;
}

void main() {
  test('features/reader/** does NOT import features/tts/**', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib/features/reader')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"][^'"]*features/tts/''').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'Reader must not import TTS; use lib/core/playback_state.dart');
  });

  test('features/tts/** does NOT import features/reader/**', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib/features/tts')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"][^'"]*features/reader/''').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'TTS must not import Reader; use lib/core/playback_state.dart');
  });

  test('lib/core/** does NOT import features/**', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib/core')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"][^'"]*features/''').hasMatch(src)) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'lib/core/** must remain free of feature imports');
  });
}
