// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The directory the import service writes EPUBs and covers into.
///
/// In production this resolves to `getApplicationDocumentsDirectory()`
/// via `path_provider`. Tests override this provider to point at a
/// per-test `Directory.systemTemp.createTempSync(...)` sandbox so the
/// service does not need a `TestDefaultBinaryMessengerBinding` +
/// `PathProviderPlatform` mock to run.
///
/// `keepAlive: true` because the resolved directory never changes
/// during an app session.

@ProviderFor(appDocumentsDir)
final appDocumentsDirProvider = AppDocumentsDirProvider._();

/// The directory the import service writes EPUBs and covers into.
///
/// In production this resolves to `getApplicationDocumentsDirectory()`
/// via `path_provider`. Tests override this provider to point at a
/// per-test `Directory.systemTemp.createTempSync(...)` sandbox so the
/// service does not need a `TestDefaultBinaryMessengerBinding` +
/// `PathProviderPlatform` mock to run.
///
/// `keepAlive: true` because the resolved directory never changes
/// during an app session.

final class AppDocumentsDirProvider
    extends
        $FunctionalProvider<
          AsyncValue<Directory>,
          Directory,
          FutureOr<Directory>
        >
    with $FutureModifier<Directory>, $FutureProvider<Directory> {
  /// The directory the import service writes EPUBs and covers into.
  ///
  /// In production this resolves to `getApplicationDocumentsDirectory()`
  /// via `path_provider`. Tests override this provider to point at a
  /// per-test `Directory.systemTemp.createTempSync(...)` sandbox so the
  /// service does not need a `TestDefaultBinaryMessengerBinding` +
  /// `PathProviderPlatform` mock to run.
  ///
  /// `keepAlive: true` because the resolved directory never changes
  /// during an app session.
  AppDocumentsDirProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDocumentsDirProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDocumentsDirHash();

  @$internal
  @override
  $FutureProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Directory> create(Ref ref) {
    return appDocumentsDir(ref);
  }
}

String _$appDocumentsDirHash() => r'9753924678ffc29e7972e9a23900da122c33495d';

/// Single import pipeline for both file_picker (LIB-01) and Share /
/// Open-in (LIB-02) per D-14.
///
/// `keepAlive: true` because the notifier outlives widget rebuilds —
/// a freshly-mounted library screen should pick up an already-running
/// import without restarting it.

@ProviderFor(ImportNotifier)
final importProvider = ImportNotifierProvider._();

/// Single import pipeline for both file_picker (LIB-01) and Share /
/// Open-in (LIB-02) per D-14.
///
/// `keepAlive: true` because the notifier outlives widget rebuilds —
/// a freshly-mounted library screen should pick up an already-running
/// import without restarting it.
final class ImportNotifierProvider
    extends $NotifierProvider<ImportNotifier, List<ImportState>> {
  /// Single import pipeline for both file_picker (LIB-01) and Share /
  /// Open-in (LIB-02) per D-14.
  ///
  /// `keepAlive: true` because the notifier outlives widget rebuilds —
  /// a freshly-mounted library screen should pick up an already-running
  /// import without restarting it.
  ImportNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'importProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$importNotifierHash();

  @$internal
  @override
  ImportNotifier create() => ImportNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ImportState> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ImportState>>(value),
    );
  }
}

String _$importNotifierHash() => r'2e060b3e0a33e8bea1181c4e866fe031514dfc35';

/// Single import pipeline for both file_picker (LIB-01) and Share /
/// Open-in (LIB-02) per D-14.
///
/// `keepAlive: true` because the notifier outlives widget rebuilds —
/// a freshly-mounted library screen should pick up an already-running
/// import without restarting it.

abstract class _$ImportNotifier extends $Notifier<List<ImportState>> {
  List<ImportState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<List<ImportState>, List<ImportState>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<ImportState>, List<ImportState>>,
              List<ImportState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
