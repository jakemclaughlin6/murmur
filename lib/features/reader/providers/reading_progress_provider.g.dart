// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Debounced reading progress saver (D-12, RDR-11).
///
/// Accepts scroll offset updates and saves to Drift after a 2-second
/// debounce. Also provides [flushNow] for AppLifecycleState.paused.

@ProviderFor(ReadingProgressNotifier)
final readingProgressProvider = ReadingProgressNotifierProvider._();

/// Debounced reading progress saver (D-12, RDR-11).
///
/// Accepts scroll offset updates and saves to Drift after a 2-second
/// debounce. Also provides [flushNow] for AppLifecycleState.paused.
final class ReadingProgressNotifierProvider
    extends $NotifierProvider<ReadingProgressNotifier, void> {
  /// Debounced reading progress saver (D-12, RDR-11).
  ///
  /// Accepts scroll offset updates and saves to Drift after a 2-second
  /// debounce. Also provides [flushNow] for AppLifecycleState.paused.
  ReadingProgressNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readingProgressProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readingProgressNotifierHash();

  @$internal
  @override
  ReadingProgressNotifier create() => ReadingProgressNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$readingProgressNotifierHash() =>
    r'73c870fab6f0d6aba9d4c045e3922c68acb654e5';

/// Debounced reading progress saver (D-12, RDR-11).
///
/// Accepts scroll offset updates and saves to Drift after a 2-second
/// debounce. Also provides [flushNow] for AppLifecycleState.paused.

abstract class _$ReadingProgressNotifier extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
