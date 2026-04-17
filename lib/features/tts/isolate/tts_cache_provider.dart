// lib/features/tts/isolate/tts_cache_provider.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:murmur/features/tts/isolate/tts_cache.dart';

part 'tts_cache_provider.g.dart';

/// App-wide singleton TtsCache rooted at `{appSupport}/tts_cache/`.
///
/// Production wiring (Wave 3 queue bootstrap) awaits
/// [ttsCacheAsyncProvider] at app startup and overrides this sync
/// provider with the resolved value. Tests override directly.
@Riverpod(keepAlive: true)
TtsCache ttsCache(Ref ref) {
  throw UnimplementedError(
    'ttsCacheProvider must be overridden at app startup; see '
    'ttsCacheAsyncProvider.future (Wave 3 adds main.dart wiring).',
  );
}

@Riverpod(keepAlive: true)
Future<TtsCache> ttsCacheAsync(Ref ref) async {
  final support = await getApplicationSupportDirectory();
  final root = Directory(p.join(support.path, 'tts_cache'));
  if (!root.existsSync()) root.createSync(recursive: true);
  return TtsCache(cacheRoot: root);
}
