// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_status_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ModelStatusNotifier)
final modelStatusProvider = ModelStatusNotifierProvider._();

final class ModelStatusNotifierProvider
    extends $AsyncNotifierProvider<ModelStatusNotifier, ModelStatus> {
  ModelStatusNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelStatusNotifierHash();

  @$internal
  @override
  ModelStatusNotifier create() => ModelStatusNotifier();
}

String _$modelStatusNotifierHash() =>
    r'e9f28f5d3e4ed55779db62420eb739bd7697356b';

abstract class _$ModelStatusNotifier extends $AsyncNotifier<ModelStatus> {
  FutureOr<ModelStatus> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ModelStatus>, ModelStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ModelStatus>, ModelStatus>,
              AsyncValue<ModelStatus>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
