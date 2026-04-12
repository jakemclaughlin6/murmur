// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReaderNotifier)
final readerProvider = ReaderNotifierFamily._();

final class ReaderNotifierProvider
    extends $AsyncNotifierProvider<ReaderNotifier, ReaderState> {
  ReaderNotifierProvider._({
    required ReaderNotifierFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'readerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerNotifierHash();

  @override
  String toString() {
    return r'readerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReaderNotifier create() => ReaderNotifier();

  @override
  bool operator ==(Object other) {
    return other is ReaderNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerNotifierHash() => r'd9308152e1c40b45e30b5556d56c7db4abe3bd5d';

final class ReaderNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ReaderNotifier,
          AsyncValue<ReaderState>,
          ReaderState,
          FutureOr<ReaderState>,
          int
        > {
  ReaderNotifierFamily._()
    : super(
        retry: null,
        name: r'readerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReaderNotifierProvider call(int bookId) =>
      ReaderNotifierProvider._(argument: bookId, from: this);

  @override
  String toString() => r'readerProvider';
}

abstract class _$ReaderNotifier extends $AsyncNotifier<ReaderState> {
  late final _$args = ref.$arg as int;
  int get bookId => _$args;

  FutureOr<ReaderState> build(int bookId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ReaderState>, ReaderState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ReaderState>, ReaderState>,
              AsyncValue<ReaderState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
