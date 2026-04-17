import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:murmur/features/tts/isolate/tts_cache.dart';
import 'package:murmur/features/tts/isolate/tts_cache_provider.dart';

void main() {
  test('ttsCacheProvider throws UnimplementedError before override', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Riverpod v3 wraps the provider body error in its own ProviderException
    // (internal, not exported). The wrapped cause is the UnimplementedError.
    expect(
      () => container.read(ttsCacheProvider),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'toString()',
          contains('UnimplementedError'),
        ),
      ),
    );
  });

  test('overrideWithValue makes ttsCacheProvider return the provided cache', () {
    final dir = Directory.systemTemp.createTempSync('cache_bootstrap');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final cache = TtsCache(cacheRoot: dir);
    final container = ProviderContainer(overrides: [
      ttsCacheProvider.overrideWithValue(cache),
    ]);
    addTearDown(container.dispose);
    expect(container.read(ttsCacheProvider), same(cache));
  });
}
