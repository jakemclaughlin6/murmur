// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_queue_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Constructs a `TtsQueue` bound to the current active `bookId`.
/// Chapter/sentence content is pushed by the reader through
/// `queue.setChapter(...)` (Phase 5 wiring). This provider only
/// dispatches isPlaying / speed / voiceId mutations.

@ProviderFor(ttsQueue)
final ttsQueueProvider = TtsQueueProvider._();

/// Constructs a `TtsQueue` bound to the current active `bookId`.
/// Chapter/sentence content is pushed by the reader through
/// `queue.setChapter(...)` (Phase 5 wiring). This provider only
/// dispatches isPlaying / speed / voiceId mutations.

final class TtsQueueProvider
    extends
        $FunctionalProvider<
          AsyncValue<TtsQueue?>,
          TtsQueue?,
          FutureOr<TtsQueue?>
        >
    with $FutureModifier<TtsQueue?>, $FutureProvider<TtsQueue?> {
  /// Constructs a `TtsQueue` bound to the current active `bookId`.
  /// Chapter/sentence content is pushed by the reader through
  /// `queue.setChapter(...)` (Phase 5 wiring). This provider only
  /// dispatches isPlaying / speed / voiceId mutations.
  TtsQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsQueueHash();

  @$internal
  @override
  $FutureProviderElement<TtsQueue?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TtsQueue?> create(Ref ref) {
    return ttsQueue(ref);
  }
}

String _$ttsQueueHash() => r'f7b994bd465c10f25799f9459565c9838502355a';
