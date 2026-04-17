// test/architecture/no_direct_network_test.dart
//
// Enforces:
// 1. package:http is imported only by the model downloader.
// 2. package:sherpa_onnx is imported only by the sherpa adapter and
//    the debug spike page.
// 3. No analytics / crash / telemetry SDKs anywhere in lib/.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<List<File>> _dartFiles(String dir) async {
  final result = <File>[];
  await for (final e in Directory(dir).list(recursive: true, followLinks: false)) {
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
  test('package:http imported ONLY by model_downloader.dart', () async {
    final offenders = <String>[];
    for (final f in await _dartFiles('lib')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"]package:http/''').hasMatch(src)) {
        if (!f.path.replaceAll(r'\', '/').endsWith('/model_downloader.dart')) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Only model_downloader may make network calls');
  });

  test('package:sherpa_onnx imported ONLY by sherpa_tts_engine.dart + spike_page.dart',
      () async {
    const allowed = <String>{
      'lib/features/tts/isolate/sherpa_tts_engine.dart',
      'lib/features/tts/spike/spike_page.dart',
    };
    final offenders = <String>[];
    for (final f in await _dartFiles('lib')) {
      final src = await f.readAsString();
      if (RegExp(r'''import\s+['"]package:sherpa_onnx/''').hasMatch(src)) {
        if (!allowed.contains(f.path.replaceAll(r'\', '/'))) {
          offenders.add(f.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'sherpa_onnx must be isolated to the engine adapter');
  });

  test('no analytics/telemetry/crashlytics packages in lib/', () async {
    const banned = [
      'firebase',
      'sentry',
      'crashlytics',
      'amplitude',
      'mixpanel',
      'segment',
      'posthog',
    ];
    final offenders = <String>[];
    for (final f in await _dartFiles('lib')) {
      final src = (await f.readAsString()).toLowerCase();
      for (final b in banned) {
        if (src.contains('package:$b')) offenders.add('${f.path} imports $b');
      }
    }
    expect(offenders, isEmpty,
        reason: 'PROJECT.md bans all analytics/telemetry SDKs');
  });
}
