// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_worker_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Family keyed by `bookId`. Spawns a real-isolate `TtsClient` in prod.
/// Tests override this provider per-bookId with an in-process spawn
/// that supplies a `FakeTtsEngine`.

@ProviderFor(ttsWorker)
final ttsWorkerProvider = TtsWorkerFamily._();

/// Family keyed by `bookId`. Spawns a real-isolate `TtsClient` in prod.
/// Tests override this provider per-bookId with an in-process spawn
/// that supplies a `FakeTtsEngine`.

final class TtsWorkerProvider
    extends
        $FunctionalProvider<
          AsyncValue<TtsClient>,
          TtsClient,
          FutureOr<TtsClient>
        >
    with $FutureModifier<TtsClient>, $FutureProvider<TtsClient> {
  /// Family keyed by `bookId`. Spawns a real-isolate `TtsClient` in prod.
  /// Tests override this provider per-bookId with an in-process spawn
  /// that supplies a `FakeTtsEngine`.
  TtsWorkerProvider._({
    required TtsWorkerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'ttsWorkerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$ttsWorkerHash();

  @override
  String toString() {
    return r'ttsWorkerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<TtsClient> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<TtsClient> create(Ref ref) {
    final argument = this.argument as String;
    return ttsWorker(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TtsWorkerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$ttsWorkerHash() => r'5a88dfeff437d441d78fc718c6a53d44f185a0c5';

/// Family keyed by `bookId`. Spawns a real-isolate `TtsClient` in prod.
/// Tests override this provider per-bookId with an in-process spawn
/// that supplies a `FakeTtsEngine`.

final class TtsWorkerFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<TtsClient>, String> {
  TtsWorkerFamily._()
    : super(
        retry: null,
        name: r'ttsWorkerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Family keyed by `bookId`. Spawns a real-isolate `TtsClient` in prod.
  /// Tests override this provider per-bookId with an in-process spawn
  /// that supplies a `FakeTtsEngine`.

  TtsWorkerProvider call(String bookId) =>
      TtsWorkerProvider._(argument: bookId, from: this);

  @override
  String toString() => r'ttsWorkerProvider';
}
