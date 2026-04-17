// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reactive library state — watches the Drift `books` table and emits
/// a [LibraryState] every time either the underlying table changes OR
/// [setSortMode] / [setSearchQuery] is called.
///
/// `keepAlive: true` so the state survives library-screen rebuilds
/// (swiping away to Settings and back must not reset the user's active
/// sort chip or search text).

@ProviderFor(LibraryNotifier)
final libraryProvider = LibraryNotifierProvider._();

/// Reactive library state — watches the Drift `books` table and emits
/// a [LibraryState] every time either the underlying table changes OR
/// [setSortMode] / [setSearchQuery] is called.
///
/// `keepAlive: true` so the state survives library-screen rebuilds
/// (swiping away to Settings and back must not reset the user's active
/// sort chip or search text).
final class LibraryNotifierProvider
    extends $StreamNotifierProvider<LibraryNotifier, LibraryState> {
  /// Reactive library state — watches the Drift `books` table and emits
  /// a [LibraryState] every time either the underlying table changes OR
  /// [setSortMode] / [setSearchQuery] is called.
  ///
  /// `keepAlive: true` so the state survives library-screen rebuilds
  /// (swiping away to Settings and back must not reset the user's active
  /// sort chip or search text).
  LibraryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryNotifierHash();

  @$internal
  @override
  LibraryNotifier create() => LibraryNotifier();
}

String _$libraryNotifierHash() => r'4ca8f4ec9d94f7e08f689d569ff482292ff30259';

/// Reactive library state — watches the Drift `books` table and emits
/// a [LibraryState] every time either the underlying table changes OR
/// [setSortMode] / [setSearchQuery] is called.
///
/// `keepAlive: true` so the state survives library-screen rebuilds
/// (swiping away to Settings and back must not reset the user's active
/// sort chip or search text).

abstract class _$LibraryNotifier extends $StreamNotifier<LibraryState> {
  Stream<LibraryState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<LibraryState>, LibraryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LibraryState>, LibraryState>,
              AsyncValue<LibraryState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
