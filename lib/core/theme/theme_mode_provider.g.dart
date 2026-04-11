// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// D-14: Theme mode persists across app restarts via `shared_preferences`
/// under the key `settings.themeMode`. @Riverpod(keepAlive: true) prevents
/// the provider from being disposed on navigation rebuilds — critical for
/// avoiding a re-read of SharedPreferences on every route change.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// D-14: Theme mode persists across app restarts via `shared_preferences`
/// under the key `settings.themeMode`. @Riverpod(keepAlive: true) prevents
/// the provider from being disposed on navigation rebuilds — critical for
/// avoiding a re-read of SharedPreferences on every route change.
final class ThemeModeControllerProvider
    extends $AsyncNotifierProvider<ThemeModeController, MurmurThemeMode> {
  /// D-14: Theme mode persists across app restarts via `shared_preferences`
  /// under the key `settings.themeMode`. @Riverpod(keepAlive: true) prevents
  /// the provider from being disposed on navigation rebuilds — critical for
  /// avoiding a re-read of SharedPreferences on every route change.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();
}

String _$themeModeControllerHash() =>
    r'a5e485ad49b36af3d9a213c75489fbbc45603ffb';

/// D-14: Theme mode persists across app restarts via `shared_preferences`
/// under the key `settings.themeMode`. @Riverpod(keepAlive: true) prevents
/// the provider from being disposed on navigation rebuilds — critical for
/// avoiding a re-read of SharedPreferences on every route change.

abstract class _$ThemeModeController extends $AsyncNotifier<MurmurThemeMode> {
  FutureOr<MurmurThemeMode> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MurmurThemeMode>, MurmurThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MurmurThemeMode>, MurmurThemeMode>,
              AsyncValue<MurmurThemeMode>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
