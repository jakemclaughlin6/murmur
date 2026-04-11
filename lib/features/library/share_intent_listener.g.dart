// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'share_intent_listener.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform share-intent source.
///
/// In production this returns [ReceiveSharingIntentSource]. Tests
/// override with a fake via `ProviderContainer(overrides: [...])`.

@ProviderFor(shareIntentSource)
final shareIntentSourceProvider = ShareIntentSourceProvider._();

/// The platform share-intent source.
///
/// In production this returns [ReceiveSharingIntentSource]. Tests
/// override with a fake via `ProviderContainer(overrides: [...])`.

final class ShareIntentSourceProvider
    extends
        $FunctionalProvider<
          ShareIntentSource,
          ShareIntentSource,
          ShareIntentSource
        >
    with $Provider<ShareIntentSource> {
  /// The platform share-intent source.
  ///
  /// In production this returns [ReceiveSharingIntentSource]. Tests
  /// override with a fake via `ProviderContainer(overrides: [...])`.
  ShareIntentSourceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareIntentSourceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareIntentSourceHash();

  @$internal
  @override
  $ProviderElement<ShareIntentSource> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ShareIntentSource create(Ref ref) {
    return shareIntentSource(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShareIntentSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShareIntentSource>(value),
    );
  }
}

String _$shareIntentSourceHash() => r'457430317b8a4aa2384c5e9c45893ae19a25976a';

/// The share-intent listener. Its `build()` drains initial media
/// (cold-start intent) and then subscribes to the runtime stream.
///
/// `keepAlive: true` because the listener must outlive every screen
/// rebuild — dropping the subscription would mean a share event
/// received while the library screen is being rebuilt disappears.
///
/// Root widget must `ref.watch(shareIntentListenerProvider)` once so
/// the provider's `build()` actually runs.

@ProviderFor(ShareIntentListener)
final shareIntentListenerProvider = ShareIntentListenerProvider._();

/// The share-intent listener. Its `build()` drains initial media
/// (cold-start intent) and then subscribes to the runtime stream.
///
/// `keepAlive: true` because the listener must outlive every screen
/// rebuild — dropping the subscription would mean a share event
/// received while the library screen is being rebuilt disappears.
///
/// Root widget must `ref.watch(shareIntentListenerProvider)` once so
/// the provider's `build()` actually runs.
final class ShareIntentListenerProvider
    extends $AsyncNotifierProvider<ShareIntentListener, void> {
  /// The share-intent listener. Its `build()` drains initial media
  /// (cold-start intent) and then subscribes to the runtime stream.
  ///
  /// `keepAlive: true` because the listener must outlive every screen
  /// rebuild — dropping the subscription would mean a share event
  /// received while the library screen is being rebuilt disappears.
  ///
  /// Root widget must `ref.watch(shareIntentListenerProvider)` once so
  /// the provider's `build()` actually runs.
  ShareIntentListenerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shareIntentListenerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shareIntentListenerHash();

  @$internal
  @override
  ShareIntentListener create() => ShareIntentListener();
}

String _$shareIntentListenerHash() =>
    r'e2360541bf05e7a5d69119a9c16a2aec3b4ba31a';

/// The share-intent listener. Its `build()` drains initial media
/// (cold-start intent) and then subscribes to the runtime stream.
///
/// `keepAlive: true` because the listener must outlive every screen
/// rebuild — dropping the subscription would mean a share event
/// received while the library screen is being rebuilt disappears.
///
/// Root widget must `ref.watch(shareIntentListenerProvider)` once so
/// the provider's `build()` actually runs.

abstract class _$ShareIntentListener extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
