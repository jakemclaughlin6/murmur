// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crash_logger_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Exposes the initialized CrashLogger singleton as a Riverpod provider.
///
/// The logger is initialized in `main.dart` (Plan 08) BEFORE `runApp`, so by
/// the time any widget reads this provider, `CrashLogger.instance` is safe
/// to call. Plan 08's Settings placeholder uses this to show:
/// - `logger.filePath` (plain text)
/// - `await logger.currentSize()` (byte count)

@ProviderFor(crashLogger)
final crashLoggerProvider = CrashLoggerProvider._();

/// Exposes the initialized CrashLogger singleton as a Riverpod provider.
///
/// The logger is initialized in `main.dart` (Plan 08) BEFORE `runApp`, so by
/// the time any widget reads this provider, `CrashLogger.instance` is safe
/// to call. Plan 08's Settings placeholder uses this to show:
/// - `logger.filePath` (plain text)
/// - `await logger.currentSize()` (byte count)

final class CrashLoggerProvider
    extends $FunctionalProvider<CrashLogger, CrashLogger, CrashLogger>
    with $Provider<CrashLogger> {
  /// Exposes the initialized CrashLogger singleton as a Riverpod provider.
  ///
  /// The logger is initialized in `main.dart` (Plan 08) BEFORE `runApp`, so by
  /// the time any widget reads this provider, `CrashLogger.instance` is safe
  /// to call. Plan 08's Settings placeholder uses this to show:
  /// - `logger.filePath` (plain text)
  /// - `await logger.currentSize()` (byte count)
  CrashLoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'crashLoggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$crashLoggerHash();

  @$internal
  @override
  $ProviderElement<CrashLogger> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CrashLogger create(Ref ref) {
    return crashLogger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CrashLogger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CrashLogger>(value),
    );
  }
}

String _$crashLoggerHash() => r'505ecdfd8b5050cfd41bc7cd1a29f63e5f4238fb';
