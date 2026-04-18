// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'just_audio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-singleton `AudioPlayerHandle`. Disposed with the root container.

@ProviderFor(audioPlayer)
final audioPlayerProvider = AudioPlayerProvider._();

/// App-singleton `AudioPlayerHandle`. Disposed with the root container.

final class AudioPlayerProvider
    extends
        $FunctionalProvider<
          AudioPlayerHandle,
          AudioPlayerHandle,
          AudioPlayerHandle
        >
    with $Provider<AudioPlayerHandle> {
  /// App-singleton `AudioPlayerHandle`. Disposed with the root container.
  AudioPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlayerHash();

  @$internal
  @override
  $ProviderElement<AudioPlayerHandle> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AudioPlayerHandle create(Ref ref) {
    return audioPlayer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlayerHandle value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlayerHandle>(value),
    );
  }
}

String _$audioPlayerHash() => r'989cc7cd74337d8a5a98f26c6a375b5ccaf77182';
