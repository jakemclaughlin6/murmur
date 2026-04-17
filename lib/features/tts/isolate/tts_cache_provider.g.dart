// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_cache_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide singleton TtsCache rooted at `{appSupport}/tts_cache/`.
///
/// Production wiring (Wave 3 queue bootstrap) awaits
/// [ttsCacheAsyncProvider] at app startup and overrides this sync
/// provider with the resolved value. Tests override directly.

@ProviderFor(ttsCache)
final ttsCacheProvider = TtsCacheProvider._();

/// App-wide singleton TtsCache rooted at `{appSupport}/tts_cache/`.
///
/// Production wiring (Wave 3 queue bootstrap) awaits
/// [ttsCacheAsyncProvider] at app startup and overrides this sync
/// provider with the resolved value. Tests override directly.

final class TtsCacheProvider
    extends $FunctionalProvider<TtsCache, TtsCache, TtsCache>
    with $Provider<TtsCache> {
  /// App-wide singleton TtsCache rooted at `{appSupport}/tts_cache/`.
  ///
  /// Production wiring (Wave 3 queue bootstrap) awaits
  /// [ttsCacheAsyncProvider] at app startup and overrides this sync
  /// provider with the resolved value. Tests override directly.
  TtsCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsCacheHash();

  @$internal
  @override
  $ProviderElement<TtsCache> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TtsCache create(Ref ref) {
    return ttsCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsCache>(value),
    );
  }
}

String _$ttsCacheHash() => r'3c9ef8db4078fdd83ad61ac7f38b85e26bf8172c';

@ProviderFor(ttsCacheAsync)
final ttsCacheAsyncProvider = TtsCacheAsyncProvider._();

final class TtsCacheAsyncProvider
    extends
        $FunctionalProvider<AsyncValue<TtsCache>, TtsCache, FutureOr<TtsCache>>
    with $FutureModifier<TtsCache>, $FutureProvider<TtsCache> {
  TtsCacheAsyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsCacheAsyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsCacheAsyncHash();

  @$internal
  @override
  $FutureProviderElement<TtsCache> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TtsCache> create(Ref ref) {
    return ttsCacheAsync(ref);
  }
}

String _$ttsCacheAsyncHash() => r'e0ecd919f5a4eedb2ad7b98504a9f5f36c0c6a9a';
