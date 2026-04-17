// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playback_state.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Coordination seam between reader and TTS. keepAlive ensures the
/// cursor survives widget rebuilds for the reader session.

@ProviderFor(PlaybackStateNotifier)
final playbackStateProvider = PlaybackStateNotifierProvider._();

/// Coordination seam between reader and TTS. keepAlive ensures the
/// cursor survives widget rebuilds for the reader session.
final class PlaybackStateNotifierProvider
    extends $NotifierProvider<PlaybackStateNotifier, PlaybackState> {
  /// Coordination seam between reader and TTS. keepAlive ensures the
  /// cursor survives widget rebuilds for the reader session.
  PlaybackStateNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'playbackStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$playbackStateNotifierHash();

  @$internal
  @override
  PlaybackStateNotifier create() => PlaybackStateNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlaybackState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlaybackState>(value),
    );
  }
}

String _$playbackStateNotifierHash() =>
    r'e9690071a519c6b3a05f271a81245407e37ce1e6';

/// Coordination seam between reader and TTS. keepAlive ensures the
/// cursor survives widget rebuilds for the reader session.

abstract class _$PlaybackStateNotifier extends $Notifier<PlaybackState> {
  PlaybackState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PlaybackState, PlaybackState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlaybackState, PlaybackState>,
              PlaybackState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
