// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controls the reader font size (D-14).
///
/// Persists to `shared_preferences` under `settings.fontSize`.
/// Values are clamped to [minSize]–[maxSize] inclusive on set (T-03-05).

@ProviderFor(FontSizeController)
final fontSizeControllerProvider = FontSizeControllerProvider._();

/// Controls the reader font size (D-14).
///
/// Persists to `shared_preferences` under `settings.fontSize`.
/// Values are clamped to [minSize]–[maxSize] inclusive on set (T-03-05).
final class FontSizeControllerProvider
    extends $AsyncNotifierProvider<FontSizeController, double> {
  /// Controls the reader font size (D-14).
  ///
  /// Persists to `shared_preferences` under `settings.fontSize`.
  /// Values are clamped to [minSize]–[maxSize] inclusive on set (T-03-05).
  FontSizeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontSizeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontSizeControllerHash();

  @$internal
  @override
  FontSizeController create() => FontSizeController();
}

String _$fontSizeControllerHash() =>
    r'e356314ec8444593e7eebb7415ed2cbf4a27c3ec';

/// Controls the reader font size (D-14).
///
/// Persists to `shared_preferences` under `settings.fontSize`.
/// Values are clamped to [minSize]–[maxSize] inclusive on set (T-03-05).

abstract class _$FontSizeController extends $AsyncNotifier<double> {
  FutureOr<double> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<double>, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<double>, double>,
              AsyncValue<double>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Controls the reader font family (D-15).
///
/// Persists to `shared_preferences` under `settings.fontFamily`.
/// Rejects values not in [availableFamilies] (T-03-05).

@ProviderFor(FontFamilyController)
final fontFamilyControllerProvider = FontFamilyControllerProvider._();

/// Controls the reader font family (D-15).
///
/// Persists to `shared_preferences` under `settings.fontFamily`.
/// Rejects values not in [availableFamilies] (T-03-05).
final class FontFamilyControllerProvider
    extends $AsyncNotifierProvider<FontFamilyController, String> {
  /// Controls the reader font family (D-15).
  ///
  /// Persists to `shared_preferences` under `settings.fontFamily`.
  /// Rejects values not in [availableFamilies] (T-03-05).
  FontFamilyControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontFamilyControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontFamilyControllerHash();

  @$internal
  @override
  FontFamilyController create() => FontFamilyController();
}

String _$fontFamilyControllerHash() =>
    r'4652c93179e80b58790a06d06bd055f9f4f62252';

/// Controls the reader font family (D-15).
///
/// Persists to `shared_preferences` under `settings.fontFamily`.
/// Rejects values not in [availableFamilies] (T-03-05).

abstract class _$FontFamilyController extends $AsyncNotifier<String> {
  FutureOr<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
